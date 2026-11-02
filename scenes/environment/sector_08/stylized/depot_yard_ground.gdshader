// The depot's floor, painted in one pass in the yard's own frame (u = screen right, v = toward the
// camera, the axes the buses and the fences follow). It replaces the slab lattice with what a
// night lot actually shows: saw-cut concrete panels, an asphalt strip along the street kerb,
// one faded north-south bus lane with wheel ruts, numbered bays on the east, a flush canaleta
// with its grate, damp that collects along it, oil where engines stood, patches and cracks
// where the pole came down, and the residue of every store (char, wet fan, scorch, rust).
// Low chroma throughout: the UI colours stay signals. Lit like the district's painted pavement.
shader_type spatial;
render_mode ambient_light_disabled;
#include "res://scenes/environment/sector_08/stylized/district_ink.gdshaderinc"

uniform vec4 concrete : source_color = vec4(0.349, 0.38, 0.416, 1.0);
uniform vec4 asphalt : source_color = vec4(0.27, 0.30, 0.33, 1.0);
uniform vec4 patch_tone : source_color = vec4(0.40, 0.41, 0.41, 1.0);
uniform vec4 paint_line : source_color = vec4(0.5, 0.51, 0.49, 1.0);
uniform vec4 oil : source_color = vec4(0.10, 0.10, 0.10, 1.0);
uniform vec4 rust : source_color = vec4(0.33, 0.22, 0.15, 1.0);
uniform vec4 char_tone : source_color = vec4(0.07, 0.065, 0.06, 1.0);
uniform vec4 steel : source_color = vec4(0.44, 0.47, 0.47, 1.0);
// Yard frame: u = dot(xz, U), v = dot(xz, V).
uniform vec2 axis_u = vec2(0.8241, -0.5664);
uniform vec2 axis_v = vec2(0.5664, 0.8241);
// The asphalt strip along the street kerb (v range).
uniform vec2 road_v = vec2(7.55, 13.3);
// The bus lane: centre u, half width, v extent.
uniform vec3 lane = vec3(9.0, 1.75, 0.0);
uniform vec2 lane_v = vec2(-18.0, 34.0);
// The canaleta: v of its centre line, u extent, half width.
uniform vec4 canal = vec4(-4.6, -19.5, 18.5, 0.19);
// Numbered bays on the east: u from..to, first v, pitch, count.
uniform vec4 bays = vec4(12.0, 19.5, -15.0, 3.6);
uniform int bay_count = 6;
// The bay apron in front of the micros: u from..to, v from..to. Wet asphalt, not panels.
uniform vec4 apron = vec4(13.6, 33.0, -12.6, 8.2);
// What wet paving gives back with no lamp over it: the overcast, a faint blue-grey.
uniform vec4 sky_sheen : source_color = vec4(0.10, 0.13, 0.16, 1.0);
// Residue and history spots: (u, v, radius, kind). Kinds: 0 char ring, 1 wet fan, 2 scorch,
// 3 rust/oil under scrap, 4 oil stain, 5 patch + cracks (impact), 6 damp low spot, 7 pad (wash bay).
uniform vec4 spots[40];
uniform int spot_count = 0;

varying vec3 world_point;
varying vec3 normal_world;
varying float wet;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 7.3) * 0.28 + noise(p * 4.3 + 1.7) * 0.17;
}
// Distance to the nearest edge of a jittered cell network: crack lines.
float crack_field(vec2 p) {
	vec2 c = floor(p);
	vec2 f = fract(p);
	float a = 8.0;
	float b = 8.0;
	for (int y = -1; y <= 1; y++)
	for (int x = -1; x <= 1; x++) {
		vec2 o = vec2(float(x), float(y));
		vec2 j = vec2(hash12(c + o), hash12(c + o + 19.1));
		float d = length(o + j - f);
		if (d < a) { b = a; a = d; } else if (d < b) { b = d; }
	}
	return b - a;
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// Snap to the yard's paint grain (8 per metre) so every mark reads as pixels through the upscale.
	vec2 xz = floor(world_point.xz * 12.0) / 12.0 + 1.0 / 24.0;
	float u = dot(xz, axis_u);
	float v = dot(xz, axis_v);
	vec2 uv = vec2(u, v);
	float big = fbm(uv * 0.11);
	float grain = hash12(floor(uv * 12.0));
	bool on_road = v > road_v.x && v < road_v.y;
	bool on_apron = u > apron.x && u < apron.y && v > apron.z && v < apron.w;
	vec3 pigment = (on_road || on_apron) ? asphalt.rgb : concrete.rgb;
	// Broad mottling, never a tile: low-frequency tone and the odd darker panel.
	pigment *= 0.92 + big * 0.16 + (grain - 0.5) * 0.025;
	float rough = 0.95;
	float damp = 0.0;
	if (on_apron && !on_road) {
		// The bay apron: asphalt the micros have polished, always a little wet, its entry line worn
		// along the bay mouths and an edge line where it meets the concrete.
		float sheen_patch = step(0.45, noise(uv * vec2(0.35, 0.22)));
		damp = max(damp, 0.35 + 0.3 * sheen_patch);
		float entry = step(abs(u - (bays.x - 0.25)), 0.07) * step(bays.z, v) * step(v, bays.z + bays.w * float(bay_count));
		float edge_line = step(abs(u - (apron.x + 0.2)), 0.06) * step(0.5, fract(v / 1.6));
		float wear = step(0.35, noise(vec2(u * 2.0, v * 0.8)));
		pigment = mix(pigment, paint_line.rgb, max(entry, edge_line) * wear * 0.5);
	} else if (!on_road) {
		// Saw-cut joints of 4.5 m panels: thin, worn and broken, a little lighter than the gaps they replace.
		vec2 cell = uv / 4.5 + vec2(0.37, 0.11);
		vec2 to_joint = abs(fract(cell) - 0.5) * 4.5;
		float joint = step(2.2, max(to_joint.x, to_joint.y));
		float worn = step(0.55, noise(uv * 0.9));
		pigment *= 1.0 - joint * worn * 0.08;
		// Every panel weathered a little differently.
		vec2 panel = floor(cell);
		pigment *= 0.96 + hash12(panel) * 0.07;
	} else {
		// Asphalt patches: rectangles of newer, darker tar cut into the strip.
		vec2 cell = floor(vec2(u / 3.1, v / 2.3));
		float h = hash12(cell + 3.0);
		vec2 f = fract(vec2(u / 3.1, v / 2.3));
		if (h > 0.72 && f.x > 0.12 && f.x < 0.86 && f.y > 0.18 && f.y < 0.8) pigment *= 0.86;
	}
	// The bus lane: two faded edge lines, wear eating them where the wheels run.
	float lane_d = abs(u - lane.x);
	bool in_lane = v > lane_v.x && v < lane_v.y;
	if (in_lane) {
		float edge = step(lane.y - 0.07, lane_d) * step(lane_d, lane.y + 0.07);
		float wear = step(0.38, noise(vec2(u * 3.0, v * 0.7)));
		pigment = mix(pigment, paint_line.rgb, edge * wear * 0.55);
		// Arrows every 14 m pointing south, in from the gate toward the bays: a stem and a head.
		float along = mod(v + 3.0, 14.0);
		float stem = step(abs(u - lane.x), 0.14) * step(0.4, along) * step(along, 2.6);
		float head = step(abs(u - lane.x), (3.9 - along) * 0.5) * step(2.6, along) * step(along, 3.9);
		pigment = mix(pigment, paint_line.rgb, max(stem, head) * step(0.3, noise(uv * 2.7)) * 0.4);
		// Wheel ruts: two darker, polished bands where every micro has run for years.
		float rut = step(abs(lane_d - 0.95), 0.2);
		pigment *= 1.0 - rut * 0.11;
		damp = max(damp, rut * step(0.45, noise(vec2(u * 0.8, v * 0.18))) * 0.7);
	}
	// Bays: lines along u at the bay pitch, each bay with oil where an engine stood.
	if (u > bays.x && u < bays.y) {
		for (int i = 0; i <= bay_count; i++) {
			float bv = bays.z + float(i) * bays.w;
			float line = step(abs(v - bv), 0.06) * step(0.33, noise(vec2(u * 2.2, bv)));
			pigment = mix(pigment, paint_line.rgb, line * 0.42);
			if (i < bay_count) {
				vec2 sump = vec2(bays.x + 4.2 + hash12(vec2(float(i), 2.0)) * 1.4, bv + bays.w * 0.5);
				float stain = fbm((uv - sump) * 1.7 + float(i));
				float d = length((uv - sump) * vec2(0.8, 1.2));
				float oil_mask = step(d + stain * 0.9, 1.1);
				pigment = mix(pigment, oil.rgb, oil_mask * 0.55);
				damp = max(damp, oil_mask * 0.6);
				// Tyre tracks turning in from the lane.
				float track = step(abs(abs(v - bv - bays.w * 0.5) - 0.95), 0.18) * step(u, bays.x + 5.0);
				pigment *= 1.0 - track * 0.08;
			}
		}
	}
	// Damp: the floor falls to the canaleta, so it is wetter near it and in the ruts.
	float to_canal = abs(v - canal.x);
	bool canal_span = u > canal.y && u < canal.z;
	if (canal_span) {
		float fall = 1.0 - smoothstep(0.3, 1.6, to_canal + (noise(uv * 0.5) - 0.5) * 1.2);
		damp = max(damp, step(0.5, fall) * 0.7);
	}
	// Spots: residue of the stores and the yard's history.
	for (int i = 0; i < spot_count; i++) {
		vec4 s = spots[i];
		vec2 d = uv - s.xy;
		float r = length(d);
		if (r > s.z * 1.6) continue;
		int kind = int(s.w + 0.5);
		float ragged = (fbm(uv * 1.9 + s.xy) - 0.5) * s.z * 0.5;
		if (kind == 0) {
			// Char: a sooty ring round a drum, ash flecks, a few cinders' black spots.
			float ring = step(r + ragged, s.z) * step(s.z * 0.28, r + ragged * 0.5);
			pigment = mix(pigment, char_tone.rgb, ring * (0.32 + 0.22 * step(0.5, noise(uv * 5.0))));
			float fleck = step(0.93, hash12(floor(uv * 10.0))) * step(r, s.z * 1.5);
			pigment = mix(pigment, vec3(0.38, 0.37, 0.35), fleck * 0.6);
		} else if (kind == 1) {
			// Wet fan: a dark, polished spread around a source, with tongues running to the canaleta.
			float tongue = step(0.7, noise(vec2(d.x * 0.9, d.y * 0.3) + s.xy));
			float mask = step(r + ragged * 0.6, s.z * 0.85) + tongue * step(r, s.z * 1.2) * step(0.0, d.y);
			mask = clamp(mask, 0.0, 1.0);
			pigment *= 1.0 - mask * 0.06;
			damp = max(damp, mask * 0.85);
		} else if (kind == 2) {
			// Scorch: burnt fan from arcs, cracked paint, a couple of molten spatters.
			float burn = step(r + ragged * 1.4, s.z);
			float streak = step(0.72, noise(vec2(atan(d.y, d.x) * 3.0, r * 0.6) + s.xy)) * step(r, s.z * 1.5);
			pigment = mix(pigment, char_tone.rgb, max(burn * 0.42, streak * 0.3));
			float spatter = step(0.965, hash12(floor(uv * 9.0))) * step(r, s.z * 1.2);
			pigment = mix(pigment, vec3(0.30, 0.31, 0.30), spatter * 0.5);
		} else if (kind == 3) {
			// Rust bleed and oil under a scrap heap.
			float bleed = step(r + ragged * 1.2, s.z);
			float drip = step(0.6, noise(uv * 2.4 + s.xy)) * step(r, s.z * 1.3);
			pigment = mix(pigment, rust.rgb, bleed * 0.3);
			pigment = mix(pigment, oil.rgb, drip * bleed * 0.3);
			damp = max(damp, drip * bleed * 0.3);
		} else if (kind == 4) {
			// An oil stain, fanned toward the fall.
			float mask = step(length(d * vec2(1.0, 0.7)) + ragged, s.z);
			pigment = mix(pigment, oil.rgb, mask * 0.42);
			damp = max(damp, mask * 0.7);
		} else if (kind == 5) {
			// Where the pole came down: a cut-and-filled patch, cracks running out of it.
			vec2 q = abs(vec2(dot(d, vec2(0.9, 0.44)), dot(d, vec2(-0.44, 0.9))));
			float patch_mask = step(q.x, s.z * 0.55) * step(q.y, s.z * 0.32);
			pigment = mix(pigment, patch_tone.rgb * (0.95 + grain * 0.06), patch_mask * 0.8);
			float crack = step(crack_field(uv * 0.85 + s.xy), 0.035) * step(r, s.z * 1.5) * (1.0 - patch_mask);
			pigment *= 1.0 - crack * 0.42;
			// The impact chip itself.
			float chip = step(r + ragged * 2.0, s.z * 0.18);
			pigment *= 1.0 - chip * 0.3;
		} else if (kind == 6) {
			// A low spot where rain sits: damp only.
			damp = max(damp, step(r + ragged * 1.5, s.z));
		} else if (kind == 7) {
			// The wash pad: smoother poured concrete, a raised lip line, fall lines to its drain.
			// Its edge is broken and stained, never a clean box.
			vec2 q = abs(d) + (noise(uv * 1.7) - 0.5) * 0.5;
			float pad = step(q.x, s.z) * step(q.y, s.z * 0.75);
			float score = step(abs(fract((d.x + d.y * 0.4) * 1.6) - 0.5), 0.05) * pad;
			pigment = mix(pigment, patch_tone.rgb * 0.92, pad * 0.28);
			pigment *= 1.0 - score * 0.06;
			// The pad's drain at its low corner.
			vec2 g = abs(d - vec2(s.z * 0.55, s.z * 0.5));
			float grate = step(g.x, 0.35) * step(g.y, 0.22);
			pigment = mix(pigment, pigment * mix(0.5, 0.9, step(0.5, fract(d.x * 6.0))), grate);
			damp = max(damp, pad * step(0.4, noise(uv * 1.1)) * 0.8);
		}
	}
	// The canaleta: a flush steel channel. Two angle-iron edges catch the light, the grating
	// between them is a continuous dark galvanised grey (its slots are finer than a pixel here, so
	// they are not drawn: drawn bars read as a dotted path across the fight). Wet, so it shines.
	// The channel uses the unsnapped position: the paint grain is a world-x/z grid, and the
	// canaleta runs diagonal to it, so snapped edges stair-step into dashes.
	float raw_to_canal = abs(dot(world_point.xz, axis_v) - canal.x);
	if (canal_span && raw_to_canal < canal.w) {
		float frame = step(canal.w - 0.08, raw_to_canal);
		vec3 grate = mix(pigment, steel.rgb, 0.45) * 0.66;
		pigment = mix(grate, mix(pigment, steel.rgb, 0.6) * 1.1, frame);
		damp = max(damp, 0.6);
		rough = 0.45;
	}
	pigment *= 1.0 - damp * 0.1;
	wet = damp;
	ALBEDO = pigment;
	ROUGHNESS = mix(rough, 0.18, damp);
	METALLIC = 0.0;
	SPECULAR = mix(0.0, 0.5, damp);
	EMISSION = district_shadow(pigment, normalize(normal_world), 1.0, 0.0);
	// Wet paving gives back the sky in long soft streaks down the view: a sheen, not a stain.
	float streak = 0.55 + 0.45 * noise(vec2(u * 0.9, v * 0.12));
	EMISSION += sky_sheen.rgb * damp * streak * 0.4;
}

void light() {
	float facing = max(dot(NORMAL, LIGHT), 0.0);
	float response = LIGHT_IS_DIRECTIONAL ? district_face(facing) : facing;
	float floor_weight = LIGHT_IS_DIRECTIONAL ? 1.15 : mix(0.22, 1.0, smoothstep(0.55, 0.85, facing));
	float illumination = district_print_light(ATTENUATION * response * floor_weight, world_point, normal_world);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * illumination / PI;
	// Damp concrete gives back the lamps as a tight, stepped glint: the only sparkle on the floor.
	if (wet > 0.01) {
		vec3 h = normalize(LIGHT + VIEW);
		float glint = pow(max(dot(NORMAL, h), 0.0), 28.0);
		// Only the tight core survives: under the mast a wide lobe read as a cream paint spill.
		glint = step(0.66, glint) * glint;
		SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * glint * wet * (LIGHT_IS_DIRECTIONAL ? 0.0 : 0.1);
	}
}
