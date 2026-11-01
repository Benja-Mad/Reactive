// An operator's pixel-art frame as a lit, upright card: it takes the yard's lamps and casts a
// real shadow, yet keeps a floor of its own colour so the art never sinks into the night.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;
uniform sampler2D frame : source_color, filter_nearest;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool flip = false;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.92, 0.82, 1.0);
uniform float self_light = 0.32;
// A one-texel cool contour, outside the art's own dark line: the crew reads against the night.
uniform vec4 outline_color : source_color = vec4(0.5, 0.58, 0.7, 1.0);

#include "res://scripts/survivor/operator_card.gdshaderinc"

void vertex() {
	MODELVIEW_MATRIX = card_modelview(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 uv = card_uv(UV, region, flip);
	vec4 texel = texture(frame, uv);
	vec3 art = texel.rgb;
	if (texel.a < 0.5) {
		vec2 texel_size = 1.0 / vec2(textureSize(frame, 0));
		float near = max(max(texture(frame, uv + vec2(texel_size.x, 0.0)).a, texture(frame, uv - vec2(texel_size.x, 0.0)).a), max(texture(frame, uv + vec2(0.0, texel_size.y)).a, texture(frame, uv - vec2(0.0, texel_size.y)).a));
		if (near < 0.5) discard;
		art = outline_color.rgb;
	}
	// Neon in the art (bright and saturated: visors, vents, wards) lights itself.
	float peak = max(art.r, max(art.g, art.b));
	float chroma = (peak - min(art.r, min(art.g, art.b))) / max(peak, 0.001);
	float neon = texel.a < 0.5 ? 0.0 : smoothstep(0.5, 0.8, peak) * smoothstep(0.3, 0.55, chroma);
	art = mix(art, flash_color.rgb, flash);
	ALBEDO = art;
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.35);
	EMISSION = art * (self_light + flash * 1.5 + neon * 1.6);
}
