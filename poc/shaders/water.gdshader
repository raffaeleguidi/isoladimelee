shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.32, 0.76, 0.78);
uniform vec3 deep_color : source_color = vec3(0.03, 0.28, 0.45);
uniform float wave_height = 0.06;
uniform float wave_speed = 1.1;
uniform float alpha_min : hint_range(0.0, 1.0) = 0.55;
uniform float alpha_max : hint_range(0.0, 1.0) = 0.95;

void vertex() {
	VERTEX.y += sin(TIME * wave_speed + VERTEX.x * 0.35 + VERTEX.z * 0.27) * wave_height;
	VERTEX.y += cos(TIME * wave_speed * 0.7 + VERTEX.x * 0.11 - VERTEX.z * 0.19) * wave_height * 0.6;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	ALBEDO = mix(shallow_color, deep_color, fresnel);
	ALPHA = mix(alpha_min, alpha_max, fresnel);
	ROUGHNESS = 0.15;
	METALLIC = 0.0;
	SPECULAR = 0.55;
}
