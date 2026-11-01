// The operator's silhouette, drawn only where scenery or machines stand in front of them.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_inverted, depth_draw_never, shadows_disabled;
uniform sampler2D frame : source_color, filter_nearest;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform bool flip = false;
uniform vec4 tint : source_color = vec4(0.9, 0.55, 0.33, 0.8);

#include "res://scripts/survivor/operator_card.gdshaderinc"

void vertex() {
	MODELVIEW_MATRIX = card_modelview(VIEW_MATRIX, INV_VIEW_MATRIX, MODEL_MATRIX);
	// Pulled toward the camera so the card's own ground contact never reads as an occluder.
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.z += 0.7;
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	if (texture(frame, card_uv(UV, region, flip)).a < 0.5) discard;
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
}
