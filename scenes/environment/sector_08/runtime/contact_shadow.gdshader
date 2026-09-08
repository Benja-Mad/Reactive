shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded, shadows_disabled;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radial = dot(centered, centered);
	ALBEDO = vec3(0.005, 0.008, 0.012);
	ALPHA = smoothstep(1.0, 0.18, radial) * 0.58;
}
