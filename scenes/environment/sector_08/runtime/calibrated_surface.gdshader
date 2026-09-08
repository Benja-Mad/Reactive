shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

instance uniform vec4 cs_surface_color = vec4(0.16, 0.17, 0.18, 1.0);
instance uniform float cs_surface_roughness = 0.72;
instance uniform float cs_surface_metallic = 0.0;
instance uniform float cs_surface_kind = 0.0;
instance uniform float cs_surface_wetness = 0.0;
instance uniform float cs_surface_seed = 0.0;
instance uniform float cs_depth_fade = 0.0;
instance uniform float cs_architecture_fill = 0.0;
instance uniform float cs_local_contrast = 0.0;

varying vec3 world_position;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 coarse_cell = floor(world_position.xz * 0.34 + cs_surface_seed * 19.0);
	vec2 fine_cell = floor(world_position.xz * 2.7 + cs_surface_seed * 41.0);
	float broad = hash21(coarse_cell);
	float fine = hash21(fine_cell);
	float plane_breakup = sin(world_position.x * 0.31 + cs_surface_seed * 8.0) * sin(world_position.z * 0.27 - cs_surface_seed * 5.0);
	float value_variation = mix(0.955, 1.045, broad) + plane_breakup * 0.014 + (fine - 0.5) * 0.014;
	value_variation += (broad - 0.5) * cs_local_contrast * 0.13 + plane_breakup * cs_local_contrast * 0.028;
	value_variation = mix(value_variation, 1.0, cs_depth_fade * 0.52);
	float asphalt = 1.0 - smoothstep(0.5, 1.5, cs_surface_kind);
	float metal = smoothstep(1.5, 2.5, cs_surface_kind) * (1.0 - smoothstep(3.5, 4.5, cs_surface_kind));
	float concrete_seam = smoothstep(0.965, 0.995, max(abs(sin(world_position.x * 0.42)), abs(sin(world_position.z * 0.39)))) * asphalt;
	float rain_streak = smoothstep(0.83, 1.0, sin(world_position.y * 2.4 + world_position.x * 0.17 + cs_surface_seed * 13.0) * 0.5 + 0.5) * (1.0 - asphalt);
	vec3 base = cs_surface_color.rgb * value_variation;
	base *= mix(1.0, 0.83, concrete_seam * 0.22 + rain_streak * 0.08);
	base *= mix(1.0, 0.78, rain_streak * cs_local_contrast);
	base = mix(base, base * vec3(0.78, 0.86, 0.92), cs_surface_wetness * 0.1);
	base = mix(base, vec3(dot(base, vec3(0.299, 0.587, 0.114))) * vec3(0.82, 0.9, 0.98), cs_depth_fade * 0.34);
	ALBEDO = base;
	ROUGHNESS = clamp(mix(cs_surface_roughness, 0.22 + fine * 0.1, cs_surface_wetness), 0.12, 0.96);
	METALLIC = cs_surface_metallic;
	SPECULAR = mix(0.3, 0.62, clamp(metal + cs_surface_wetness * 0.38, 0.0, 1.0));
	AO = mix(mix(0.92, 1.0, fine), 1.0, clamp(cs_architecture_fill * 3.2, 0.0, 1.0));
	vec3 shared_night_floor = vec3(0.0011, 0.00155, 0.0021) * (1.0 - cs_depth_fade * 0.28);
	EMISSION = base * (0.025 + cs_architecture_fill) + shared_night_floor;
}
