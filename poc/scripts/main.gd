extends Node3D

## "Isola di Mêlée" — proof of concept di adventure 3D cartoon.
## Tutto il mondo è costruito da codice: terreno procedurale, acqua, props CC0,
## personaggio giocante con collisioni, camera orbitale, verbi e dialoghi.

const ISLAND_RADIUS := 17.0
const TAU_F := TAU

const MODELS := {
	"hero": "res://assets/models/hero_adventurer.glb",
	"captain": "res://assets/models/npc_pirate_captain.glb",
	"parrot_pirate": "res://assets/models/npc_pirate.glb",
	"palm_01": "res://assets/models/palm_01.glb",
	"palm_02": "res://assets/models/palm_02.glb",
	"palm_03": "res://assets/models/palm_03.glb",
	"hut_01": "res://assets/models/hut_01.glb",
	"hut_02": "res://assets/models/hut_02.glb",
	"hut_03": "res://assets/models/hut_03.glb",
	"dock": "res://assets/models/dock_long.glb",
	"crate": "res://assets/models/crate.glb",
	"lantern": "res://assets/models/lantern.glb",
	"rock_01": "res://assets/models/rock_01.glb",
	"rock_large": "res://assets/models/rock_large.glb",
	"rocks_01": "res://assets/models/rocks_01.glb",
	"totem": "res://assets/models/totem.glb",
}

var player: AdventurePlayer
var camera_rig: Node3D
var ui: CanvasLayer
var outline_material: ShaderMaterial
var interactables := {}
var flags := {"grog": false, "quest_done": false}
var pending := {}
var hover_id := ""
var current_verb := "esamina"

var _dragging := false
var _blip: AudioStreamPlayer
var _ocean: AudioStreamPlayer
var _marker: Node3D

func _ready() -> void:
	randomize()
	_build_environment()
	_build_island()
	_build_water()
	_build_camera()
	_build_player()
	_populate()
	_build_ui()
	_build_audio()
	await get_tree().process_frame
	ui.show_dialogue([
		{"speaker": "Narratore", "text": "Sei naufragato sull'Isola di Mêlée. Il tuo nome? Non importa."},
		{"speaker": "Narratore", "text": "Il tuo problema, invece, ha un nome: il Capitano Rodomonte. Non parla con chi non ha del grog."},
	])

# ---------------------------------------------------------------- ambiente

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.10, 0.27, 0.54)
	sky_mat.sky_horizon_color = Color(0.80, 0.88, 0.93)
	sky_mat.sky_curve = 0.22
	sky_mat.ground_bottom_color = Color(0.06, 0.22, 0.34)
	sky_mat.ground_horizon_color = Color(0.55, 0.78, 0.86)
	sky_mat.sun_angle_max = 18.0

	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.76, 0.86, 0.93)
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -38, 0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color(0.6, 0.75, 1.0)
	fill.light_energy = 0.18
	fill.shadow_enabled = false
	add_child(fill)

	outline_material = ShaderMaterial.new()
	outline_material.shader = load("res://shaders/outline.gdshader")

func terrain_height(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var t := clampf(1.0 - r / ISLAND_RADIUS, 0.0, 1.0)
	var base := smoothstep(0.0, 0.55, t) * 1.35
	var n := (sin(x * 0.33) * cos(z * 0.29) + sin((x + z) * 0.17) * 0.7) * 0.22
	var edge := -0.38 * (1.0 - smoothstep(0.0, 0.28, t))
	return base + n * smoothstep(0.0, 0.4, t) + edge

func _ground_color(y: float, x: float, z: float) -> Color:
	var sand := Color(0.91, 0.81, 0.59)
	var grass := Color(0.31, 0.56, 0.27)
	var dark_grass := Color(0.20, 0.41, 0.19)
	var k := smoothstep(0.40, 0.85, y)
	var c := sand.lerp(grass, k)
	var v := sin(x * 1.7) * cos(z * 1.3) * 0.5 + 0.5
	c = c.lerp(dark_grass, k * v * 0.35)
	return c

func _build_island() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings := 26
	var segs := 72
	var center := Vector3(0.0, terrain_height(0.0, 0.0), 0.0)

	# vertici ad anelli, dal centro verso l'esterno
	var ring_pts: Array = []
	for i in range(rings + 1):
		var r := ISLAND_RADIUS * float(i) / float(rings)
		var row: Array = []
		for j in range(segs):
			var a := TAU_F * float(j) / float(segs)
			var x := cos(a) * r
			var z := sin(a) * r
			row.append(Vector3(x, terrain_height(x, z), z))
		ring_pts.append(row)

	# ventaglio centrale
	var first: Array = ring_pts[1]
	for j in range(segs):
		var a: Vector3 = first[j]
		var b: Vector3 = first[(j + 1) % segs]
		_add_tri(st, center, a, b)

	# quadi tra gli anelli
	for i in range(1, rings):
		var row_a: Array = ring_pts[i]
		var row_b: Array = ring_pts[i + 1]
		for j in range(segs):
			var jn := (j + 1) % segs
			var a0: Vector3 = row_a[j]
			var a1: Vector3 = row_a[jn]
			var b0: Vector3 = row_b[j]
			var b1: Vector3 = row_b[jn]
			_add_tri(st, a0, b0, a1)
			_add_tri(st, a1, b0, b1)

	st.generate_normals()
	var mesh := st.commit()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var col := _ground_color((a.y + b.y + c.y) / 3.0, (a.x + b.x + c.x) / 3.0, (a.z + b.z + c.z) / 3.0)
	for p in [a, b, c]:
		st.set_color(col)
		st.add_vertex(p)

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2000, 2000)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")

	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(0, 0.0, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ---------------------------------------------------------------- camera e player

func _build_camera() -> void:
	camera_rig = Node3D.new()
	camera_rig.set_script(load("res://scripts/camera_rig.gd"))
	camera_rig.name = "CameraRig"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 55.0
	cam.near = 0.1
	cam.far = 500.0
	camera_rig.add_child(cam)
	add_child(camera_rig)

func _build_player() -> void:
	player = AdventurePlayer.new()
	player.name = "Player"
	player.position = Vector3(0.5, terrain_height(0.5, 2.0) + 0.1, 2.0)
	player.rotation.y = PI

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.7
	col.shape = cap
	col.position = Vector3(0, 0.95, 0)
	player.add_child(col)

	add_child(player)

	var packed: PackedScene = load(MODELS["hero"])
	var inst: Node3D = packed.instantiate()
	inst.rotation.y = PI
	player.add_child(inst)

	var aabb := _node_aabb(inst)
	var h := maxf(aabb.size.y, 0.01)
	var s := 1.75 / h
	inst.scale = Vector3(s, s, s)
	_apply_toon(inst, false)
	aabb = _node_aabb(inst)
	inst.position.y -= aabb.position.y - player.global_position.y

	var ap := _find_anim_player(inst)
	if ap:
		player.setup_animations(ap)

	player.arrived.connect(_on_player_arrived)
	camera_rig.target_pos = player.global_position

# ---------------------------------------------------------------- props

func _apply_toon(root: Node3D, with_outline := false) -> void:
	# Il build glTF di questi pack è in centimetri: il contorno va calcolato
	# in unità di mondo, altrimenti diventa spesso quanto l'oggetto.
	var ws := root.global_transform.basis.get_scale().y
	if ws <= 0.0001:
		ws = 1.0
	var outline: ShaderMaterial = null
	if with_outline:
		outline = ShaderMaterial.new()
		outline.shader = outline_material.shader
		outline.set_shader_parameter("outline_width", 0.015 / ws)

	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var src := mi.get_active_material(s)
			if src is BaseMaterial3D:
				var mat: BaseMaterial3D = (src as BaseMaterial3D).duplicate()
				mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
				mat.roughness = 0.95
				mat.metallic = 0.0
				mat.metallic_specular = 0.1
				mat.rim_enabled = true
				mat.rim = 0.4
				mat.rim_tint = 0.55
				mat.next_pass = outline
				mi.set_surface_override_material(s, mat)

func _node_aabb(root: Node3D) -> AABB:
	var has := false
	var acc := AABB()
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = mi.get_aabb()
		var xf := mi.global_transform
		for i in range(8):
			var wp := xf * b.get_endpoint(i)
			if not has:
				acc = AABB(wp, Vector3.ZERO)
				has = true
			else:
				acc = acc.expand(wp)
	return acc

func _find_anim_player(root: Node) -> AnimationPlayer:
	var found := root.find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		return null
	return found[0] as AnimationPlayer

func spawn(id: String, model_key: String, x: float, z: float, opts := {}) -> Node3D:
	var packed: PackedScene = load(MODELS[model_key])
	var inst: Node3D = packed.instantiate()

	var holder := Node3D.new()
	holder.position = Vector3(x, 0.0, z)
	holder.rotation.y = float(opts.get("rot", 0.0))
	add_child(holder)
	holder.add_child(inst)

	var fit := String(opts.get("fit", "height"))
	var target := float(opts.get("size", 1.0))
	var aabb := _node_aabb(inst)
	if fit == "height" and aabb.size.y > 0.001:
		var s := target / aabb.size.y
		inst.scale = Vector3(s, s, s)
	elif fit == "length" and aabb.size.z > 0.001:
		var s2 := target / aabb.size.z
		inst.scale = Vector3(s2, s2, s2)

	aabb = _node_aabb(inst)
	var base_y := terrain_height(x, z) if not opts.has("y") else float(opts["y"])
	inst.position.y -= aabb.position.y - base_y

	if bool(opts.get("toon", true)):
		_apply_toon(inst, bool(opts.get("toon_outline", false)))

	aabb = _node_aabb(inst)
	if bool(opts.get("collide", true)) and aabb.size.length() > 0.01:
		var body := StaticBody3D.new()
		body.position = aabb.get_center()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(maxf(aabb.size.x, 0.2), maxf(aabb.size.y, 0.2), maxf(aabb.size.z, 0.2))
		shape.shape = box
		body.add_child(shape)
		if id != "":
			body.set_meta("interact_id", id)
		add_child(body)

	if id != "":
		var label := String(opts.get("label", id.capitalize()))
		interactables[id] = {"node": holder, "label": label}

	return holder

func _populate() -> void:
	# --- palme
	var palms := [
		["palm_01", 11.2, 7.6, 7.5, -0.4], ["palm_02", -11.6, 6.2, 8.0, 0.9],
		["palm_03", 10.2, -2.4, 7.0, 2.1], ["palm_01", -4.8, -6.8, 7.8, 0.3],
		["palm_02", 3.6, -6.2, 7.2, 1.4], ["palm_03", -10.6, -3.6, 8.2, -0.8],
		["palm_01", 12.2, 3.4, 6.5, 2.8], ["palm_02", -13.6, 7.4, 7.0, 0.2],
	]
	for p in palms:
		spawn("", p[0], p[1], p[2], {"size": p[3], "rot": p[4]})

	# --- rocce
	spawn("", "rocks_01", 8.8, 1.6, {"size": 1.1, "rot": 0.6})
	spawn("", "rock_large", -6.4, 6.2, {"size": 1.0, "rot": 1.9})
	spawn("", "rock_01", 4.2, 9.2, {"size": 1.2, "rot": 0.9})
	spawn("", "rock_large", -11.2, 1.4, {"size": 1.3, "rot": 2.6})
	spawn("", "rock_01", 2.6, -3.6, {"size": 0.9, "rot": 1.2})

	# --- capanne
	spawn("hut_a", "hut_01", 8.6, -5.4, {"size": 2.6, "rot": -0.5, "label": "Capanna del pescatore"})
	spawn("hut_b", "hut_02", -9.0, -2.2, {"size": 2.4, "rot": 0.7, "label": "Capanna del fabbro"})
	spawn("hut_c", "hut_03", -3.4, -9.4, {"size": 2.3, "rot": 0.2, "label": "Capanna vuota"})

	# --- molo che entra in acqua
	spawn("", "dock", 0.6, -14.6, {"size": 11.0, "fit": "length", "y": 0.55, "rot": 0.06})
	var dock_body := StaticBody3D.new()
	dock_body.position = Vector3(0.6, 0.55, -14.6)
	dock_body.set_meta("interact_id", "dock")
	var dock_shape := CollisionShape3D.new()
	var dock_box := BoxShape3D.new()
	dock_box.size = Vector3(3.4, 0.35, 11.0)
	dock_shape.shape = dock_box
	dock_body.add_child(dock_shape)
	add_child(dock_body)
	interactables["dock"] = {"node": dock_body, "label": "Molo malandato"}

	# --- casse
	spawn("crate_main", "crate", 2.4, -11.4, {"size": 0.9, "rot": 0.3, "label": "Cassa di legno"})
	spawn("", "crate", 3.4, -11.0, {"size": 0.8, "rot": 1.1})
	spawn("", "crate", 2.9, -10.2, {"size": 0.7, "rot": 0.7})

	# --- lanterna
	var lantern := spawn("lantern_main", "lantern", -6.6, -1.0, {"size": 1.6, "rot": 0.2, "label": "Lanterna"})
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.4, 0)
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 2.2
	light.omni_range = 7.0
	light.visible = false
	lantern.add_child(light)
	lantern.set_meta("light", light)

	# --- totem decorativo
	spawn("", "totem", 10.8, -1.8, {"size": 2.2, "rot": -0.3})

	# --- capitano
	var captain := spawn("captain", "captain", -1.8, -10.4, {"size": 1.85, "rot": 2.6, "collide": false, "toon_outline": false, "label": "Capitano Rodomonte"})
	_add_capsule_body(captain, "captain")
	var cap_ap := _find_anim_player(captain)
	if cap_ap:
		_play_idle(cap_ap)

	# --- pirata impagliato (statico)
	var parrot := spawn("parrot_pirate", "parrot_pirate", 6.8, 1.6, {"size": 1.8, "rot": -0.9, "collide": false, "toon_outline": false, "label": "Pirata immobile"})
	_add_capsule_body(parrot, "parrot_pirate")

func _add_capsule_body(holder: Node3D, id: String) -> void:
	var body := StaticBody3D.new()
	body.position = holder.global_position + Vector3(0, 0.9, 0)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.7
	shape.shape = cap
	body.add_child(shape)
	body.set_meta("interact_id", id)
	add_child(body)

func _play_idle(ap: AnimationPlayer) -> void:
	for n in ap.get_animation_list():
		var lower := String(n).to_lower()
		if lower.ends_with("idle") or lower.ends_with("|idle"):
			var a := ap.get_animation(n)
			if a:
				a.loop_mode = Animation.LOOP_LINEAR
			ap.play(n, 0.2)
			return

# ---------------------------------------------------------------- UI e audio

func _build_ui() -> void:
	var ui_script: GDScript = load("res://scripts/ui.gd")
	ui = ui_script.new()
	add_child(ui)
	ui.verb_changed.connect(_on_verb_changed)
	ui.dialogue_finished.connect(_on_dialogue_finished)

func _build_audio() -> void:
	_ocean = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://assets/audio/ocean.wav")
	if stream:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * float(stream.mix_rate))
		stream.loop_end = int(stream.data.size() / 2.0)
		_ocean.stream = stream
		_ocean.volume_db = -14.0
		add_child(_ocean)
		_ocean.play()

	_blip = AudioStreamPlayer.new()
	_blip.stream = load("res://assets/audio/blip.wav")
	_blip.volume_db = -10.0
	add_child(_blip)

func _blip_sound() -> void:
	if _blip:
		_blip.play()

func _on_verb_changed(verb: String) -> void:
	current_verb = verb

func _on_dialogue_finished() -> void:
	pass

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if ui.is_dialogue_open():
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			camera_rig.zoom(-1.2)
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			camera_rig.zoom(1.2)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_on_world_click(mb.position)
			return

	if event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		camera_rig.rotate_camera(mm.relative.x, mm.relative.y)

func _process(_delta: float) -> void:
	if ui == null:
		return
	if ui.is_dialogue_open() or _dragging:
		ui.set_hover("")
		return
	_update_hover(get_viewport().get_mouse_position())

func _update_hover(mouse_pos: Vector2) -> void:
	var hit := _raycast(mouse_pos)
	if hit.is_empty():
		hover_id = ""
		ui.set_hover("")
		return
	var collider: Object = hit.get("collider")
	if collider and collider.has_meta("interact_id"):
		var id := String(collider.get_meta("interact_id"))
		hover_id = id
		if interactables.has(id):
			ui.set_hover("▸ " + String(interactables[id]["label"]))
		else:
			ui.set_hover("")
	else:
		hover_id = ""
		ui.set_hover("")

func _raycast(screen_pos: Vector2) -> Dictionary:
	var cam: Camera3D = camera_rig.get_node("Camera3D")
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 300.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collide_with_areas = false
	q.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(q)

func _on_world_click(screen_pos: Vector2) -> void:
	if player == null:
		return
	var hit := _raycast(screen_pos)
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	if collider and collider.has_meta("interact_id"):
		var id := String(collider.get_meta("interact_id"))
		_begin_interaction(id)
		return
	# altrimenti: cammina verso il punto cliccato
	var point: Vector3 = hit.get("position")
	_set_marker(point)
	player.walk_to(point)

func _begin_interaction(id: String) -> void:
	if not interactables.has(id):
		return
	var node: Node3D = interactables[id]["node"]
	pending = {"id": id, "verb": current_verb}
	var dist := node.global_position.distance_to(player.global_position)
	if dist <= 2.2:
		_execute_pending()
		return
	# avvicinati restando a 1.5 m dall'oggetto
	var dir := node.global_position - player.global_position
	dir.y = 0.0
	dir = dir.normalized()
	var dest := node.global_position - dir * 1.5
	_set_marker(dest)
	player.walk_to(dest)

func _on_player_arrived() -> void:
	if pending.is_empty():
		return
	_execute_pending()

func _execute_pending() -> void:
	var id := String(pending.get("id", ""))
	var verb := String(pending.get("verb", "esamina"))
	pending = {}
	_blip_sound()
	match id:
		"crate_main":
			_crate(verb)
		"captain":
			_captain(verb)
		"parrot_pirate":
			_parrot(verb)
		"dock":
			_dock(verb)
		"lantern_main":
			_lantern(verb)
		"hut_a", "hut_b", "hut_c":
			_hut(verb)
		_:
			ui.show_dialogue([{"speaker": "Tu", "text": "Non succede niente di interessante."}])

# ---------------------------------------------------------------- dialoghi e quest

func _crate(verb: String) -> void:
	match verb:
		"esamina":
			ui.show_dialogue([{"speaker": "Tu", "text": "Una cassa di legno. Odora di mare, di muffa e di pessime decisioni."}])
		"usa", "prendi":
			if not flags["grog"]:
				flags["grog"] = true
				ui.set_objective("Obiettivo: porta il grog al Capitano Rodomonte.")
				ui.show_dialogue([
					{"speaker": "Tu", "text": "Infili la mano tra la paglia... una bottiglia di grog!"},
					{"speaker": "Tu", "text": "La cassa era piena di bottiglie. Chi l'avrebbe mai detto."},
				])
			else:
				ui.show_dialogue([{"speaker": "Tu", "text": "Vuota. Solo paglia e rimpianti."}])
		_:
			ui.show_dialogue([{"speaker": "Tu", "text": "Non è il momento di parlare con una cassa."}])

func _captain(verb: String) -> void:
	match verb:
		"parla":
			if flags["grog"] and not flags["quest_done"]:
				flags["quest_done"] = true
				ui.set_objective("Obiettivo completato: il molo è tuo. Per ora.")
				ui.show_dialogue([
					{"speaker": "Capitano Rodomonte", "text": "Per le cento balene! Del grog! Sei un mozzo con i fiocchi."},
					{"speaker": "Capitano Rodomonte", "text": "Tieni pure il molo. Il resto dell'isola... vedremo."},
					{"speaker": "Narratore", "text": "Il Capitano sorride. È la cosa più inquietante che tu abbia visto oggi."},
				])
			elif flags["grog"]:
				ui.show_dialogue([{"speaker": "Capitano Rodomonte", "text": "Ancora qui? Il molo non si pulisce da solo."}])
			else:
				ui.show_dialogue([{"speaker": "Capitano Rodomonte", "text": "Arrr! Non parlo con gli straccioni. Torna quando avrai del grog."}])
		"esamina":
			ui.show_dialogue([{"speaker": "Tu", "text": "Ha l'aria di chi non beve da tre giorni. E di chi non lava da tre anni."}])
		_:
			ui.show_dialogue([{"speaker": "Capitano Rodomonte", "text": "Togli le mani di dosso, mozzo."}])

func _parrot(verb: String) -> void:
	if verb == "parla":
		ui.show_dialogue([
			{"speaker": "Pappagallo", "text": "Pezzi di otto! Pezzi di otto!"},
			{"speaker": "Tu", "text": "Il pirata non risponde. Forse è di legno. Forse è solo educato."},
		])
	else:
		ui.show_dialogue([{"speaker": "Tu", "text": "Un pirata impagliato. Ha più vita lui di certi esseri umani."}])

func _dock(verb: String) -> void:
	if verb == "usa":
		ui.show_dialogue([{"speaker": "Tu", "text": "Ci sali sopra. Scricchiola in modo poco rassicurante."}])
	elif verb == "parla":
		ui.show_dialogue([{"speaker": "Tu", "text": "Il molo non risponde. Meglio così."}])
	else:
		ui.show_dialogue([{"speaker": "Tu", "text": "Un molo malandato. Regge per inerzia e per educazione."}])

func _lantern(verb: String) -> void:
	var light: OmniLight3D = interactables["lantern_main"]["node"].get_meta("light")
	if verb == "usa":
		if light:
			light.visible = not light.visible
		ui.show_dialogue([{"speaker": "Tu", "text": "La lanterna si accende. L'isola sembra subito meno spaventosa."}] if light and light.visible else [{"speaker": "Tu", "text": "Spegni la lanterna. Il buio, in fondo, aveva il suo fascino."}])
	else:
		ui.show_dialogue([{"speaker": "Tu", "text": "Una lanterna. Fa luce, il che è più di quanto faccia la maggior parte delle persone qui."}])

func _hut(verb: String) -> void:
	if verb == "usa":
		ui.show_dialogue([{"speaker": "Tu", "text": "La porta è chiusa. Dentro c'è odore di pesce e di segreti."}])
	else:
		ui.show_dialogue([{"speaker": "Tu", "text": "Una capanna. Il tetto è di foglie, le speranze di paglia."}])

# ---------------------------------------------------------------- marker di destinazione

func _set_marker(pos: Vector3) -> void:
	if _marker and is_instance_valid(_marker):
		_marker.queue_free()
	var m := Node3D.new()
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.28
	torus.outer_radius = 0.42
	torus.rings = 16
	torus.ring_segments = 8
	mi.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.4, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	m.add_child(mi)
	m.position = Vector3(pos.x, terrain_height(pos.x, pos.z) + 0.06, pos.z)
	add_child(m)
	_marker = m
	var tw := create_tween()
	tw.tween_property(m, "scale", Vector3(0.2, 0.2, 0.2), 0.8)
	tw.parallel().tween_property(mi, "transparency", 1.0, 0.8)
	tw.tween_callback(m.queue_free)
