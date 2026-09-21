shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D pavement : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D authored_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal = false;
uniform float wetness = 0.8;
uniform float standing_water = 0.0;
uniform float fixture_power = 1.0;
uniform vec3 cyan_anchor = vec3(-18.0, 4.0, -15.0);
uniform vec3 amber_anchor = vec3(4.0, 6.0, -16.0);
uniform vec3 magenta_anchor = vec3(-25.0, 8.0, -12.0);
varying vec3 world;

float water_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	vec4 h = fract(sin(vec4(dot(cell,vec2(127.1,311.7)), dot(cell+vec2(1,0),vec2(127.1,311.7)), dot(cell+vec2(0,1),vec2(127.1,311.7)), dot(cell+vec2(1,1),vec2(127.1,311.7))))*43758.5453);
	return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);
}

// Broken, elongated reflection strokes, projected from the actual district fixtures.
float reflection(vec2 p, vec2 anchor, float width, float reach, float breakup) {
	vec2 d = p - anchor;
	float wobble = (water_noise(p*vec2(2.8,7.0))-0.5)*0.75;
	float lane = exp(-pow((d.x + wobble) / (width*(1.0+max(d.y,0.0)*0.025)), 2.0));
	float length_mask = smoothstep(-2.0, 1.0, d.y) * (1.0-smoothstep(2.0, reach, d.y));
	float scan = texture(pavement, p*vec2(0.31,1.15)+vec2(breakup*0.07)).r;
	float bars = mix(0.05, 1.0, smoothstep(0.24, 0.65, scan));
	bars *= mix(0.35, 1.0, water_noise(p*vec2(3.5,24.0)));
	return lane * length_mask * bars;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world.xz * 0.17;
	vec3 texel = texture(pavement, uv).rgb;
	float damp = texture(pavement, uv * 0.29 + vec2(0.21, 0.63)).r;
	// World-space islands continue across slab seams; their shape does not depend on
	// the scan's luminance or the rectangular silhouette of an authored puddle mesh.
	float basin = water_noise(world.xz*0.38)*0.72 + water_noise(world.xz*1.35)*0.28;
	float pool = smoothstep(0.34, 0.66, basin + (damp-0.5)*0.12) * wetness;
	pool = max(pool, standing_water*smoothstep(0.28,0.53,basin));
	// Preserve the scan's broad water marks without turning every grain into a glint.
	vec3 broad = texture(pavement, uv * 0.98 + vec2(0.015), 1.5).rgb;
	ALBEDO = mix(mix(texel, broad, 0.22) * vec3(0.30, 0.32, 0.35), vec3(0.009, 0.015, 0.026), pool * 0.62);
	float grain = texture(pavement, uv * 2.7).r;
	// 0.085 in standing water is a perfect mirror, and a perfect mirror under a sodium lamp
	// clips: the pool returned a blown white core, the warm twin of the cyan blob on the slabs.
	// It is raining, so the surface is agitated -- a rougher minimum both spreads the highlight
	// into a reflection you can read and is the more honest surface.
	ROUGHNESS = clamp(mix(0.57, 0.19, pool) + (grain - 0.5) * 0.23, 0.15, 0.76);
	METALLIC = 0.015;
	SPECULAR = 0.48;
	// Reflections retain the scan's irregular surface instead of a continuous glass skin.
	vec2 ripple_uv = world.xz + vec2(sin(world.z*5.0+TIME*1.3), cos(world.x*4.0-TIME))*0.035;
	float cloud = water_noise(ripple_uv*vec2(0.22,0.38));
	float sky_band = smoothstep(0.12, 0.88, cloud);
	// Dark navy bands retain the painted sky without filling the shadows with cyan.
	vec3 sky = mix(vec3(0.004,0.007,0.016),vec3(0.045,0.075,0.13),sky_band);
	float cyan = reflection(ripple_uv,cyan_anchor.xz,1.55,27.0,damp);
	float amber = reflection(ripple_uv,amber_anchor.xz,1.25,28.0,damp);
	float magenta = reflection(ripple_uv,magenta_anchor.xz,0.65,23.0,damp);
	// One expanding impact per sparse world-space cell; fades before the next impact.
	vec2 cell = floor(world.xz * 0.65);
	float seed = fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
	float age = fract(TIME*0.64+seed);
	float radius = length(fract(world.xz*0.65)-vec2(0.25+seed*0.5,0.55));
	float ring = (1.0-smoothstep(0.004,0.012,abs(radius-age*0.32))) * pow(1.0-age,2.0) * step(0.76,seed) * smoothstep(0.1,0.25,age);
	vec3 light_strokes = vec3(0.025,0.56,0.82)*cyan*0.85 + vec3(1.0,0.47,0.12)*amber*1.35 + vec3(0.95,0.08,0.43)*magenta*0.95;
	// Keep the broad sky in the lit surface so cover shadows can interrupt it.
	// A flat 0.45 of sky added straight into albedo made every pool read as spilled pale paint:
	// a diffuse wash with a hard edge, brightest where water should be darkest. Water is dark and
	// reflective, so the sky reaches it through the low roughness below, not through albedo.
	ALBEDO += pool * sky * 0.08;
	// Reflected fixtures are accents; physical lighting supplies the contact shadows.
	EMISSION = pool * (sky*0.08 + fixture_power*light_strokes*0.48 + (vec3(0.035,0.065,0.09)+fixture_power*light_strokes*0.12)*ring*0.62);
	if (has_normal) {
		NORMAL_MAP = texture(authored_normal, UV).rgb;
		NORMAL_MAP_DEPTH = mix(0.62, 0.25, pool);
	} else {
		// Microrelief comes from the generated scan, not an unrelated noise texture.
		float dx = texture(pavement, uv + vec2(0.001, 0.0)).r - texel.r;
		float dy = texture(pavement, uv + vec2(0.0, 0.001)).r - texel.r;
		NORMAL_MAP = normalize(vec3(-dx * 1.4, -dy * 1.4, 1.0)) * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = mix(0.55, 0.22, pool);
	}
}
