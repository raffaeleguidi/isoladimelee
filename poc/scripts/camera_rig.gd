extends Node3D

## Camera orbitale che segue il personaggio.
## Tasto destro + trascinamento = ruota, rotella = zoom.

@export var distance := 9.5
@export var pitch := 0.40
@export var yaw := 0.22
@export var min_distance := 5.0
@export var max_distance := 20.0
@export var min_pitch := 0.18
@export var max_pitch := 1.15

var target_pos := Vector3.ZERO
var _cam: Camera3D

func _ready() -> void:
	_cam = get_node_or_null("Camera3D")
	global_position = target_pos + Vector3(0, 1.2, 0)

func _process(delta: float) -> void:
	var k := 1.0 - exp(-7.0 * delta)
	var desired := target_pos + Vector3(0, 1.2, 0)
	global_position = global_position.lerp(desired, k)
	rotation = Vector3(0.0, yaw, 0.0)
	if _cam:
		_cam.position = Vector3(0.0, sin(pitch) * distance, cos(pitch) * distance)
		_cam.look_at(global_position + Vector3(0, 0.6, 0), Vector3.UP)

func rotate_camera(delta_x: float, delta_y: float) -> void:
	yaw -= delta_x * 0.006
	pitch = clamp(pitch + delta_y * 0.004, min_pitch, max_pitch)

func zoom(amount: float) -> void:
	distance = clamp(distance + amount, min_distance, max_distance)
