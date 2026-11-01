// Brasa's flame as pixel art (and, recoloured, any stream thrown along a line, like the Novia's jet): a tongue of fire drawn on a card that runs from her palm along the
// aim and turns to face the camera. Quantised to the yard's texel grid and to four steps of her
// palette -- core, hot, flame, ember -- with hard edges and no soft glow of its own; the scene's
// bloom does the rest. Noise scrolls toward the tip so it roars instead of sitting still.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// How many texels the card spans, along and across.
uniform vec2 texels = vec2(150.0, 54.0);
// 0..1: how far the tongue reaches along the card; it grows on and shrinks off.
uniform float power : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;
// Width at the source (0..1 of the card): a flame starts as a thin jet, a hose starts full.
uniform float throat = 0.1;
// How much it cools toward the tip: fire burns out, a jet of water carries to the end.
uniform float cool = 0.55;
uniform vec4 core : source_color = vec4(1.0, 0.941, 0.784, 1.0);
uniform vec4 hot : source_color = vec4(1.0, 0.678, 0.29, 1.0);
uniform vec4 flame : source_color = vec4(1.0, 0.416, 0.141, 1.0);
uniform vec4 ember : source_color = vec4(0.486, 0.165, 0.071, 1.0);
uniform vec4 soot : source_color = vec4(0.09, 0.05, 0.05, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 cell = floor(UV * texels);
	vec2 uv = (cell + 0.5) / texels;
	float t = TIME + seed;
	float reach = max(power, 0.001);
	float x = uv.x / reach;
	if (x > 1.0) discard;
	float y = abs(uv.y - 0.5) * 2.0;
	// The tongue: a thin jet off the palm that blooms, then tears apart toward the tip.
	float half_width = mix(throat, 0.92, pow(x, 0.5)) * (1.0 - 0.45 * smoothstep(0.7, 1.0, x));
	float churn = noise(vec2(cell.x * 0.16 - t * 26.0, cell.y * 0.2 + t * 4.0)) * 0.65
			+ noise(vec2(cell.x * 0.06 - t * 11.0, cell.y * 0.08 - t * 2.0)) * 0.35;
	float heat = 1.0 - y / half_width - (churn - 0.45) * (0.35 + x * 0.9) - x * x * cool;
	if (heat < 0.0) discard;
	vec3 color = soot.rgb;
	if (heat > 0.62) color = core.rgb;
	else if (heat > 0.4) color = hot.rgb;
	else if (heat > 0.2) color = flame.rgb;
	else if (heat > 0.07 || x < 0.75) color = ember.rgb;
	ALBEDO = color;
}
