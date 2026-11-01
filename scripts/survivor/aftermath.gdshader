// What burnt or discharged matter leaves on the paving: a ragged dark scorch with a few glowing
// fissures, fading over its life. Alpha in the same hard steps as the other floor marks, so it
// reads as pixel art through the upscale.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float life = 1.0;
uniform bool electric = false;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ragged = 0.07 * sin(atan(p.y, p.x) * 13.0) + 0.04 * sin(p.x * 31.0);
	float edge = 1.0 - step(0.8 + ragged, r);
	float rim = edge * step(0.62 + ragged, r);
	float fissure = step(0.8, pow(max(0.0, sin(p.x * 18.0 + sin(p.y * 17.0))), 18.0)) * (1.0 - step(0.7, r));
	if (edge <= 0.0) discard;
	vec3 glow = electric ? vec3(0.6, 0.49, 0.16) : vec3(0.42, 0.11, 0.02);
	ALBEDO = mix(vec3(0.055, 0.035, 0.025), glow, fissure * life);
	float alpha = rim > 0.0 ? 0.45 : 0.75;
	ALPHA = (life > 0.5 ? alpha : alpha * 0.5);
}
