// Facade-scale advertising screen for the Sector 08 foreground.
//
// Everything here is deliberately large: the panel sits inside the diorama's near-blur band, so
// it renders at roughly three mip levels down. Fine detail and text would be destroyed, while
// big blocks, a strong colour and a slow vertical scroll survive and read as a working screen.
shader_type spatial;
// Fully opaque on purpose. With an alpha pass the board drew after the diorama's world filter
// and came out razor sharp inside a foreground where everything else is three mips down --
// the same mismatch the access panel had.
render_mode cull_disabled, shadows_disabled, specular_disabled, unshaded;

uniform vec3 screen_tint : source_color = vec3(0.62, 0.16, 0.86);
uniform vec3 accent_tint : source_color = vec3(1.0, 0.36, 0.72);
uniform float brightness : hint_range(0.0, 8.0) = 2.2;
uniform float supply : hint_range(0.0, 1.2) = 1.0;
uniform float corruption : hint_range(0.0, 1.0) = 0.0;
uniform float panel_columns = 7.0;
uniform float panel_rows = 4.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.7, 289.1))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	// Panel grid: a facade screen is an array of modules with dark seams between them.
	vec2 cell = vec2(uv.x * panel_columns, uv.y * panel_rows);
	vec2 cell_id = floor(cell);
	vec2 cell_uv = fract(cell);
	float seam = smoothstep(0.0, 0.045, cell_uv.x) * smoothstep(0.0, 0.045, cell_uv.y)
		* smoothstep(0.0, 0.045, 1.0 - cell_uv.x) * smoothstep(0.0, 0.045, 1.0 - cell_uv.y);

	// Slow vertical wipe, so the screen is alive without pulling the eye off the gameplay.
	float wipe = fract(uv.y * 0.5 - TIME * 0.035);
	float band = smoothstep(0.0, 0.18, wipe) * smoothstep(0.55, 0.30, wipe);

	// A few modules run brighter content than their neighbours.
	float module = hash(cell_id);
	float lit = step(0.62, module);

	vec3 colour = screen_tint * (0.45 + 0.55 * band);
	colour = mix(colour, accent_tint, lit * (0.35 + 0.4 * band));

	// Scanlines at panel scale, not pixel scale, so they survive the blur.
	float scan = 0.88 + 0.12 * sin(uv.y * panel_rows * 34.0);
	colour *= scan * seam;

	// Dead modules: a screen this size always has some.
	float dead = step(0.94, hash(cell_id + 7.3));
	colour *= 1.0 - dead * 0.92;

	// Signal loss drives the whole board towards flicker and colour break-up.
	float glitch = step(1.0 - corruption * 0.55, hash(cell_id + floor(TIME * 6.0)));
	colour = mix(colour, colour.gbr * 1.4, glitch);

	ALBEDO = colour * brightness * supply;
}
