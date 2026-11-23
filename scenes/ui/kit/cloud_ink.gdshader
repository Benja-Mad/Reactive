shader_type canvas_item;

// Print the cloud plate in one ink, fading back into the paper at the edges.
void fragment() {
	float tone = texture(TEXTURE, vec2(UV.x, UV.y * 0.76 + 0.12)).b;
	float margin = (1.0 - smoothstep(0.68, 1.0, UV.x)) * (1.0 - smoothstep(0.52, 1.0, UV.y));
	COLOR = vec4(vec3(0.22, 0.40, 0.44), (1.0 - smoothstep(0.32, 0.92, tone)) * 0.36 * margin);
}
