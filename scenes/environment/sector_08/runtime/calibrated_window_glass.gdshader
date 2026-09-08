shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform float cs_power = 0.88;
uniform float cs_blackout = 0.0;
uniform float cs_wave_intensity = 0.72;
uniform vec2 cs_wave_direction = vec2(0.72, 0.68);
uniform float cs_wave_speed = 0.12;
uniform float cs_wave_width = 0.16;
uniform float cs_wave_phase = 0.0;
uniform float cs_effect_time = 0.0;
uniform float cs_corruption = 0.08;
instance uniform vec3 cs_local_coord = vec3(0.5);
instance uniform float cs_building_seed = 0.0;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 logical_cell = floor(UV + cs_local_coord.xz * 19.0);
	float room_seed = hash21(logical_cell + vec2(cs_building_seed * 17.0, cs_building_seed * 31.0));
	float rough_noise = hash21(logical_cell + vec2(4.7, 9.2));
	float occupancy = step(0.69, room_seed);
	float spatial = dot(cs_local_coord.xz, normalize(cs_wave_direction));
	float wave_distance = abs(fract(spatial - cs_effect_time * cs_wave_speed + cs_wave_phase) - 0.5);
	float wave = smoothstep(cs_wave_width, 0.0, wave_distance) * cs_wave_intensity;
	float fail_order = hash21(logical_cell + vec2(71.0, 13.0));
	float powered = 1.0 - smoothstep(fail_order - 0.08, fail_order + 0.08, cs_blackout);
	float edge_fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
	float grime = smoothstep(0.0, 0.22, fract(UV.y * 0.47 + room_seed));
	vec3 glass_tint = mix(vec3(0.024, 0.027, 0.03), vec3(0.055, 0.066, 0.075), edge_fresnel);
	glass_tint *= mix(0.86, 1.06, grime);
	vec3 reflected_city = mix(vec3(0.035, 0.075, 0.085), vec3(0.13, 0.025, 0.11), cs_corruption);
	vec3 warm = vec3(1.0, 0.31, 0.075);
	vec3 neutral = vec3(0.54, 0.44, 0.31);
	vec3 cool = vec3(0.18, 0.38, 0.48);
	vec3 room_color = mix(warm, neutral, smoothstep(0.34, 0.7, room_seed));
	room_color = mix(room_color, cool, smoothstep(0.9, 0.985, room_seed));
	vec2 room_uv = fract(UV);
	float blinds = mix(0.38, 1.0, smoothstep(0.08, 0.16, fract(room_uv.y * 5.0 + room_seed)));
	float recess = smoothstep(0.03, 0.18, room_uv.x) * smoothstep(0.03, 0.18, 1.0 - room_uv.x);
	float interior = occupancy * powered * cs_power * blinds * recess;
	vec3 wave_color = mix(vec3(0.035, 0.48, 0.82), vec3(0.62, 0.025, 0.42), cs_corruption);
	ALBEDO = glass_tint + reflected_city * edge_fresnel * 0.18 + room_color * interior * 0.025;
	ROUGHNESS = mix(0.3, 0.5, rough_noise);
	METALLIC = 0.04;
	SPECULAR = 0.66;
	EMISSION = room_color * interior * mix(0.14, 0.32, room_seed) + wave_color * wave * 0.96;
}
