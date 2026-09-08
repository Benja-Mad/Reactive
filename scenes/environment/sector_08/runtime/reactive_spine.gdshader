shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform float cs_network_load = 0.42;
uniform float cs_corruption = 0.08;
uniform float cs_electric_activity = 0.35;
uniform float cs_effect_time = 0.0;
instance uniform vec3 cs_local_coord = vec3(0.5);
instance uniform float cs_building_seed = 0.0;

float hash11(float value) { return fract(sin(value * 91.3458) * 47453.5453); }

void fragment() {
	float segment = floor((UV.x + UV.y) * 9.0 + cs_building_seed * 17.0);
	float travelling = smoothstep(0.32, 0.0, abs(fract(segment * 0.113 - cs_effect_time * mix(0.18, 0.72, cs_network_load)) - 0.5));
	float malfunction = step(0.72, hash11(segment + floor(cs_effect_time * 8.0))) * cs_corruption;
	vec3 network_color = mix(vec3(0.08, 0.62, 0.92), vec3(0.72, 0.03, 0.38), malfunction);
	float activity = 0.28 + cs_network_load * 0.78 + travelling * (0.4 + cs_electric_activity * 0.5);
	ALBEDO = vec3(0.018, 0.035, 0.045) + network_color * 0.08;
	ROUGHNESS = 0.34;
	METALLIC = 0.28;
	SPECULAR = 0.52;
	EMISSION = network_color * activity * (0.72 + travelling * 1.35) * (1.0 - malfunction * 0.42);
}
