import { WebSocketServer, WebSocket } from 'ws';
import { v4 as uuidv4 } from 'uuid';
import { ClientMessage, ServerMessage } from './types';

const PORT = parseInt(process.env['PORT'] ?? '9090', 10);

interface Player {
  ws: WebSocket;
  name: string;
  role: 'p1' | 'p2';
  character: string;
  bgIndex: number;
  charConfirmed: boolean;
}

interface Room {
  id: string;
  p1: Player;
  p2: Player | null;
}

const queue: { ws: WebSocket; name: string }[] = [];
const rooms = new Map<string, Room>();
const socketToRoom = new Map<WebSocket, { roomId: string; role: 'p1' | 'p2' }>();

const wss = new WebSocketServer({ port: PORT });

console.log(`[relay] Listening on ws://0.0.0.0:${PORT}`);

wss.on('connection', (ws) => {
  console.log('[relay] Client connected');

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data.toString()) as ClientMessage;
      handleMessage(ws, msg);
    } catch (err) {
      console.error('[relay] Bad message:', err);
    }
  });

  ws.on('close', () => handleDisconnect(ws));
  ws.on('error', (err) => console.error('[relay] Socket error:', err));
});

function send(ws: WebSocket, msg: ServerMessage): void {
  if (ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(msg));
  }
}

function handleMessage(ws: WebSocket, msg: ClientMessage): void {
  switch (msg.type) {
    case 'join_queue': {
      // Prevent double-joining
      if (socketToRoom.has(ws)) return;
      if (queue.some(q => q.ws === ws)) return;
      queue.push({ ws, name: msg.name });
      tryMatch();
      break;
    }

    case 'char_select': {
      const info = socketToRoom.get(ws);
      if (!info) return;
      const room = rooms.get(info.roomId);
      if (!room || !room.p2) return;

      const me = info.role === 'p1' ? room.p1 : room.p2;
      const partner = info.role === 'p1' ? room.p2 : room.p1;

      me.character = msg.character;
      me.bgIndex = msg.background_index;
      me.charConfirmed = true;

      // Tell partner what we picked
      send(partner.ws, {
        type: 'opponent_char',
        character: msg.character,
        background_index: msg.background_index,
      });

      // If both confirmed, send canonical game_start to both
      if (room.p1.charConfirmed && room.p2.charConfirmed) {
        const bgIndex = room.p1.bgIndex; // P1 picks the background
        const gameStart: ServerMessage = {
          type: 'game_start',
          p1_char: room.p1.character,
          p2_char: room.p2.character,
          bg_index: bgIndex,
        };
        send(room.p1.ws, gameStart);
        send(room.p2.ws, gameStart);
        console.log(`[relay] Room ${room.id}: game starting — ${room.p1.character} vs ${room.p2.character}`);
      }
      break;
    }

    case 'char_hover': {
      const info = socketToRoom.get(ws);
      if (!info) return;
      const room = rooms.get(info.roomId);
      if (!room || !room.p2) return;

      const partner = info.role === 'p1' ? room.p2 : room.p1;
      send(partner.ws, { type: 'opponent_char_hover', index: msg.index });
      break;
    }

    case 'input_frame': {
      const info = socketToRoom.get(ws);
      if (!info) return;
      const room = rooms.get(info.roomId);
      if (!room || !room.p2) return;

      const partner = info.role === 'p1' ? room.p2 : room.p1;
      send(partner.ws, {
        type: 'input_relay',
        frame: msg.frame,
        keys: msg.keys,
      });
      break;
    }

    case 'ping': {
      send(ws, { type: 'pong', ts: msg.ts });
      break;
    }
  }
}

function handleDisconnect(ws: WebSocket): void {
  console.log('[relay] Client disconnected');

  // Remove from queue if waiting
  const queueIdx = queue.findIndex(q => q.ws === ws);
  if (queueIdx !== -1) {
    queue.splice(queueIdx, 1);
    return;
  }

  // Notify partner and clean up room
  const info = socketToRoom.get(ws);
  if (!info) return;

  socketToRoom.delete(ws);
  const room = rooms.get(info.roomId);
  if (!room) return;

  const partner = info.role === 'p1' ? room.p2 : room.p1;
  if (partner) {
    send(partner.ws, { type: 'opponent_disconnected' });
    socketToRoom.delete(partner.ws);
  }

  rooms.delete(info.roomId);
  console.log(`[relay] Room ${info.roomId} closed`);
}

function tryMatch(): void {
  if (queue.length < 2) return;

  const p1entry = queue.shift()!;
  const p2entry = queue.shift()!;

  const roomId = uuidv4().slice(0, 8);

  const p1: Player = {
    ws: p1entry.ws,
    name: p1entry.name,
    role: 'p1',
    character: '',
    bgIndex: 0,
    charConfirmed: false,
  };
  const p2: Player = {
    ws: p2entry.ws,
    name: p2entry.name,
    role: 'p2',
    character: '',
    bgIndex: 0,
    charConfirmed: false,
  };

  const room: Room = { id: roomId, p1, p2 };
  rooms.set(roomId, room);
  socketToRoom.set(p1.ws, { roomId, role: 'p1' });
  socketToRoom.set(p2.ws, { roomId, role: 'p2' });

  send(p1.ws, { type: 'matched', role: 'p1', room_id: roomId });
  send(p2.ws, { type: 'matched', role: 'p2', room_id: roomId });

  console.log(`[relay] Room ${roomId}: matched ${p1.name} (p1) vs ${p2.name} (p2)`);
}

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[relay] Shutting down...');
  wss.close(() => process.exit(0));
});
