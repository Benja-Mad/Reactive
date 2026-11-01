// Sharp upscale of the world buffer: every buffer pixel stays a flat square at any window size,
// with only a one-screen-pixel blend at its edges so non-integer scales do not double columns.
shader_type canvas_item;

void fragment() {
	vec2 size = vec2(textureSize(TEXTURE, 0));
	vec2 texel = UV * size;
	vec2 centre = floor(texel) + 0.5;
	vec2 spread = max(fwidth(texel), vec2(1e-4));
	texel = centre + clamp((texel - centre) / spread, -0.5, 0.5);
	COLOR = texture(TEXTURE, texel / size);
}
