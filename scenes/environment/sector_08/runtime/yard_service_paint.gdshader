shader_type spatial;
render_mode cull_disabled, depth_draw_never;

uniform sampler2D wear : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Use the same water scan as the slabs so abrasion follows the yard surface.
	float abrasion = texture(wear, world.xz * 0.75).r;
	float grit = texture(wear, world.xz * 3.1).r;
	float edge = smoothstep(0.0, 0.09, min(UV.x, 1.0-UV.x));
	ALBEDO = vec3(0.38, 0.32, 0.15);
	ROUGHNESS = 0.48;
	SPECULAR = 0.32;
	ALPHA = edge * smoothstep(0.16, 0.52, abrasion) * mix(0.25, 0.72, grit);
}
