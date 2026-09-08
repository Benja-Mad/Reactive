shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform float cs_network_load = 0.42;
uniform float cs_alert_level = 0.08;
uniform float cs_corruption = 0.08;
uniform float cs_power = 0.88;
uniform float cs_electric_activity = 0.35;
uniform float cs_wave_intensity = 0.72;
uniform vec2 cs_wave_direction = vec2(0.72, 0.68);
uniform float cs_wave_speed = 0.12;
uniform float cs_wave_width = 0.16;
uniform float cs_wave_phase = 0.0;
uniform float cs_blackout = 0.0;
uniform float cs_effect_time = 0.0;
uniform sampler2D pattern_mask : repeat_enable, filter_nearest;
uniform float pattern_mix = 0.0;
instance uniform vec3 cs_local_coord = vec3(0.5);
instance uniform float cs_building_seed = 0.0;
instance uniform float cs_route_index = 0.0;
instance uniform float cs_phase_offset = 0.0;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 logical_cell = floor(UV + cs_local_coord.xz * 23.0);
	vec2 room_uv = fract(UV);
	float seed = hash21(logical_cell + vec2(cs_building_seed * 11.0, cs_building_seed * 29.0));
	float color_seed = hash21(logical_cell + vec2(2.3, 8.7));
	float occupancy = step(0.64 + cs_blackout * 0.18, seed);
	float spatial = dot(cs_local_coord.xz, normalize(cs_wave_direction));
	float phase = spatial - cs_effect_time * cs_wave_speed + cs_wave_phase;
	float wave_distance = abs(fract(phase) - 0.5);
	float wave = smoothstep(cs_wave_width, 0.0, wave_distance) * cs_wave_intensity;
	float fail_order = hash21(logical_cell + vec2(43.0, 91.0));
	float blackout_front = smoothstep(fail_order - 0.075, fail_order + 0.075, cs_blackout);
	float flicker_band = smoothstep(0.04, 0.22, cs_blackout) * (1.0 - smoothstep(0.34, 0.52, cs_blackout));
	float flicker = step(0.48, hash21(logical_cell + floor(vec2(cs_effect_time * 13.0, cs_effect_time * 7.0)))) * flicker_band;
	float powered = clamp(cs_power * (1.0 - blackout_front) * (1.0 - flicker), 0.0, 1.0);
	vec3 warm = vec3(1.0, 0.32, 0.08);
	vec3 neutral = vec3(0.58, 0.48, 0.35);
	vec3 cool = vec3(0.17, 0.38, 0.5);
	vec3 room_color = mix(warm, neutral, smoothstep(0.42, 0.76, color_seed));
	room_color = mix(room_color, cool, smoothstep(0.9, 0.985, color_seed));
	float blind = mix(0.44, 1.0, smoothstep(0.08, 0.14, fract(room_uv.y * 6.0 + seed)));
	float side_occlusion = smoothstep(0.02, 0.16, room_uv.x) * smoothstep(0.02, 0.16, 1.0 - room_uv.x);
	float ceiling_falloff = mix(0.58, 1.0, pow(1.0 - room_uv.y, 2.0));
	float interior_depth = blind * side_occlusion * ceiling_falloff;
	float corrupt_tick = step(0.76, hash21(logical_cell + floor(cs_effect_time * 9.0))) * cs_corruption;
	vec3 corrupt_color = mix(vec3(0.5, 0.015, 0.2), vec3(0.08, 0.55, 0.4), hash21(logical_cell));
	float pattern = texture(pattern_mask, fract(UV / vec2(16.0))).r * pattern_mix;
	float base_light = occupancy * powered * mix(0.24, 0.62, seed) * interior_depth;
	vec3 reactive_color = mix(room_color, corrupt_color, corrupt_tick);
	vec3 wave_color = mix(vec3(0.05, 0.48, 0.82), vec3(0.56, 0.04, 0.62), cs_corruption);
	float route_pulse = smoothstep(0.12, 0.0, abs(fract(cs_effect_time * 0.08 - cs_phase_offset) - 0.5)) * cs_network_load;
	ALBEDO = vec3(0.012, 0.013, 0.014) + reactive_color * base_light * 0.1;
	ROUGHNESS = 0.64;
	SPECULAR = 0.2;
	EMISSION = reactive_color * base_light * (0.64 + cs_electric_activity * 0.2) + wave_color * wave * (0.94 + cs_network_load * 0.82) + vec3(0.72, 0.045, 0.015) * cs_alert_level * occupancy * 0.18 + reactive_color * pattern * powered * 0.46 + wave_color * route_pulse * 0.08;
}
