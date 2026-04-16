// Messages sent from client to server
export type ClientMessage =
  | { type: 'join_queue'; name: string }
  | { type: 'char_select'; character: string; background_index: number }
  | { type: 'input_frame'; frame: number; keys: number }
  | { type: 'ping'; ts: number };

// Messages sent from server to client
export type ServerMessage =
  | { type: 'matched'; role: 'p1' | 'p2'; room_id: string }
  | { type: 'opponent_char'; character: string; background_index: number }
  | { type: 'game_start'; p1_char: string; p2_char: string; bg_index: number }
  | { type: 'input_relay'; frame: number; keys: number }
  | { type: 'pong'; ts: number }
  | { type: 'opponent_disconnected' };

// Input bitmask layout (6 bits):
// bit 0: left
// bit 1: right
// bit 2: jump
// bit 3: down
// bit 4: punch
// bit 5: kick
export const INPUT_LEFT  = 1 << 0;
export const INPUT_RIGHT = 1 << 1;
export const INPUT_JUMP  = 1 << 2;
export const INPUT_DOWN  = 1 << 3;
export const INPUT_PUNCH = 1 << 4;
export const INPUT_KICK  = 1 << 5;
