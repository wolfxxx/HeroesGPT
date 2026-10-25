// The online relay (Cloudflare Worker + one Durable Object per room). It does not run the game: it passes the
// messages of one game between the host's machine and the machines that joined it, so that browsers (which cannot
// open ENet's UDP sockets or listen for others) and machines behind routers can play online. The game's side is
// scripts/core/relay_peer.gd; the host still checks every command, as over ENet (scripts/core/net.gd).
//
//   wss://<relay>/host        opens a room: the reply is {"t":"room","code":"KX7Q"}; the host is peer 1
//   wss://<relay>/join/KX7Q   joins it: {"t":"id","id":N} (N >= 2), or {"t":"error","reason":...} and closed
//
// Binary frames, both ways: 4 bytes (int32, little-endian) peer, 1 byte flags, the data. From a joined machine
// the peer is ignored and the frame goes to the host with the sender's id; from the host the peer is the target
// (0: everyone, -N: everyone but N) and the frame arrives with peer 1. Text frames are the relay's own notes: to
// the host {"t":"join","id":N} / {"t":"leave","id":N}; to the others {"t":"host_left"} before the room closes.

const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // (no 0/O, 1/I: read aloud or typed from a screen)
const ROOM_PEERS = 8;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const parts = url.pathname.split("/").filter((s) => s !== "");
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Heroes of the Shattered Crown: online relay.\n", { status: parts.length ? 426 : 200 });
    }
    if (parts[0] === "host") {
      for (let tries = 0; tries < 8; tries++) {
        let code = "";
        const r = crypto.getRandomValues(new Uint8Array(4));
        for (const b of r) code += CODE_CHARS[b % CODE_CHARS.length];
        const room = env.ROOMS.get(env.ROOMS.idFromName(code));
        const res = await room.fetch(new Request(`https://room/host/${code}`, request));
        if (res.status !== 409) return res; // (409: that code is in use; draw another)
      }
      return new Response("No free room.", { status: 503 });
    }
    if (parts[0] === "join" && parts[1]) {
      const code = parts[1].toUpperCase().slice(0, 8);
      const room = env.ROOMS.get(env.ROOMS.idFromName(code));
      return room.fetch(new Request(`https://room/join/${code}`, request));
    }
    return new Response("Not found.", { status: 404 });
  },
};

export class Room {
  constructor(state, env) {
    this.state = state;
  }

  async fetch(request) {
    const [, role, code] = new URL(request.url).pathname.split("/");
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    const host = this.state.getWebSockets("host")[0];
    if (role === "host") {
      if (host) return new Response("Taken.", { status: 409 });
      this.state.acceptWebSocket(server, ["host"]);
      server.serializeAttachment({ id: 1 });
      server.send(JSON.stringify({ t: "room", code }));
      return new Response(null, { status: 101, webSocket: client });
    }
    // a joining machine: accepted either way, so that it can be told why it cannot join
    this.state.acceptWebSocket(server, ["peer"]);
    const peers = this.state.getWebSockets("peer");
    if (!host) {
      server.send(JSON.stringify({ t: "error", reason: `No game with the code ${code}.` }));
      server.close(4000, "no game");
      return new Response(null, { status: 101, webSocket: client });
    }
    if (peers.length > ROOM_PEERS) {
      server.send(JSON.stringify({ t: "error", reason: "The game is full." }));
      server.close(4001, "full");
      return new Response(null, { status: 101, webSocket: client });
    }
    const used = new Set(peers.map((ws) => (ws.deserializeAttachment() || {}).id));
    let id = 0;
    while (id < 2 || used.has(id)) id = 2 + (crypto.getRandomValues(new Uint32Array(1))[0] % 2147483000);
    server.serializeAttachment({ id });
    server.send(JSON.stringify({ t: "id", id }));
    host.send(JSON.stringify({ t: "join", id }));
    return new Response(null, { status: 101, webSocket: client });
  }

  _peer(id) {
    return this.state.getWebSockets("peer").find((ws) => (ws.deserializeAttachment() || {}).id === id);
  }

  async webSocketMessage(ws, message) {
    if (typeof message === "string" || message.byteLength < 5) return;
    const me = (ws.deserializeAttachment() || {}).id;
    const view = new DataView(message);
    if (me === 1) {
      const to = view.getInt32(0, true);
      view.setInt32(0, 1, true);
      if (to > 0) {
        const p = this._peer(to);
        if (p) p.send(message);
      } else {
        for (const p of this.state.getWebSockets("peer")) {
          const pid = (p.deserializeAttachment() || {}).id;
          if (pid && pid !== -to) p.send(message);
        }
      }
    } else if (me) {
      const host = this.state.getWebSockets("host")[0];
      view.setInt32(0, me, true);
      if (host) host.send(message);
    }
  }

  async webSocketClose(ws, code, reason) {
    this._gone(ws);
  }

  async webSocketError(ws, error) {
    this._gone(ws);
  }

  _gone(ws) {
    const me = (ws.deserializeAttachment() || {}).id;
    ws.serializeAttachment({});
    try { ws.close(1000, "bye"); } catch (e) {}
    if (me === 1) {
      for (const p of this.state.getWebSockets("peer")) {
        try {
          p.send(JSON.stringify({ t: "host_left" }));
          p.close(4002, "host left");
        } catch (e) {}
      }
    } else if (me) {
      const host = this.state.getWebSockets("host")[0];
      if (host) {
        try { host.send(JSON.stringify({ t: "leave", id: me })); } catch (e) {}
      }
    }
  }
}
