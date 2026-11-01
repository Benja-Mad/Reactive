// Shared vocabulary of programmable matter: the nanite coating, the armed seam, and the noise
// both phases are built from. Included by matter_water and matter_ice.

uniform bool coated = false;
uniform float coat_progress : hint_range(0.0, 1.0) = 1.0;
uniform bool armed = false;
uniform vec4 armed_color : source_color = vec4(1.0, 0.68, 0.32, 1.0);
uniform float impact = 0.0;
uniform float pulse = 0.0;
uniform float seed = 0.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i);
	float n100 = hash13(i + vec3(1, 0, 0));
	float n010 = hash13(i + vec3(0, 1, 0));
	float n110 = hash13(i + vec3(1, 1, 0));
	float n001 = hash13(i + vec3(0, 0, 1));
	float n101 = hash13(i + vec3(1, 0, 1));
	float n011 = hash13(i + vec3(0, 1, 1));
	float n111 = hash13(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amplitude;
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		amplitude *= 0.5;
	}
	return total;
}

// Distance to the nearest cell edge of a 3D Voronoi lattice: the fracture network.
float voronoi_edge(vec3 p) {
	vec3 cell = floor(p);
	vec3 local = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int z = -1; z <= 1; z++)
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec3 offset = vec3(float(x), float(y), float(z));
		vec3 jitter = vec3(hash13(cell + offset), hash13(cell + offset + 17.0), hash13(cell + offset + 41.0));
		float d = length(offset + jitter - local);
		if (d < first) { second = first; first = d; }
		else if (d < second) { second = d; }
	}
	return second - first;
}

// Hexagonal micro-lattice, the nanite cells. Returns distance to the cell wall (0 at the wall).
float hex_cells(vec2 p) {
	const vec2 s = vec2(1.0, 1.7320508);
	vec4 h = vec4(p, p - vec2(0.5, 1.0)) / s.xyxy;
	vec4 c = floor(h) + 0.5;
	vec4 a = vec4(p - c.xy * s, p - (c.zw + 0.5) * s);
	vec2 q = dot(a.xy, a.xy) < dot(a.zw, a.zw) ? a.xy : a.zw;
	q = abs(q);
	return 0.5 - max(dot(q, s * 0.5), q.x);
}

// The coating: brass cells that gather along channels and crawl, rather than a flat tint.
// `p` is in object space, `height` is 0 at the base and 1 at the top.
void nanite_coat(vec3 p, float height, inout vec3 albedo, inout float metallic, inout float roughness, inout vec3 emission) {
	if (!coated) return;
	float flow = fbm(vec3(p.x * 1.4 - TIME * 0.35, p.y * 2.2 + TIME * 0.18, p.z * 1.4 + seed));
	float channels = 1.0 - smoothstep(0.0, 0.16, abs(fract(p.y * 2.4 + flow * 0.9) - 0.5) - 0.28);
	float density = clamp(flow * 1.35 - 0.18 + channels * 0.55, 0.0, 1.0);
	// The swarm climbs from the base when the coating is first applied.
	float reach = coat_progress * 1.15;
	density *= 1.0 - smoothstep(reach - 0.15, reach, height);
	float cell = hex_cells(vec2(p.x + p.z, p.y) * 9.0);
	float cell_wall = 1.0 - smoothstep(0.02, 0.07, cell);
	float coverage = smoothstep(0.38, 0.62, density);
	vec3 brass = mix(vec3(0.33, 0.22, 0.09), vec3(0.62, 0.46, 0.22), cell_wall);
	albedo = mix(albedo, brass, coverage);
	metallic = mix(metallic, 0.88, coverage);
	roughness = mix(roughness, mix(0.42, 0.22, cell_wall), coverage);
	// Sparse cells relay a charge: a slow travelling glint, never a constant glow.
	float relay = pow(max(0.0, sin(p.x * 3.1 + p.y * 1.7 - TIME * 2.4 + flow * 6.0)), 18.0);
	float spark = step(0.86, hash13(floor(vec3(p.x + p.z, p.y, 0.0) * 9.0) + floor(TIME * 3.0)));
	emission += vec3(1.0, 0.62, 0.24) * coverage * cell_wall * (relay * 0.9 + spark * 0.35);
}

// The armed reaction: a seam of light running around the base of the construct.
void armed_seam(vec3 p, float height, inout vec3 emission) {
	if (!armed) return;
	float band = 1.0 - smoothstep(0.0, 0.03, abs(height - 0.12));
	float travel = 0.55 + 0.45 * sin(p.x * 2.2 + p.z * 2.2 - TIME * 3.4);
	emission += armed_color.rgb * band * travel * 1.6;
}
