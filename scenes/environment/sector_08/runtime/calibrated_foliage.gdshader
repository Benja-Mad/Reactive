shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

instance uniform vec4 cs_surface_color = vec4(0.05, 0.09, 0.055, 1.0);
instance uniform float cs_surface_seed = 0.0;
instance uniform float cs_depth_fade = 0.0;

varying vec3 world_position;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float cluster = hash21(floor(world_position.xz * 0.72 + cs_surface_seed * 23.0));
	float vertical = 0.9 + sin(world_position.y * 1.7 + cs_surface_seed * 9.0) * 0.06;
	vec3 base = cs_surface_color.rgb * mix(0.78, 1.18, cluster) * vertical;
	base = mix(base, vec3(dot(base, vec3(0.299, 0.587, 0.114))) * vec3(0.78, 0.9, 0.84), cs_depth_fade * 0.4);
	ALBEDO = base;
	ROUGHNESS = 0.82;
	METALLIC = 0.0;
	SPECULAR = 0.2;
	AO = 0.95;
	EMISSION = base * 0.018 + vec3(0.0007, 0.0011, 0.00085) * (1.0 - cs_depth_fade * 0.35);
}
