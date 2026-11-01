shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
#include "res://scenes/environment/sector_08/stylized/district_ink.gdshaderinc"
varying vec3 world_point;
varying vec3 normal_world;
void vertex() { world_point = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; normal_world = normalize(MODEL_NORMAL_MATRIX*NORMAL); }
uniform vec4 pigment : source_color = vec4(0.25,0.28,0.28,1.0);
uniform float ink_fill = 0.09;
void fragment() {
	ALBEDO = pigment.rgb;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	// A quiet coloured shadow value instead of the scene-wide grey ambient.
	EMISSION = pigment.rgb * ink_fill;
}
void light() {
	float facing = max(dot(NORMAL,LIGHT),0.0);
	// Three broad face values; cast shadows remain geometric rather than painted.
	float cut = facing < 0.22 ? 0.08 : (facing < 0.65 ? 0.48 : 0.95);
	if (!LIGHT_IS_DIRECTIONAL) {
		cut = 0.08 + 0.4*smoothstep(0.12,0.32,facing) + 0.47*smoothstep(0.48,0.82,facing);
	}
	float response = mix(facing,cut,0.8);
	float weight = LIGHT_IS_DIRECTIONAL ? 0.55 : 1.0;
	float illumination = district_print_light(ATTENUATION*response*weight,world_point,normal_world);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * illumination / PI;
}
