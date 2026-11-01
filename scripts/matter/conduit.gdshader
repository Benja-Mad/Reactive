// A conduit between two constructs: a brass filament with packets drifting toward the
// receiver, so the direction of the program is legible at rest. A pulse is one bright bead.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.66, 0.3, 1.0);
uniform float grow : hint_range(0.0, 1.0) = 1.0;
uniform float pulse_at = -1.0;
uniform float armed_end = 0.0;
uniform float length = 6.0;

void fragment() {
	float along = UV.x;
	if (along > grow) discard;
	// Across the ribbon: bright core, soft shoulders.
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float core = pow(across, 3.0);
	float glow = pow(across, 1.2) * 0.3;
	// Idle packets every ~0.7 m, moving toward the receiver.
	float packets = smoothstep(0.7, 1.0, fract(along * length / 0.7 - TIME * 0.9));
	float idle = 0.35 + packets * 0.45;
	// The receiving end burns brighter when it holds a reaction waiting for this pulse.
	idle += smoothstep(0.75, 1.0, along) * armed_end * 0.6;
	float bead = 0.0;
	if (pulse_at >= 0.0) {
		float d = (along - pulse_at) * length;
		bead = exp(-d * d * 6.0) * 4.0 + exp(-max(-d, 0.0) * 1.4) * step(d, 0.0) * 0.6;
	}
	float tip = smoothstep(grow - 0.02, grow, along) * step(grow, 0.999) * 3.0;
	vec3 tint = mix(color.rgb, vec3(1.0, 0.95, 0.85), clamp(bead * 0.25, 0.0, 1.0));
	ALBEDO = tint * (core + glow) * (idle + bead + tip);
}
