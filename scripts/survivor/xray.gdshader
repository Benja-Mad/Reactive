// Drawn only where something stands in front of the operator, so the silhouette survives a crowd.
shader_type spatial;
render_mode unshaded, depth_test_inverted, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.85, 0.52, 0.33, 0.75);
void vertex() {
	// Pulled toward the camera so the operator's own limbs never count as an occluder.
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	view.z += 0.7;
	POSITION = PROJECTION_MATRIX * view;
}
void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = tint.a;
}
