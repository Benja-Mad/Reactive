// The depot's merged props: one mesh per cluster, pigment carried in the vertex colour, lit with
// the district's painted-surface vocabulary so they sit with the rest of the yard. A vertex
// alpha below 1 marks a part that gives its own light (a cinder hole, a radio LED, a TV): the
// lower the alpha, the brighter it glows in its own colour.
shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
#include "res://scenes/environment/sector_08/stylized/district_ink.gdshaderinc"

varying vec3 world_point;
varying vec3 normal_world;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 pigment = to_linear(COLOR.rgb);
	float glow = 1.0 - COLOR.a;
	ALBEDO = pigment;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
	EMISSION = district_shadow(pigment, normalize(normal_world), 0.0, 0.0) + pigment * 0.035 + pigment * glow * 9.0;
}

void light() {
	float facing = max(dot(NORMAL, LIGHT), 0.0);
	float response = LIGHT_IS_DIRECTIONAL ? district_face(facing) : district_local_face(facing);
	float illumination = district_print_light(ATTENUATION * response, world_point, normal_world);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * illumination / PI;
}
