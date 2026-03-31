extends CharacterBody2D

const SPEED := 200.0
const JUMP_VELOCITY := -600.0
const GRAVITY := 980.0

const PUNCH_DAMAGE := 10
const KICK_DAMAGE := 20
const HIT_COMBO_THRESHOLD := 3
const HIT_WINDOW := 3.0
const PUNCH_REACH := 140.0
const KICK_REACH := 180.0

@export var key_left: int = KEY_LEFT
@export var key_right: int = KEY_RIGHT
@export var key_jump: int = KEY_SPACE
@export var key_punch: int = KEY_Z
@export var key_kick: int = KEY_X
@export var face_left: bool = false
@export var health_bar_path: NodePath
@export var display_name: String = "Simonka"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

enum State { NORMAL, HIT, FALLEN, GETUP }

signal defeated

var state := State.NORMAL
var health := 100
var is_defeated := false
var hit_count := 0
var hit_timer := 0.0
var _attacking := false
var _opponent: CharacterBody2D
var _health_bar: ProgressBar

func _ready() -> void:
	add_to_group("players")
	anim.animation_finished.connect(_on_animation_finished)
	anim.frame_changed.connect(_on_frame_changed)
	if face_left:
		anim.flip_h = true
	if health_bar_path:
		_health_bar = get_node(health_bar_path)
		_health_bar.value = health

func _find_opponent() -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if p != self:
			_opponent = p as CharacterBody2D
			return

func _on_animation_finished() -> void:
	match state:
		State.HIT:
			state = State.NORMAL
		State.FALLEN:
			if is_defeated:
				pass  # stay down permanently
			else:
				state = State.GETUP
				anim.play("getup")
		State.GETUP:
			state = State.NORMAL
			hit_count = 0
		_:
			_attacking = false

func _on_frame_changed() -> void:
	if anim.animation == "punch" and anim.frame == 1:
		_try_hit_opponent(false)
	elif anim.animation == "kick" and anim.frame == 2:
		_try_hit_opponent(true)

func take_hit(is_kick: bool) -> void:
	if is_defeated or state == State.FALLEN or state == State.GETUP:
		return
	var damage := KICK_DAMAGE if is_kick else PUNCH_DAMAGE
	health = max(0, health - damage)
	if _health_bar:
		_health_bar.value = health
	if health <= 0:
		_enter_defeated()
		return
	hit_count += 1
	hit_timer = HIT_WINDOW
	if hit_count >= HIT_COMBO_THRESHOLD:
		hit_count = 0
		hit_timer = 0.0
		_enter_fallen()
	else:
		_enter_hit()

func _enter_hit() -> void:
	state = State.HIT
	_attacking = false
	velocity.x = 0.0
	anim.play("gets_hit")

func _enter_fallen() -> void:
	state = State.FALLEN
	_attacking = false
	velocity = Vector2.ZERO
	anim.play("falls")

func _enter_defeated() -> void:
	is_defeated = true
	state = State.FALLEN
	_attacking = false
	velocity = Vector2.ZERO
	anim.play("falls")
	defeated.emit()

func _try_hit_opponent(is_kick: bool) -> void:
	if _opponent == null:
		_find_opponent()
	if _opponent == null:
		return
	var dist := global_position.distance_to(_opponent.global_position)
	var reach := KICK_REACH if is_kick else PUNCH_REACH
	if dist > reach:
		return
	var to_opponent := _opponent.global_position.x - global_position.x
	var facing_right := not anim.flip_h
	if (facing_right and to_opponent > 0) or (not facing_right and to_opponent < 0):
		_opponent.take_hit(is_kick)

func _unhandled_input(event: InputEvent) -> void:
	if state != State.NORMAL:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if not _attacking:
			if event.keycode == key_punch:
				_attacking = true
				anim.play("punch")
			elif event.keycode == key_kick:
				_attacking = true
				anim.play("kick")
		if event.keycode == key_jump and is_on_floor():
			velocity.y = JUMP_VELOCITY

func _physics_process(delta: float) -> void:
	if hit_timer > 0.0:
		hit_timer -= delta
		if hit_timer <= 0.0:
			hit_count = 0
			hit_timer = 0.0

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if state == State.FALLEN or state == State.GETUP:
		velocity.x = 0.0
		move_and_slide()
		return

	var left := Input.is_key_pressed(key_left)
	var right := Input.is_key_pressed(key_right)
	var direction := float(right) - float(left)

	if state == State.HIT:
		velocity.x = 0.0
	else:
		velocity.x = direction * SPEED

	move_and_slide()

	if state == State.NORMAL and not _attacking:
		if not is_on_floor():
			anim.play("jump")
		elif direction != 0:
			anim.flip_h = direction < 0
			anim.play("walk")
		else:
			anim.play("idle")
