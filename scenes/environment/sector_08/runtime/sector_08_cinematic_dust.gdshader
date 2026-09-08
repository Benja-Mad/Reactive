// Airborne matter at several depths, drawn the way a lens would render it.
//
// These sit *in* the scene: depth tested, so a mote at 64 m is occluded by anything in front of
// it, and fog-affected, so distance drains it the same way distance drains everything else. They
// only skip depth *writing*, which is what any transparent sprite does.
//
// One shape family, not three characters. A dim speck of dust far outside the depth of field does
// not render as an aperture disc with a bright rim -- that only happens to a *bright point source*
// -- it renders as a large, very soft, low-contrast smudge. `softness` is that: 0 is a crisp
// speck at focus distance, 1 is the wide diffuse blob of the near layer. INSTANCE_ID still varies
// each mote's rotation, proportion and brightness, but around a coherent look rather than across
// three different ones.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform float opacity : hint_range(0.0, 1.0) = 0.12;
uniform float supply : hint_range(0.0, 1.2) = 1.0;
uniform vec3 tint : source_color = vec3(0.58, 0.65, 0.70);
uniform vec3 tint_warm : source_color = vec3(0.95, 0.72, 0.52);
/// 0 = everything is a sharp speck, 1 = everything is a fully defocused aperture disc.
uniform float softness : hint_range(0.0, 1.0) = 0.0;
/// How far each mote may stray from that look. Small on purpose: a field that varies wildly reads
/// as noise, not as dust.
uniform float variation : hint_range(0.0, 1.0) = 0.25;

varying flat vec3 mote;   // x rotation, y aspect, z brightness
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
	mote = vec3(
		hash(id + 0.17) * 6.2831,                            // orientation
		mix(1.0, mix(0.82, 1.28, hash(id + 5.31)), variation),  // gently non-circular
		mix(1.0, mix(0.62, 1.0, hash(id + 11.7)), variation));  // brightness spread
	// A few motes catch the sodium instead of the moonlight. Kept rare, so it reads as an
	// occasional warm accent rather than as two-tone confetti.
	mote_tint = mix(tint, tint_warm, step(0.88, hash(id + 41.3)));
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

	// A single falloff whose width and shoulder are driven by `softness`. Sharp motes concentrate
	// near the centre; defocused ones spread almost to the edge with barely any gradient, which is
	// what an out-of-focus dim source actually looks like.
	float concentration = mix(11.0, 1.5, softness);
	float shape = exp(-r * r * concentration);
	// A defocused mote is flatter across its middle than a gaussian, but only slightly. Lifting
	// it all the way to a plateau turned the near layer into a solid grey ball that washed out
	// whatever was behind it.
	shape = mix(shape, smoothstep(0.0, 1.0, shape) * 0.25 + shape * 0.75, softness);

	// Guarantee the edge is clean whatever the softness and proportion worked out to.
	shape *= 1.0 - smoothstep(0.86, 1.0, r);

	ALBEDO = mote_tint * COLOR.rgb;
	ALPHA = shape * mote.z * COLOR.a * opacity * mix(0.15, 1.0, clamp(supply, 0.0, 1.0));
}
