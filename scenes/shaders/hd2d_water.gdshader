shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded;

uniform sampler2D water_texture : source_color, repeat_enable, filter_nearest_mipmap;
uniform vec3 deep_color : source_color = vec3(0.03, 0.18, 0.25);
uniform vec3 glow_color : source_color = vec3(0.12, 0.55, 0.7);
uniform vec3 foam_color : source_color = vec3(0.24, 0.62, 0.68);
uniform float tile_scale = 3.0;

void fragment() {
	vec2 flow_a = vec2(sin(TIME * 0.25) * 0.012, -TIME * 0.055);
	vec2 flow_b = vec2(-TIME * 0.018, -TIME * 0.026);
	vec4 a = texture(water_texture, UV * vec2(tile_scale, tile_scale * 2.8) + flow_a);
	vec4 b = texture(water_texture, UV * vec2(tile_scale * 0.62, tile_scale * 1.65) + flow_b);
	float ripple = mix(a.r, b.g, 0.42);
	float bank = smoothstep(0.88, 0.995, abs(UV.x * 2.0 - 1.0));
	float broken_foam = smoothstep(0.5, 0.78, b.b + sin(UV.y * 74.0 - TIME * 1.4) * 0.08);
	float foam = bank * broken_foam * 0.42;
	vec3 water = mix(deep_color, glow_color, ripple * 0.46);
	ALBEDO = mix(water, foam_color, foam);
	EMISSION = glow_color * pow(ripple, 4.0) * 0.22 + foam_color * foam * 0.08;
	ROUGHNESS = 0.3;
	METALLIC = 0.03;
	ALPHA = 0.82;
}
