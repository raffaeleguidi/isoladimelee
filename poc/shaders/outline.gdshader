shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;

// Contorno "inverted hull": disegna il retro del mesh leggermente espanso
// e lo colora di scuro. Insieme al materiale toon dà il look cartoon.

uniform float outline_width : hint_range(0.0, 0.2) = 0.018;
uniform vec4 outline_color : source_color = vec4(0.06, 0.05, 0.09, 1.0);

void vertex() {
	VERTEX += normalize(NORMAL) * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = 1.0;
}
