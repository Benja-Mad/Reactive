// Gravity on the floor, in the same hard pixel steps as the other fields. Violet is gravity's own
// colour; the ring and the wave front take the colour of the matter that makes them.
// A well (mode 0): faint spiral arms drawn in toward the ring, and the ring itself -- the well's
// matter going round counter-clockwise, as dashes, at the speed bodies ride it.
// A repulsor (mode 1): the front running out, then the bubble's rim and bands pushing outward.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.55, 0.48, 1.0, 1.0);
uniform vec4 matter : source_color = vec4(0.21, 0.78, 0.88, 1.0);
uniform float mode = 0.0;
// Fractions of the radius.
uniform float ring = 0.4;
uniform float front = -1.0;
uniform float bubble = 0.5;
// Turns a second the ring goes round.
uniform float turns = 0.33;
uniform float life = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) discard;
	float turn = atan(p.y, p.x) / 6.2831853;
	float arms = 0.0;
	float band = 0.0;
	float rim = 0.0;
	if (mode < 0.5) {
		// Three thin arms winding in from the edge to the ring; the pattern slides inward as it turns.
		float phase = fract(turn * 3.0 - log(max(r, 0.04)) * 1.4 + TIME * 0.7);
		arms = step(0.95, phase) * step(ring + 0.08, r) * step(r, 0.96);
		// The ring: matter in dashes going round, a lit edge either side.
		float on = 1.0 - step(0.045, abs(r - ring));
		float dash = step(0.38, fract(turn * 16.0 - TIME * turns * 16.0));
		band = on * dash;
		rim = (1.0 - step(0.012, abs(r - ring - 0.055))) + (1.0 - step(0.012, abs(r - ring + 0.055)));
		rim += step(0.985, r) * step(0.5, fract(turn * 48.0));
	} else {
		float inside = step(r, bubble) * (front >= 0.0 ? step(r, front) : 1.0);
		arms = inside * step(0.9, fract(r * 7.0 - TIME * 1.6)) * step(0.08, r);
		// The front: a hard bright edge in the matter's colour with a wash just behind it.
		band = front >= 0.0 ? 1.0 - step(0.035, abs(r - front)) : 0.0;
		arms = max(arms, front >= 0.0 ? step(r, front) * step(front - 0.16, r) : 0.0);
		rim = inside * (1.0 - step(0.015, abs(r - bubble))) * step(0.35, fract(turn * 32.0 + TIME * 0.4));
	}
	float alpha = max(max(arms * 0.3, rim * 0.6), band * 0.9);
	alpha = alpha > 0.7 ? 0.85 : (alpha > 0.4 ? 0.5 : (alpha > 0.0 ? 0.25 : 0.0));
	if (alpha <= 0.0) discard;
	ALBEDO = band > 0.0 ? matter.rgb : tint.rgb;
	ALPHA = alpha * life;
}
