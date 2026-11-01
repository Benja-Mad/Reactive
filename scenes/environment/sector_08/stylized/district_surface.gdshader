shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
#include "res://scenes/environment/sector_08/stylized/district_ink.gdshaderinc"
uniform vec4 pigment : source_color = vec4(0.3,0.35,0.36,1.0);
uniform float depth_tier = 0.0;
varying vec3 normal_world;
varying vec3 world_point;
void vertex() { world_point = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; normal_world = normalize(MODEL_NORMAL_MATRIX*NORMAL); }
void fragment() {
	vec3 face_normal = normalize(cross(dFdx(VERTEX),dFdy(VERTEX)));
	NORMAL = dot(face_normal,NORMAL) < 0.0 ? -face_normal : face_normal;
	vec3 surface_pigment = pigment.rgb;
	ALBEDO = surface_pigment;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	EMISSION = district_shadow(surface_pigment,normalize(normal_world),0.0,depth_tier);
}
void light() {
	float facing = max(dot(NORMAL,LIGHT),0.0);
	float hierarchy = mix(1.0,0.45,depth_tier);
	float response = LIGHT_IS_DIRECTIONAL ? district_face(facing) : district_local_face(facing);
	float illumination = district_print_light(ATTENUATION*response,world_point,normal_world);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * illumination*hierarchy / PI;
}
