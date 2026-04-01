# CLAUDE.md - Godot MCP Project Guidelines

## Build & Run Commands
- **Server Build**: `cd server && npm run build`
- **Server Start**: `cd server && npm run start`
- **Server Dev Mode**: `cd server && npm run dev` (auto-rebuild on changes)
- **Run Godot Project**: Open project.godot in Godot Editor

## Code Style Guidelines

### TypeScript (Server)
- Use camelCase for variables, methods, and function names
- Use PascalCase for classes/interfaces
- Strong typing: avoid `any` type
- Prefer async/await over Promise chains
- Import structure: Node modules first, then local modules

### Godot Version
- **Always use Godot 3 APIs** — this project targets Godot 3.x, not Godot 4
- Use `yield()` for coroutines, not `await`
- Use `connect("signal", target, "method")` syntax, not `signal.connect(callable)`
- Use `get_node()` / `$Node` paths as in Godot 3
- `onready var` not `@onready var`; `export var` not `@export var`
- `Vector2`, `KinematicBody2D`, `Area2D` etc. are Godot 3 class names (not `CharacterBody2D`)

### GDScript (Godot)
- Use snake_case for variables, methods, and function names
- Use PascalCase for classes
- Use type hints where possible: `var player: Player`
- Follow Godot singleton conventions (e.g., `Engine`, `OS`)
- Prefer signals for communication between nodes

### General
- Use descriptive names
- Keep functions small and focused
- Add comments for complex logic
- Error handling: prefer try/catch in TS, use assertions in GDScript
