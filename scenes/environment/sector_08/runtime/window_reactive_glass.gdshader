shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

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
	float occupancy = step(0.58, room_seed);
	float spatial = dot(cs_local_coord.xz, normalize(cs_wave_direction));
	float wave_distance = abs(fract(spatial - cs_effect_time * cs_wave_speed + cs_wave_phase) - 0.5);
	float wave = smoothstep(cs_wave_width, 0.0, wave_distance) * cs_wave_intensity;
	float fail_order = hash21(logical_cell + vec2(71.0, 13.0));
	float powered = 1.0 - smoothstep(fail_order - 0.08, fail_order + 0.08, cs_blackout);
	float edge_fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.0);
	float grime = smoothstep(0.0, 0.22, fract(UV.y * 0.47 + room_seed));
	vec3 glass_tint = mix(vec3(0.018, 0.032, 0.045), vec3(0.035, 0.075, 0.095), edge_fresnel);
	glass_tint *= mix(0.82, 1.08, grime);
	vec3 reflected_city = mix(vec3(0.02, 0.12, 0.16), vec3(0.16, 0.035, 0.18), cs_corruption);
	vec3 room_color = mix(vec3(1.0, 0.38, 0.12), vec3(0.28, 0.64, 0.78), smoothstep(0.48, 0.82, room_seed));
	vec2 room_uv = fract(UV);
	float blinds = mix(0.4, 1.0, smoothstep(0.08, 0.16, fract(room_uv.y * 5.0 + room_seed)));
	float recess = smoothstep(0.03, 0.18, room_uv.x) * smoothstep(0.03, 0.18, 1.0 - room_uv.x);
	float interior = occupancy * powered * cs_power * blinds * recess;
	vec3 wave_color = mix(vec3(0.04, 0.62, 1.0), vec3(0.72, 0.04, 0.55), cs_corruption);
	ALBEDO = glass_tint + reflected_city * edge_fresnel * 0.22 + room_color * interior * 0.035;
	ROUGHNESS = mix(0.24, 0.48, rough_noise);
	METALLIC = 0.08;
	SPECULAR = 0.72;
	EMISSION = room_color * interior * mix(0.28, 0.62, room_seed) + wave_color * wave * 1.25;
}
