// Held water, drawn in the crew's pixel language. Lying down it is a puddle on the yard floor: an
// uneven wet patch that darkens the ground under it, glossy streaks where the lamps reflect, a lip
// that catches the light on the near side and shades on the far one, and the rain landing in it as
// little rings. Raised, it gathers into a sphere with circulating bands. An explicit wall
// command makes a curtain with climbing streams instead.
// It fades by dithering, never by going soft.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, shadows_disabled, fog_disabled;

#include "res://scripts/matter/matter_common.gdshaderinc"

uniform bool wall = false;
uniform bool orb = false;
uniform vec3 extent = vec3(4.0, 0.12, 3.0);
uniform float rise : hint_range(0.0, 1.2) = 1.0;
uniform float presence : hint_range(0.0, 1.0) = 1.0;
uniform vec4 deep_color : source_color = vec4(0.024, 0.09, 0.125, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.082, 0.353, 0.42, 1.0);
uniform vec4 line_color : source_color = vec4(0.184, 0.663, 0.761, 1.0);
uniform vec4 glint_color : source_color = vec4(0.576, 0.953, 1.0, 1.0);
uniform vec4 foam_color : source_color = vec4(0.937, 0.996, 1.0, 1.0);
// About two pixels of the yard's grid, in metres.
uniform float line = 0.06;

varying vec3 local;
varying float height01;
varying float edge_sdf;
varying vec3 world;

// An uneven footprint: an oval with a few lobes spilling out of it, so no two puddles share a
// shape. Fixed once it lies there -- water does not crawl. Negative inside.
float puddle_sdf(vec2 p) {
	vec2 half_size = max(extent.xz * 0.5, vec2(0.3));
	float small = min(half_size.x, half_size.y);
	float d = (length(p / (half_size * 0.78)) - 1.0) * small * 0.78;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float a = fi * 1.2566 + seed * 2.1 + hash13(vec3(seed, fi, 1.0)) * 0.9;
		vec2 c = vec2(cos(a), sin(a)) * half_size * mix(0.4, 0.55, hash13(vec3(fi, seed, 2.0)));
		float r = small * mix(0.28, 0.42, hash13(vec3(seed, 3.0, fi)));
		d = min(d, length(p - c) - r);
	}
	return d + (fbm(vec3(p * 1.6, seed)) - 0.5) * 0.22;
}

float curtain_flow(vec2 p) {
	// p.x along the wall, p.y up. Streams climb; their phase drifts so nothing tiles.
	float streams = fbm(vec3(p.x * 3.4, p.y * 0.9 - TIME * 1.35, seed));
	float fine = value_noise(vec3(p.x * 14.0, p.y * 2.2 - TIME * 2.4, seed + 3.0));
	return streams * 0.8 + fine * 0.2;
}

void vertex() {
	local = VERTEX;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (orb) {
		height01 = clamp(VERTEX.y / extent.y + 0.5, 0.0, 1.0);
		VERTEX += NORMAL * sin(VERTEX.y * 7.0 + TIME * 2.2 + seed) * 0.025;
		edge_sdf = -1.0;
	} else if (wall) {
		height01 = clamp(VERTEX.y / extent.y + 0.5, 0.0, 1.0);
		float flow = curtain_flow(vec2(VERTEX.x, VERTEX.y));
		float side = sign(VERTEX.z);
		// Thicker at the base where it is fed, thinning toward a rolling crest.
		float body = mix(1.25, 0.7, height01);
		VERTEX.z = VERTEX.z * body + side * (flow - 0.5) * 0.07;
		// The crest leans over in the direction it is about to fall.
		VERTEX.z += smoothstep(0.75, 1.0, height01) * 0.07 * sin(VERTEX.x * 2.3 + TIME * 1.7);
		VERTEX.y += (sin(VERTEX.x * 3.3 + TIME * 2.1) * 0.08 + sin(VERTEX.x * 7.9 - TIME * 3.3) * 0.03) * smoothstep(0.7, 1.0, height01);
		// Both ends slump: the program holds the middle hardest.
		float end_fall = pow(clamp(abs(VERTEX.x) / (extent.x * 0.5), 0.0, 1.0), 5.0);
		VERTEX.y = (VERTEX.y + extent.y * 0.5) * (1.0 - end_fall * 0.45) - extent.y * 0.5;
		VERTEX.z *= 1.0 - end_fall * 0.5;
		// Rising from the puddle it was.
		VERTEX.y = (VERTEX.y + extent.y * 0.5) * rise - extent.y * 0.5;
		edge_sdf = -1.0;
	} else {
		height01 = 0.0;
		edge_sdf = 0.0;
		VERTEX.y += 0.012;
	}
}

// Ordered dither: 1 where `amount` covers this screen pixel.
float dither(vec2 frag, float amount) {
	ivec2 q = ivec2(mod(frag, 4.0));
	int i = q.x + q.y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return step((m[i] + 0.5) / 16.0, amount);
}

float band(float d, float w) {
	return step(abs(d), w * 0.5);
}

void fragment() {
	vec3 color = deep_color.rgb;
	float metallic = 0.0;
	float roughness = 1.0;
	vec3 emission = vec3(0.0);
	float alpha;
	float t = TIME;
	float sdf = -1.0;
	if (orb) {
		float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float flow = fbm(local * 3.5 + vec3(TIME * 0.6, -TIME, seed));
		color = mix(deep_color.rgb, shallow_color.rgb, step(0.4, flow));
		color = mix(color, line_color.rgb, step(0.62, flow));
		color = mix(color, glint_color.rgb, step(facing, 0.3));
		float swirl = step(0.96, sin(local.y * 19.0 + atan(local.z, local.x) * 3.0 - TIME * 3.5));
		color = mix(color, glint_color.rgb, swirl * 0.8);
		alpha = 0.96;
	} else if (wall) {
		vec2 p = local.xy;
		float h = curtain_flow(p);
		float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		// Climbing streams: two stepped bands, thin bright threads racing up through them.
		color = mix(color, shallow_color.rgb, step(0.56, h));
		color = mix(color, line_color.rgb, step(0.7, h));
		float thread = step(0.86, value_noise(vec3(p.x * 26.0, p.y * 1.4 - t * 3.4, seed + 9.0)));
		color = mix(color, glint_color.rgb, thread);
		// Foam where it is fed at the base and where it rolls over at the crest.
		float crest = step(0.93 - 0.05 * value_noise(vec3(p.x * 9.0, t * 3.0, seed)), height01);
		float feed = step(height01, 0.08 * value_noise(vec3(p.x * 7.0, t * 2.0, seed + 5.0)) + 0.02);
		color = mix(color, glint_color.rgb, max(crest, feed));
		color = mix(color, foam_color.rgb, crest * step(0.97, height01));
		// Its edges catch the light: a cyan line round the silhouette.
		color = mix(color, line_color.rgb, step(facing, 0.25));
		alpha = mix(0.82, 1.0, max(max(crest, feed), step(facing, 0.25)));
	} else {
		vec2 p = local.xz;
		sdf = puddle_sdf(p);
		if (sdf > 0.0) discard;
		// The water itself: the floor seen through it, darkened and cooled.
		alpha = 0.6;
		// Lamps reflected as thin streaks straight down the screen, as reflections in a puddle run,
		// broken into lengths and in two steps.
		float column = hash13(vec3(floor(FRAGCOORD.x), seed, 3.0));
		float length_on = step(0.5, value_noise(vec3(floor(FRAGCOORD.x) * 0.7, FRAGCOORD.y * 0.06, seed)));
		float streak = column * length_on;
		color = mix(color, shallow_color.rgb, step(0.86, streak));
		color = mix(color, line_color.rgb, step(0.95, streak) * 0.7);
		alpha = mix(alpha, 0.8, step(0.86, streak));
		// The lip: which way the edge faces decides whether it catches the light (toward the
		// camera) or sits in its own shade (away from it).
		float e = 0.05;
		vec2 grad = vec2(puddle_sdf(p + vec2(e, 0.0)) - sdf, puddle_sdf(p + vec2(0.0, e)) - sdf);
		vec3 outward = normalize((MODEL_MATRIX * vec4(grad.x, 0.0, grad.y, 0.0)).xyz + vec3(0.0001));
		float lip = step(-line, sdf);
		float near = step(0.25, outward.z);
		float far = step(outward.z, -0.25);
		color = mix(color, glint_color.rgb, lip * near);
		color = mix(color, vec3(0.01, 0.02, 0.035), lip * far);
		alpha = mix(alpha, 0.95, lip * max(near, far));
		// Rain: each patch of floor gets a drop now and then, a ring that opens and breaks up.
		vec2 cell = floor(world.xz / 0.7);
		float h = hash13(vec3(cell, 7.0 + seed));
		vec2 centre = (cell + 0.25 + 0.5 * vec2(h, hash13(vec3(cell, 11.0)))) * 0.7;
		float age = fract(TIME * 0.9 + h * 7.0);
		float ring = band(length((world.xz - centre) * vec2(1.0, 1.25)) - age * 0.3, line * 0.9);
		float drop = ring * step(age, 0.6) * step(sdf, -0.1) * dither(FRAGCOORD.xy, 1.0 - age * 1.2);
		color = mix(color, glint_color.rgb, drop);
		alpha = max(alpha, drop * 0.9);
		// A pulse through the program sends one bright ring racing out from the middle.
		float r = length(p / (extent.xz * 0.5));
		color = mix(color, line_color.rgb, band(r - fract(t * 1.5), 0.05) * step(0.05, pulse));
	}
	color = mix(color, foam_color.rgb, step(0.5, impact) * 0.7);
	nanite_coat(local, height01, color, metallic, roughness, emission);
	// A puddle has no height to carry the seam, so it runs just inside the rim instead.
	armed_seam(local, wall ? height01 : 0.32 + sdf, emission);
	ALBEDO = color + emission;
	// Coming and going it breaks up into pixels instead of thinning.
	ALPHA = alpha * dither(FRAGCOORD.xy, presence);
}
