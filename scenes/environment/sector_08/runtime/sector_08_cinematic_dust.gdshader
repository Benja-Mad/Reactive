// Optical atmosphere for the diorama framing: motes at several depths, drawn as they would be
// by a lens rather than as lit geometry.
//
// The near layer sits ~13 m from the camera while the scene is focused ~88 m out, so those motes
// are far outside the depth of field. A real defocused point source is not a gaussian blob: it is
// the aperture itself, a soft-edged disc with a slightly brighter rim, because the out-of-focus
// image of a point is the shape of the iris. That rim is the whole reason it reads as "in front
// of the lens" instead of as fog, so it is worth the two extra instructions.
//
// Unshaded and depth-blind on purpose. These are not dust motes catching a lamp -- that job
// belongs to sector_08_particles.gd, which is shaded and lit by the scene. These sit optically
// in front of everything, including the world filter.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform float opacity : hint_range(0.0, 1.0) = 0.12;
uniform float supply : hint_range(0.0, 1.2) = 1.0;
uniform vec3 tint : source_color = vec3(0.58, 0.65, 0.70);
/// 0 = a soft grain of dust, 1 = a fully defocused aperture disc with a bright rim.
uniform float defocus : hint_range(0.0, 1.0) = 0.0;
/// Horizontal stretch. Anamorphic glass smears near highlights sideways; the far layers keep 1.0.
uniform float anamorphic : hint_range(1.0, 3.0) = 1.0;

void vertex() {
	// Billboard each quad without disturbing the emitter's world-space particle positions: the
	// parallax has to come from the camera actually moving past them.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.x /= anamorphic;
	float r = length(p);

	// Tight grain, for the layers that are near enough to focus.
	float grain = exp(-r * r * 5.5);

	// Defocused aperture: flat interior, soft shoulder, brighter at the edge.
	float disc = 1.0 - smoothstep(0.62, 0.98, r);
	float rim = smoothstep(0.34, 0.72, r) * (1.0 - smoothstep(0.72, 0.98, r));
	float bokeh = disc * 0.55 + rim * 0.85;

	float shape = mix(grain, bokeh, defocus);
	// COLOR.a carries the process material's fade in and out over the particle's life.
	ALBEDO = tint * COLOR.rgb;
	ALPHA = shape * COLOR.a * opacity * mix(0.15, 1.0, clamp(supply, 0.0, 1.0));
}
