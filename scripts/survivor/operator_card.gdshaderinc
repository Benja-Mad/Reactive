// Shared by the operator card and its silhouette pass: an upright, camera-facing card that
// keeps its node's scale, and the atlas region of the current animation frame.
mat4 card_modelview(mat4 view, mat4 inv_view, mat4 model) {
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 side = normalize(cross(up, inv_view[2].xyz));
	vec3 facing = normalize(cross(side, up));
	return view * mat4(vec4(side * length(model[0].xyz), 0.0), vec4(up * length(model[1].xyz), 0.0), vec4(facing * length(model[2].xyz), 0.0), model[3]);
}

vec2 card_uv(vec2 uv, vec4 area, bool mirrored) {
	if (mirrored) uv.x = 1.0 - uv.x;
	return area.xy + uv * area.zw;
}
