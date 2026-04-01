extends KinematicBody2D

const SPEED := 200.0
const JUMP_VELOCITY := -600.0
const GRAVITY := 980.0

const PUNCH_DAMAGE := 10
const KICK_DAMAGE := 20
const HIT_COMBO_THRESHOLD := 3
const HIT_WINDOW := 3.0
const PUNCH_REACH := 140.0
const KICK_REACH := 180.0

export var action_left: String = "p1_left"
export var action_right: String = "p1_right"
export var action_jump: String = "p1_jump"
export var action_punch: String = "p1_punch"
export var action_kick: String = "p1_kick"
export var face_left: bool = false
export var health_bar_path: NodePath
export var display_name: String = "Simonka"

onready var anim: AnimatedSprite = $AnimatedSprite

enum State { NORMAL, HIT, FALLEN, GETUP }

signal defeated

var state = State.NORMAL
var health := 100
var is_defeated := false
var hit_count := 0
var hit_timer := 0.0
var _attacking := false
var _opponent: KinematicBody2D
var _health_bar: ProgressBar
var frozen: bool = false
var _start_position: Vector2
var velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	_start_position = global_position
	add_to_group("players")
	anim.connect("animation_finished", self, "_on_animation_finished")
	anim.connect("frame_changed", self, "_on_frame_changed")
	if face_left:
		anim.flip_h = true
	if health_bar_path:
		_health_bar = get_node(health_bar_path)
		_health_bar.value = health

func reset_for_round() -> void:
	health = 100
	is_defeated = false
	state = State.NORMAL
	hit_count = 0
	hit_timer = 0.0
	_attacking = false
	_opponent = null
	velocity = Vector2.ZERO
	global_position = _start_position
	if _health_bar:
		_health_bar.value = health
	anim.play("idle")

func _find_opponent() -> void:
	for p in get_tree().get_nodes_in_group("players"):
		if p != self:
			_opponent = p as KinematicBody2D
			return

func _on_animation_finished() -> void:
	match state:
		State.HIT:
			state = State.NORMAL
		State.FALLEN:
			if is_defeated:
				pass
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
	emit_signal("defeated")

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
	if frozen or state != State.NORMAL:
		return
	if not _attacking:
		if event.is_action_pressed(action_punch):
			_attacking = true
			anim.play("punch")
		elif event.is_action_pressed(action_kick):
			_attacking = true
			anim.play("kick")
	if event.is_action_pressed(action_jump) and is_on_floor():
		velocity.y = JUMP_VELOCITY

func _physics_process(delta: float) -> void:
	if frozen:
		return
	if hit_timer > 0.0:
		hit_timer -= delta
		if hit_timer <= 0.0:
			hit_count = 0
			hit_timer = 0.0

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if state == State.FALLEN or state == State.GETUP:
		velocity.x = 0.0
		velocity = move_and_slide(velocity, Vector2.UP)
		return

	var left := Input.is_action_pressed(action_left)
	var right := Input.is_action_pressed(action_right)
	var direction := float(right) - float(left)

	if state == State.HIT:
		velocity.x = 0.0
	else:
		velocity.x = direction * SPEED

	velocity = move_and_slide(velocity, Vector2.UP)

	if state == State.NORMAL and not _attacking:
		if not is_on_floor():
			anim.play("jump")
		elif direction != 0:
			anim.flip_h = direction < 0
			anim.play("walk")
		else:
			anim.play("idle")
