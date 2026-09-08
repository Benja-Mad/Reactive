shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform float cs_network_load = 0.42;
uniform float cs_corruption = 0.08;
uniform float cs_wave_intensity = 0.72;
uniform vec2 cs_wave_direction = vec2(0.72, 0.68);
uniform float cs_wave_speed = 0.12;
uniform float cs_wave_width = 0.16;
uniform float cs_wave_phase = 0.0;
uniform float cs_effect_time = 0.0;
uniform sampler2D pattern_mask : repeat_enable, filter_nearest;
uniform float pattern_mix = 0.12;
instance uniform vec3 cs_local_coord = vec3(0.5);
instance uniform float cs_building_seed = 0.0;

void fragment() {
	vec2 cell_uv = fract(UV);
	float line = smoothstep(0.11, 0.02, min(min(cell_uv.x, 1.0 - cell_uv.x), min(cell_uv.y, 1.0 - cell_uv.y)));
	float spatial = dot(UV * 0.035 + cs_local_coord.xz, normalize(cs_wave_direction));
	float wave_distance = abs(fract(spatial - cs_effect_time * cs_wave_speed + cs_wave_phase) - 0.5);
	float wave = smoothstep(cs_wave_width, 0.0, wave_distance) * cs_wave_intensity;
	float mask_value = texture(pattern_mask, fract(UV / vec2(16.0))).r;
	vec3 base = vec3(0.018, 0.026, 0.034);
	vec3 network_color = mix(vec3(0.04, 0.48, 0.72), vec3(0.58, 0.03, 0.42), cs_corruption);
	ALBEDO = base + network_color * line * 0.035;
	ROUGHNESS = 0.62;
	METALLIC = 0.16;
	SPECULAR = 0.3;
	EMISSION = network_color * (line * wave * (1.2 + cs_network_load) + mask_value * pattern_mix * cs_network_load * 0.25);
}
