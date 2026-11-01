// Deployment preview: the routine's final form projected where it will stand. Scanlines climb
// it and its silhouette burns, so it reads as a promise of matter, not as matter.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform float strength = 1.0;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float edge = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.5);
	float scan = smoothstep(0.55, 1.0, fract(world.y * 9.0 - TIME * 1.6));
	float sweep = smoothstep(0.0, 0.06, fract(world.y * 0.5 - TIME * 0.45)) * (1.0 - smoothstep(0.06, 0.14, fract(world.y * 0.5 - TIME * 0.45)));
	float flicker = 0.9 + 0.1 * sin(TIME * 47.0 + world.x * 3.0);
	ALBEDO = color.rgb * (0.05 + edge * 0.9 + scan * 0.12 + sweep * 0.6) * strength * flicker;
}
