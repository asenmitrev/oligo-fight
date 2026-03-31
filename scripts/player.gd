extends CharacterBody2D

const SPEED := 200.0
const JUMP_VELOCITY := -600.0
const GRAVITY := 980.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _attacking := false

func _ready() -> void:
	anim.animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	_attacking = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _attacking:
		if event.keycode == KEY_A:
			_attacking = true
			anim.play("punch")
		elif event.keycode == KEY_D:
			_attacking = true
			anim.play("kick")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * SPEED

	move_and_slide()

	if not _attacking:
		if not is_on_floor():
			anim.play("jump")
		elif direction != 0:
			anim.flip_h = direction < 0
			anim.play("walk")
		else:
			anim.play("idle")
