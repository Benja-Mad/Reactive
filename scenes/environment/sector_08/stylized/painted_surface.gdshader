shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
#include "res://scenes/environment/sector_08/stylized/district_ink.gdshaderinc"

uniform vec4 paint : source_color = vec4(0.23, 0.29, 0.31, 1.0);
uniform bool pavement = false;
uniform bool south_pavement = false;
uniform bool replace_south = false;
uniform vec4 south_bounds = vec4(-34.0, -26.0, 34.0, 28.0);
uniform vec4 lane_paint : source_color = vec4(0.28, 0.32, 0.36, 1.0);
uniform vec4 boarding_paint : source_color = vec4(0.37, 0.39, 0.42, 1.0);
uniform vec4 line_paint : source_color = vec4(0.51, 0.482, 0.38, 1.0);
uniform bool obstacle_readability = false;
uniform bool city_aperture = false;
uniform float roof_cutoff = 10000.0;
varying vec3 world_point;
varying vec3 normal_world;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
	vec2 delta = world_point.xz - vec2(12.0,16.0);
	float angle = radians(34.38);
	vec2 transit = vec2(cos(angle)*delta.x-sin(angle)*delta.y, sin(angle)*delta.x+cos(angle)*delta.y);
	bool in_south = transit.y >= -5.0 && world_point.x >= south_bounds.x && world_point.x <= south_bounds.z && world_point.z >= south_bounds.y && world_point.z <= south_bounds.w;
	// Cut the old slab faces out of exactly the replacement footprint. Leaving
	// their raised edges visible through a new plane caused the crossed grids.
	if (replace_south && in_south) { discard; }
	if (world_point.y > roof_cutoff) { discard; }
	float along = dot(world_point.xz, vec2(0.731354, -0.681998));
	if (city_aperture && along > 3.0 && along < 12.0) { discard; }
	// Broad, stepped patches instead of scan grain or normal-map sparkle.
	vec2 p = floor(world_point.xz * 8.0) / 8.0;
	float stain = sin(p.x * 0.71 + p.y * 0.43) * sin(p.y * 0.89 - p.x * 0.21);
	float shade = pavement ? (stain > 0.55 ? 0.95 : (stain < -0.65 ? 1.02 : 1.0)) : 1.0;
	vec3 pigment = paint.rgb;
	if (south_pavement) {
		// One coherent orientation and a continuous apron, including both ends.
		pigment = boarding_paint.rgb;
		if (transit.y >= 1.7 && transit.y < 9.5) { pigment = lane_paint.rgb; }
		else {
			float joint = mod(transit.x + 24.0, 8.0);
			if (joint < 0.035) { pigment *= 0.83; }
		}
		if (transit.y >= 1.7 && transit.y < 1.82) { pigment = line_paint.rgb; }
		if (transit.y >= 8.7 && transit.y < 8.81 && mod(transit.x,8.0) < 2.0) { pigment = mix(lane_paint.rgb,line_paint.rgb,0.6); }
	}

	ALBEDO = pigment * shade;
	ROUGHNESS = 0.95;
	METALLIC = 0.0;
	// Restrained ambient floor for solid cover: silhouettes stay readable in shadow.
	EMISSION = district_shadow(pigment,normalize(normal_world),pavement ? 1.0 : 0.0,0.0);
	if (obstacle_readability) { EMISSION += pigment*0.035; }
}

void light() {
	float facing = max(dot(NORMAL, LIGHT), 0.0);
	float response = LIGHT_IS_DIRECTIONAL ? district_face(facing) : district_local_face(facing);
	// A local light's incidence varies continuously across a flat floor.
	// Quantizing it makes concentric bands unrelated to architectural shadows.
	if (pavement && !LIGHT_IS_DIRECTIONAL) {
		response = facing;
	}
	// Grazing architecture cuts should not become broad pools on horizontal paving.
	float floor_weight = pavement ? (LIGHT_IS_DIRECTIONAL ? 1.15 : mix(0.22,1.0,smoothstep(0.55,0.85,facing))) : 1.0;
	float illumination = district_print_light(ATTENUATION * response * floor_weight,world_point,normal_world);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * illumination / PI;
}
