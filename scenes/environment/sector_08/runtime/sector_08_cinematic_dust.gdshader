// Airborne matter at several depths, drawn the way a lens would render it.
//
// These sit *in* the scene: depth tested, so a mote at 64 m is occluded by anything in front of
// it, and fog-affected, so distance drains it the same way distance drains everything else. They
// only skip depth *writing*, which is what any transparent sprite does.
//
// Every particle differs. INSTANCE_ID seeds a per-mote random that picks one of three characters
// -- an out-of-focus aperture disc, a drawn-out streak, or a hard little speck -- and then varies
// its rotation, aspect, brightness and edge softness on top. Without that a layer reads as one
// sprite stamped a hundred times.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float opacity : hint_range(0.0, 1.0) = 0.12;
uniform float supply : hint_range(0.0, 1.2) = 1.0;
uniform vec3 tint : source_color = vec3(0.58, 0.65, 0.70);
uniform vec3 tint_warm : source_color = vec3(0.95, 0.72, 0.52);
/// 0 = everything is a sharp speck, 1 = everything is a fully defocused aperture disc.
uniform float defocus : hint_range(0.0, 1.0) = 0.0;
/// How far the per-particle character is allowed to stray from that average.
uniform float variation : hint_range(0.0, 1.0) = 0.7;

varying flat vec4 mote;   // x rotation, y aspect, z brightness, w character
varying flat vec3 mote_tint;

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void vertex() {
	// Billboard the quad without touching the emitter's world-space particle positions: the
	// parallax has to come from the camera genuinely moving past them.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);

	float id = float(INSTANCE_ID);
	float a = hash(id + 0.17);
	float b = hash(id + 5.31);
	float c = hash(id + 11.7);
	float d = hash(id + 23.9);
	mote = vec4(
		a * 6.2831,                          // free rotation, so no two share an orientation
		mix(1.0, mix(0.55, 2.6, b), variation),  // squashed to drawn-out
		mix(1.0, mix(0.35, 1.0, c), variation),  // brightness spread
		d);                                  // which character this one is
	// A minority of motes catch the sodium instead of the moonlight, which is what stops the
	// field reading as a single grey dust colour.
	mote_tint = mix(tint, tint_warm, step(0.82, hash(id + 41.3)) * variation);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;

	float s = sin(mote.x);
	float k = cos(mote.x);
	p = vec2(p.x * k - p.y * s, p.x * s + p.y * k);

	// Semi-axes normalised so the longer one is exactly one quad unit. That puts the whole
	// ellipse inside the quad's inscribed circle at any rotation, so r reaches 1 before the edge
	// on every axis and nothing can be cut off square. Dividing by the aspect alone -- as this
	// did before -- left the *other* axis running past the boundary at full opacity.
	vec2 axis = vec2(mote.y, 1.0);
	axis /= max(axis.x, axis.y);
	float r = length(p / axis);

	float speck = exp(-r * r * 9.0);
	float disc = (1.0 - smoothstep(0.30, 0.94, r)) * 0.55
		+ smoothstep(0.16, 0.52, r) * (1.0 - smoothstep(0.52, 0.94, r)) * 0.85;
	float streak = exp(-r * r * 3.4) * (0.45 + 0.55 * exp(-p.y * p.y * 26.0));

	// Blend the three characters by this mote's own draw, then bias the whole layer by `defocus`.
	float pick = mote.w;
	float shape = mix(speck, disc, clamp(defocus + (pick - 0.5) * variation, 0.0, 1.0));
	shape = mix(shape, streak, smoothstep(0.86, 1.0, pick) * variation);

	// Guarantee a clean edge no matter which character won the blend.
	shape *= 1.0 - smoothstep(0.86, 1.0, r);

	ALBEDO = mote_tint * COLOR.rgb;
	ALPHA = shape * mote.z * COLOR.a * opacity * mix(0.15, 1.0, clamp(supply, 0.0, 1.0));
}
