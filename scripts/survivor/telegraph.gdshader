// The danger marks on the yard floor, drawn in the crew's language instead of as flat slabs: the
// ground only darkens, the edges are thin rose piping that marches toward the hit, and the countdown
// is carried by light -- chevrons that come on one by one along a lane, or a ring that grows from
// the stolen seal at a landing's centre until it meets the edge. Hard edges, no gradients, so it
// sits on the pixel grid like the cards do.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// 0: landing ring, 1: lane.
uniform int shape = 0;
uniform float radius = 1.0;
uniform float span = 1.0;
uniform float width = 1.0;
// 0 = just warned, 1 = the hit lands now.
uniform float fill : hint_range(0.0, 1.0) = 0.0;
uniform vec4 danger : source_color = vec4(1.0, 0.231, 0.42, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.78, 0.86, 1.0);
uniform vec4 shade : source_color = vec4(0.09, 0.0, 0.03, 1.0);
// Line thickness in metres: about two pixels of the yard's grid.
uniform float line = 0.07;

varying vec3 local;

void vertex() {
	local = VERTEX;
}

float band(float d, float w) {
	return step(abs(d), w * 0.5);
}

void put(inout vec4 c, vec3 color, float a) {
	c.rgb = mix(c.rgb, color, a);
	c.a = max(c.a, a);
}

void fragment() {
	vec4 c = vec4(shade.rgb, 0.0);
	float t = TIME;
	float armed = step(0.9, fill);
	if (shape == 0) {
		vec2 p = local.xz;
		float r = length(p);
		float ang = atan(p.y, p.x);
		float inside = step(r, radius);
		put(c, shade.rgb, 0.32 * inside);
		// What the countdown has already claimed: a faint wash, edged by a hot ring.
		float reach = fill * (radius - line);
		put(c, danger.rgb, 0.16 * step(r, reach));
		put(c, hot.rgb, band(r - reach, line * 1.3) * step(0.02, fill));
		// The outline: dashes that turn slowly, closing to a solid ring as it lands.
		float dashes = max(armed, step(0.32, fract(ang / 6.2831853 * 28.0 + t * 0.35)));
		put(c, mix(danger.rgb, hot.rgb, armed * 0.6), band(r - radius + line * 0.5, line) * dashes);
		// Four ticks outside, like a sight.
		vec2 q = abs(p);
		float tick = max(band(q.y, line) * step(radius + 0.1, q.x) * step(q.x, radius + 0.32),
				band(q.x, line) * step(radius + 0.1, q.y) * step(q.y, radius + 0.32));
		put(c, danger.rgb, tick);
		// The seal at the centre: a broken ring with a bar through it, pulsing.
		float gap = step(0.7, ang) * step(ang, 1.5);
		float seal = band(r - 0.24, line) * (1.0 - gap);
		vec2 d = normalize(vec2(1.0, -1.0));
		seal = max(seal, band(dot(p, vec2(-d.y, d.x)), line) * step(abs(dot(p, d)), 0.34));
		put(c, mix(danger.rgb, hot.rgb, 0.5 + 0.5 * sin(t * 9.0)), seal);
	} else {
		float a = span * 0.5 - local.z;
		float x = local.x;
		float hw = width * 0.5;
		float inside = step(abs(x), hw) * step(0.0, a) * step(a, span);
		put(c, shade.rgb, 0.3 * inside);
		put(c, danger.rgb, 0.12 * inside * step(a, fill * span));
		// Edge piping, dashed and marching toward the end of the lane; solid once committed.
		float march = max(armed, step(0.36, fract(a / 0.42 - t * 2.4)));
		float edge = band(abs(x) - hw + line * 0.5, line) * step(0.0, a) * step(a, span);
		put(c, mix(danger.rgb, hot.rgb, armed * 0.6), edge * march);
		// Chevrons pointing down the lane, lit from the start as the countdown runs.
		float s = 0.85;
		float cell = floor(a / s);
		float k = mod(a, s);
		// Steep arms, so the arrow still reads once the camera's pitch squashes it.
		float chevron = band(k - (s * 0.75 - abs(x) * 1.1), line * 1.6) * step(abs(x), hw * 0.6);
		chevron *= step(0.0, a) * step(a, span - s * 0.6);
		float lit = step((cell + 0.5) * s, fill * span);
		float flicker = 0.85 + 0.15 * step(0.5, fract(t * 7.0 + cell * 0.37));
		put(c, mix(danger.rgb, hot.rgb, lit), chevron * mix(0.55, flicker, lit));
		// The end of the run: a bar across with its corners turned back.
		float cap = band(a - span + line * 0.6, line * 1.2) * step(abs(x), hw);
		cap = max(cap, band(abs(x) - hw + line * 0.5, line) * step(span - 0.28, a) * step(a, span));
		put(c, danger.rgb, cap);
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
