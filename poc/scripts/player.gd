extends CharacterBody3D
class_name AdventurePlayer

## Controller del personaggio giocante.
## Movimento "point & click": il giocatore clicca un punto e il personaggio ci va,
## con collisioni reali contro terreno e oggetti (CharacterBody3D + move_and_slide).

signal arrived

const GRAVITY := 18.0
const ACCEL := 30.0

@export var speed := 4.2
@export var model_yaw_offset := 0.0

var anim: AnimationPlayer
var _idle := ""
var _walk := ""
var _current := ""
var _target := Vector3.ZERO
var _has_target := false
var _arrived_emitted := true

func setup_animations(player: AnimationPlayer) -> void:
	anim = player
	_idle = _find_anim("idle")
	_walk = _find_anim("walk")
	_play(_idle)

func _find_anim(key: String) -> String:
	if anim == null:
		return ""
	for name in anim.get_animation_list():
		var lower := String(name).to_lower()
		if lower.ends_with(key) or lower.ends_with("|" + key):
			var a := anim.get_animation(name)
			if a != null:
				a.loop_mode = Animation.LOOP_LINEAR
			return name
	return ""

func walk_to(pos: Vector3) -> void:
	_target = pos
	_has_target = true
	_arrived_emitted = false

func stop() -> void:
	_has_target = false
	velocity.x = 0.0
	velocity.z = 0.0
	_play(_idle)

func is_moving() -> bool:
	return _has_target

func _play(name: String) -> void:
	if anim == null or name == "" or _current == name:
		return
	_current = name
	anim.play(name, 0.2)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = -0.1

	if _has_target:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.35:
			_has_target = false
			velocity.x = 0.0
			velocity.z = 0.0
			_play(_idle)
			if not _arrived_emitted:
				_arrived_emitted = true
				arrived.emit()
		else:
			var dir := to.normalized()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			var desired_yaw := atan2(-dir.x, -dir.z) + model_yaw_offset
			rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-12.0 * delta))
			_play(_walk)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)
		_play(_idle)

	move_and_slide()
