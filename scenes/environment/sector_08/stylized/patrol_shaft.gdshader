shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float strength = 0.0;
void fragment() {
	// A restrained faceted shaft makes the airborne source legible even where
	// the district's deliberately sparse volumetric fog would hide it.
	float ends = smoothstep(0.02,0.16,UV.y) * (1.0-smoothstep(0.55,1.0,UV.y));
	ALBEDO = vec3(0.67,0.65,0.86);
	// Fade the silhouette so the searchlight never reads as a translucent card.
	float silhouette = smoothstep(0.10,0.85,abs(dot(normalize(NORMAL),normalize(VIEW))));
	ALPHA = 0.018 * ends * strength * silhouette;
}
