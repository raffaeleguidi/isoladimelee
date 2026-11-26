extends CanvasLayer

## HUD in stile adventure: barra dei verbi, etichetta oggetto, pannello dialogo,
## obiettivo corrente. Tutto costruito da codice per non dipendere da scene .tscn.

signal verb_changed(verb: String)
signal dialogue_finished

const VERBS := [
	["esamina", "ESAMINA"],
	["parla", "PARLA"],
	["usa", "USA"],
	["prendi", "PRENDI"],
	["vai", "VAI"],
]

const INK := Color(0.97, 0.94, 0.86)
const GOLD := Color(1.0, 0.82, 0.35)
const PANEL_BG := Color(0.05, 0.09, 0.13, 0.88)
const PANEL_BORDER := Color(0.85, 0.68, 0.32, 0.9)

var current_verb := "esamina"

var _lines: Array = []
var _line_index := 0
var _dialogue_panel: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _hint_label: Label
var _hover_label: Label
var _objective_label: Label
var _verb_bar: HBoxContainer
var _verb_buttons := {}

func _ready() -> void:
	layer = 10
	_build()

func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Titolo ---
	var title := Label.new()
	title.text = "ISOLA DI MÊLÉE"
	title.position = Vector2(28, 22)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("outline_size", 8)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "un proof of concept in stile adventure"
	subtitle.position = Vector2(30, 58)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.88, 0.9))
	subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	subtitle.add_theme_constant_override("outline_size", 6)
	root.add_child(subtitle)

	# --- Obiettivo ---
	_objective_label = Label.new()
	_objective_label.position = Vector2(30, 92)
	_objective_label.add_theme_font_size_override("font_size", 16)
	_objective_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	_objective_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_objective_label.add_theme_constant_override("outline_size", 6)
	root.add_child(_objective_label)
	set_objective("Obiettivo: trova del grog per il Capitano Rodomonte.")

	# --- Suggerimenti comandi ---
	_hint_label = Label.new()
	_hint_label.text = "click sinistro: interagisci   ·   tasto destro + trascina: ruota camera   ·   rotella: zoom"
	_hint_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hint_label.offset_left = -740
	_hint_label.offset_right = -24
	_hint_label.offset_top = 22
	_hint_label.offset_bottom = 46
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.85))
	_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hint_label.add_theme_constant_override("outline_size", 5)
	root.add_child(_hint_label)

	# --- Etichetta hover ---
	_hover_label = Label.new()
	_hover_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hover_label.offset_left = -400
	_hover_label.offset_right = 400
	_hover_label.offset_top = -118
	_hover_label.offset_bottom = -92
	_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hover_label.add_theme_font_size_override("font_size", 18)
	_hover_label.add_theme_color_override("font_color", GOLD)
	_hover_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hover_label.add_theme_constant_override("outline_size", 7)
	root.add_child(_hover_label)

	# --- Barra dei verbi ---
	_verb_bar = HBoxContainer.new()
	_verb_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_verb_bar.offset_top = -66
	_verb_bar.offset_bottom = -16
	_verb_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_verb_bar.add_theme_constant_override("separation", 10)
	root.add_child(_verb_bar)

	var group := ButtonGroup.new()
	for v in VERBS:
		var b := Button.new()
		b.text = v[1]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(120, 42)
		b.add_theme_font_size_override("font_size", 16)
		_style_button(b)
		b.pressed.connect(_on_verb_pressed.bind(v[0]))
		_verb_bar.add_child(b)
		_verb_buttons[v[0]] = b
	_verb_buttons["esamina"].button_pressed = true

	# --- Pannello dialogo ---
	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dialogue_panel.offset_left = -430
	_dialogue_panel.offset_right = 430
	_dialogue_panel.offset_top = -230
	_dialogue_panel.offset_bottom = -100
	_dialogue_panel.add_theme_stylebox_override("panel", _panel_style())
	_dialogue_panel.visible = false
	_dialogue_panel.gui_input.connect(_on_dialogue_input)
	root.add_child(_dialogue_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_dialogue_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 18)
	_speaker_label.add_theme_color_override("font_color", GOLD)
	box.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 17)
	_text_label.add_theme_color_override("font_color", INK)
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_text_label)

	var cont := Label.new()
	cont.text = "clicca per continuare"
	cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cont.add_theme_font_size_override("font_size", 11)
	cont.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 0.8))
	box.add_child(cont)

	# --- Crediti ---
	var credits := Label.new()
	credits.text = "asset 3D: Quaternius, Kenney, Kay Lousberg — CC0 (poly.pizza)"
	credits.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	credits.position = Vector2(-520, -22)
	credits.size = Vector2(400, 18)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credits.add_theme_font_size_override("font_size", 10)
	credits.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85, 0.7))
	credits.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	credits.add_theme_constant_override("outline_size", 4)
	root.add_child(credits)

func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.border_color = PANEL_BORDER
	s.set_border_width_all(2)
	s.set_corner_radius_all(12)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 8
	return s

func _style_button(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.11, 0.16, 0.82)
	normal.border_color = Color(0.45, 0.5, 0.55, 0.7)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)

	var hover := normal.duplicate()
	hover.bg_color = Color(0.12, 0.18, 0.24, 0.95)
	hover.border_color = GOLD

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.85, 0.68, 0.32, 0.95)
	pressed.border_color = Color(1, 0.9, 0.6)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(0.08, 0.07, 0.05))
	b.add_theme_color_override("font_hover_pressed_color", Color(0.08, 0.07, 0.05))

func _on_verb_pressed(verb: String) -> void:
	current_verb = verb
	verb_changed.emit(verb)
	if _verb_buttons.has(verb):
		_verb_buttons[verb].button_pressed = true

func set_objective(text: String) -> void:
	if _objective_label:
		_objective_label.text = "▸ " + text

func set_hover(text: String) -> void:
	if _hover_label:
		_hover_label.text = text

func is_dialogue_open() -> bool:
	return _dialogue_panel != null and _dialogue_panel.visible

func show_dialogue(lines: Array) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_line_index = 0
	_dialogue_panel.visible = true
	_verb_bar.visible = false
	_hover_label.visible = false
	_render_line()

func _render_line() -> void:
	var line: Dictionary = _lines[_line_index]
	_speaker_label.text = String(line.get("speaker", ""))
	_text_label.text = String(line.get("text", ""))

func advance_dialogue() -> void:
	if not is_dialogue_open():
		return
	_line_index += 1
	if _line_index >= _lines.size():
		_dialogue_panel.visible = false
		_verb_bar.visible = true
		_hover_label.visible = true
		dialogue_finished.emit()
	else:
		_render_line()

func _on_dialogue_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			advance_dialogue()
			get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_dialogue_open():
		return
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.keycode == KEY_SPACE or k.keycode == KEY_ENTER or k.keycode == KEY_ESCAPE:
			advance_dialogue()
			get_viewport().set_input_as_handled()
