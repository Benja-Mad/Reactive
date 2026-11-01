shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform sampler2D artwork : source_color, filter_nearest;
uniform float luminance = 0.9;
void fragment() {
	vec3 color = texture(artwork, UV).rgb;
	// Slow refresh, restrained scan lines. No flashes or high-frequency glitch effects.
	float scan = mix(0.87, 1.0, step(0.22, fract(UV.y * 200.0)));
	float sweep = 1.0 + 0.035 * sin(UV.y * 5.0 - TIME * 0.4);
	ALBEDO = color * luminance * scan * sweep;
}
