shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	ALBEDO = vec3(0.025, 0.035, 0.045);
	ALPHA = (1.0 - smoothstep(0.25, 1.0, radius)) * 0.48;
}
