// Ground marks drawn on a flat quad: corner brackets around a selected construct, or chevrons
// running along the vector a routine will push along.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform bool chevrons = false;
uniform vec2 extent = vec2(4.0, 3.0);
uniform float strength = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * extent;
	float shade = 0.0;
	if (chevrons) {
		// Arrow along +x: chevrons that travel, then a head at the far end.
		float along = UV.x;
		float across = abs(UV.y - 0.5) * 2.0;
		float v = fract(along * 5.0 + across * 0.9 - TIME * 1.4);
		float chevron = smoothstep(0.0, 0.08, v) * (1.0 - smoothstep(0.18, 0.3, v));
		shade = chevron * (1.0 - smoothstep(0.75, 1.0, across)) * smoothstep(0.0, 0.25, along) * (1.0 - smoothstep(0.85, 1.0, along));
	} else {
		vec2 half_size = extent * 0.5;
		vec2 q = abs(p);
		float pulse = 0.85 + 0.15 * sin(TIME * 4.0);
		float line = 0.09;
		float arm = min(0.7, min(half_size.x, half_size.y) * 0.9);
		float near_x = 1.0 - smoothstep(line * 0.5, line, abs(q.x - (half_size.x - line)));
		float near_y = 1.0 - smoothstep(line * 0.5, line, abs(q.y - (half_size.y - line)));
		float in_arm_y = step(half_size.y - arm, q.y);
		float in_arm_x = step(half_size.x - arm, q.x);
		float brackets = max(near_x * in_arm_y, near_y * in_arm_x);
		float fill = 0.05 * (1.0 - smoothstep(0.0, 0.4, max(q.x - half_size.x + 0.4, q.y - half_size.y + 0.4)));
		shade = (brackets + fill) * pulse;
	}
	ALBEDO = color.rgb * shade * strength;
}
