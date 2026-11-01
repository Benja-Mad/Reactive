// Programmed ice: a row of grown crystal columns rather than a slab, drawn in the crew's pixel
// language. No scene lighting: each facet takes one step of the ice palette from its own key light
// (deep teal in shadow, cyan, pale on the lit tops), the silhouette is piped in pale cyan, a few
// dark cleavage lines show through the body, frost rims the base and tips, and the fracture
// network opens as hard bright lines with a dark split as the construct loses integrity.
shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_back, shadows_disabled, fog_disabled;

#include "res://scripts/matter/matter_common.gdshaderinc"

uniform bool orb = false;
uniform vec3 extent = vec3(4.0, 1.8, 0.2);
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float formation : hint_range(0.0, 1.2) = 1.2;
uniform vec4 shade_color : source_color = vec4(0.043, 0.173, 0.227, 1.0);
uniform vec4 core_color : source_color = vec4(0.082, 0.353, 0.42, 1.0);
uniform vec4 body_color : source_color = vec4(0.184, 0.663, 0.761, 1.0);
uniform vec4 lit_color : source_color = vec4(0.576, 0.953, 1.0, 1.0);
uniform vec4 white_color : source_color = vec4(0.937, 0.996, 1.0, 1.0);
uniform vec4 crack_color : source_color = vec4(0.012, 0.05, 0.07, 1.0);

varying vec3 local;
varying float height01;
varying float column;

void vertex() {
	local = VERTEX;
	height01 = clamp(VERTEX.y / max(extent.y, 0.05) + (orb ? 0.5 : 0.0), 0.0, 1.0);
	column = COLOR.r;
}

// One of five palette steps, 0 (shadow) to 4 (white).
vec3 ice_step(float i) {
	if (i < 0.5) return shade_color.rgb;
	if (i < 1.5) return core_color.rgb;
	if (i < 2.5) return body_color.rgb;
	if (i < 3.5) return lit_color.rgb;
	return white_color.rgb;
}

void fragment() {
	// Grown from the ground up: everything above the front is not there yet.
	float front = formation * 1.08;
	if (height01 > front) discard;
	vec3 p = local + vec3(seed * 3.1, 0.0, seed * 1.7);
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// The yard's key: high, from the left and toward the camera.
	float key = dot(n, normalize(vec3(-0.45, 0.75, 0.45)));
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// The facet's step: shadowed sides sit in the core, lit faces in the body, tops go pale.
	float tone = 1.0 + step(-0.1, key) + step(0.45, key) + step(0.85, key) * 0.6;
	// Growth ribs climb each column as a lighter step.
	float rib = step(0.93, sin((local.y * 6.5 + column * 7.0 + fbm(p * 1.2) * 1.4) * 3.14159));
	tone += rib * 0.9;
	// Frost: rough pale pixels where the column meets the ground, and along the very tips.
	float frost = step(height01, 0.12 + 0.1 * value_noise(p * 9.0)) + step(0.94 - 0.05 * value_noise(p * 7.0), height01);
	tone = max(tone, 3.0 * min(frost, 1.0));
	// A struck column flares two steps.
	tone += impact * 2.0;
	vec3 albedo = ice_step(floor(tone));
	// Cleavage planes seen through the body: thin dark lines, only on the faces turned to us.
	float cleave = voronoi_edge(p * vec3(1.3, 0.9, 1.3));
	albedo = mix(albedo, core_color.rgb, step(cleave, 0.035) * step(0.55, facing) * step(tone, 3.0));
	// The silhouette carries a line of pale light, like the cast's piping.
	albedo = mix(albedo, lit_color.rgb, step(facing, 0.22));
	// Fractures open as integrity drops: hard bright lines with a dark split down the middle.
	float edge = voronoi_edge(p * vec3(2.4, 1.6, 2.4));
	float spread = step(fbm(p * 0.8 + 2.0) * 0.9, damage * 1.25 - 0.15);
	float crack_width = 0.02 + damage * 0.05;
	albedo = mix(albedo, white_color.rgb, step(edge, crack_width) * spread * step(0.02, damage));
	albedo = mix(albedo, crack_color.rgb, step(edge, crack_width * 0.4) * spread * step(0.35, damage));
	// The growth front is a white band while it climbs.
	albedo = mix(albedo, white_color.rgb, step(front - 0.06, height01) * step(formation, 1.0));
	float metallic = 0.0;
	float roughness = 1.0;
	vec3 emission = vec3(0.0);
	nanite_coat(local, height01, albedo, metallic, roughness, emission);
	// Brass where the swarm covers it takes the same key light as the ice under it.
	albedo = mix(albedo, albedo * (0.55 + 0.6 * step(-0.1, key) + 0.3 * step(0.45, key)), metallic / 0.88);
	armed_seam(local, height01, emission);
	ALBEDO = albedo + emission;
}
