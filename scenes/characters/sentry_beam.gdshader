// Targeting beam: a soft-edged additive filament. While hunting it is broken into charge
// packets running toward the target; once committed it is one continuous line.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.07, 0.16, 1.0);
uniform float intensity = 1.0;
uniform float dash : hint_range(0.0, 1.0) = 1.0;
uniform float length = 10.0;

void fragment() {
	// Bright core, soft falloff to the silhouette.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float core = pow(facing, 2.2);
	// Packets travel muzzle -> target (UV.y runs along the tube).
	float along = (1.0 - UV.y) * length;
	float packet = smoothstep(0.15, 0.55, fract(along * 1.6 - TIME * 7.0));
	float body = mix(1.0, 0.25 + 0.75 * packet, dash);
	// A faint heat shimmer keeps a frozen line from reading as a static prop.
	float shimmer = 0.9 + 0.1 * sin(along * 23.0 - TIME * 31.0);
	float strength = intensity * core * body * shimmer;
	ALBEDO = mix(color.rgb, vec3(1.0, 0.85, 0.8), core * core * 0.35) * strength;
}
