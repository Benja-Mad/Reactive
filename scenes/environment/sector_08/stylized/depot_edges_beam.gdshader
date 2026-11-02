shader_type spatial;
// The relief's dipped headlights in the night air: a soft additive cone from the lamp (local y = -0.5)
// to its far end (y = +0.5), or, with `pool` set, the elongated patch where the beam lands.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.95, 0.86, 0.62);
uniform float strength = 1.0;
uniform bool pool = false;
varying vec3 local;
void vertex() {
	local = VERTEX;
}
void fragment() {
	if (pool) {
		// Plane mesh 1 x 1: brightest a third of the way in from the near edge, fading to the rim.
		vec2 p = vec2(local.x * 2.0, (local.z + 0.18) * 2.0);
		float r = length(p * vec2(1.0, 0.8));
		ALBEDO = tint;
		ALPHA = strength * 0.22 * pow(1.0 - smoothstep(0.1, 1.0, r), 1.6);
	} else {
		float along = local.y + 0.5;
		float ends = smoothstep(0.0, 0.05, along) * (1.0 - smoothstep(0.35, 1.0, along));
		// Soft rim: bright where the cone is seen through its depth, gone at the silhouette.
		float silhouette = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.4);
		ALBEDO = tint;
		ALPHA = strength * 0.075 * ends * silhouette * (1.0 - 0.55 * along);
	}
}
