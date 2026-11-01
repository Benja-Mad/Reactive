// A ring of water spreading on the floor where an ánima burst: one pixel-thin line that widens
// and breaks into dashes as it fades.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float radius = 0.9;
uniform float line = 0.06;
uniform vec4 color : source_color = vec4(0.576, 0.953, 1.0, 1.0);
varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 p = local.xz;
	float r = length(p);
	float ring = mix(0.15, radius, sqrt(progress));
	float dashes = step(progress * 0.9, fract(atan(p.y, p.x) / 6.2831853 * 18.0));
	float on = step(abs(r - ring), line * 0.5) * dashes;
	if (on < 0.5) discard;
	ALBEDO = color.rgb;
}
