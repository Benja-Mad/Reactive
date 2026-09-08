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
uniform float pattern_mix = 0.08;
instance uniform vec3 cs_local_coord = vec3(0.5);
instance uniform float cs_building_seed = 0.0;

void fragment() {
	vec2 cell_uv = fract(UV);
	float line = smoothstep(0.11, 0.02, min(min(cell_uv.x, 1.0 - cell_uv.x), min(cell_uv.y, 1.0 - cell_uv.y)));
	float spatial = dot(UV * 0.035 + cs_local_coord.xz, normalize(cs_wave_direction));
	float wave_distance = abs(fract(spatial - cs_effect_time * cs_wave_speed + cs_wave_phase) - 0.5);
	float wave = smoothstep(cs_wave_width, 0.0, wave_distance) * cs_wave_intensity;
	float mask_value = texture(pattern_mask, fract(UV / vec2(16.0))).r;
	vec3 base = vec3(0.045, 0.047, 0.05);
	vec3 network_color = mix(vec3(0.035, 0.4, 0.66), vec3(0.5, 0.025, 0.34), cs_corruption);
	ALBEDO = base + network_color * line * 0.032;
	ROUGHNESS = 0.66;
	METALLIC = 0.08;
	SPECULAR = 0.34;
	EMISSION = network_color * (line * wave * (0.92 + cs_network_load * 0.82) + mask_value * pattern_mix * cs_network_load * 0.16);
}
