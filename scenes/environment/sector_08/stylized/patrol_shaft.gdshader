shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = 0.0;
void fragment() {
	// The bright core of the drone's beam in the rain: a narrow shaft from the gimbal lamp to the
	// pool, never a broad wedge laid over the floor. The district has no global volumetric fog.
	float ends = smoothstep(0.0,0.08,UV.y) * (1.0-smoothstep(0.45,1.0,UV.y));
	ALBEDO = vec3(0.82,0.86,0.88);
	// Fade the silhouette so the searchlight never reads as a translucent card.
	float silhouette = smoothstep(0.10,0.85,abs(dot(normalize(NORMAL),normalize(VIEW))));
	ALPHA = 0.03 * ends * strength * silhouette;
}
