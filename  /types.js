"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.INPUT_KICK = exports.INPUT_PUNCH = exports.INPUT_DOWN = exports.INPUT_JUMP = exports.INPUT_RIGHT = exports.INPUT_LEFT = void 0;
// Input bitmask layout (6 bits):
// bit 0: left
// bit 1: right
// bit 2: jump
// bit 3: down
// bit 4: punch
// bit 5: kick
exports.INPUT_LEFT = 1 << 0;
exports.INPUT_RIGHT = 1 << 1;
exports.INPUT_JUMP = 1 << 2;
exports.INPUT_DOWN = 1 << 3;
exports.INPUT_PUNCH = 1 << 4;
exports.INPUT_KICK = 1 << 5;
