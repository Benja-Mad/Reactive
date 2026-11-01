// A gravity field on the floor: a dark core, bands that flow in (well) or out (repulsor) and a
// hard neon rim. Alpha comes in three hard steps so it reads as pixel art through the upscale.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.55, 0.48, 1.0, 1.0);
// -1 flows inward, 1 outward.
uniform float flow = -1.0;
uniform float speed = 0.9;
uniform float life = 1.0;
// A one-shot ring at this fraction of the radius; negative for none.
uniform float pulse = -1.0;
uniform float core = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) discard;
	float a = atan(p.y, p.x) / 6.2831853;
	float bands = fract(r * 3.0 - TIME * speed * flow + a * (flow < 0.0 ? 1.0 : 0.0));
	float line = step(0.95, bands) * step(0.18, r) * step(pulse, -0.5);
	float rim = step(0.988, r) * step(pulse, -0.5);
	float ring = pulse >= 0.0 ? 1.0 - step(0.02, abs(r - pulse)) : 0.0;
	float pit = core * (1.0 - step(0.3, r));
	float alpha = max(max(line * 0.35, rim * 0.8), max(ring * 0.9, pit * 0.45));
	alpha = alpha > 0.7 ? 0.85 : (alpha > 0.4 ? 0.45 : (alpha > 0.0 ? 0.25 : 0.0));
	if (alpha <= 0.0) discard;
	ALBEDO = pit > 0.0 && line + rim + ring <= 0.0 ? tint.rgb * 0.12 : tint.rgb * (rim + ring > 0.0 ? 1.0 : 0.72);
	ALPHA = alpha * life;
}
