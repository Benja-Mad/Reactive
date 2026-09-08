// Airborne dust that is only visible where light finds it.
//
// The previous material was a StandardMaterial3D with alpha blending and a fixed 0.55 alpha. That
// makes a mote a constant grey wash: over a dark wall it *adds* brightness, and inside a bright
// beam it is darker than what it covers, so it *subtracts*. Measured, the old motes contributed
// ten times more in shadow than in the sodium beam -- the exact inverse of real dust.
//
// Two changes fix that. Additive blending means an unlit mote adds nothing and is invisible,
// while a lit one glows. And scattering is computed with a phase function rather than a diffuse
// N.L term: a camera-facing billboard has its normal pointing at the lens, so N.L barely changes
// as the mote crosses a beam, which is why the old one never flared.
//
// Dust does scatter forward, but that is a refinement here, not the main effect. This camera
// looks down at 30 degrees at lamps that also point down, so the geometry is mostly *back*
// scattering: a strong forward lobe made the motes darkest exactly where they should be
// brightest. The dominant cue is simply being inside a cone at all, which is ATTENUATION. So the
// asymmetry stays mild and the isotropic term carries most of the response.
shader_type spatial;
// Shadow reception left ON: ATTENUATION then carries the shadow map, so a mote drifting behind
// the fence goes dark inside the cone instead of glowing through it.
render_mode blend_add, depth_draw_never, cull_disabled, specular_disabled, ambient_light_disabled;

uniform vec3 tint : source_color = vec3(0.86, 0.90, 0.96);
uniform float opacity : hint_range(0.0, 1.0) = 0.9;
uniform float gain : hint_range(0.0, 40.0) = 2.6;
/// Henyey-Greenstein asymmetry. 0 is isotropic, higher throws the scattering forward.
uniform float anisotropy : hint_range(0.0, 0.9) = 0.22;
/// Sun and moon should barely register: what makes dust appear is a lamp, not the sky.
uniform float ambient_response : hint_range(0.0, 1.0) = 0.028;
/// Floor so motes do not vanish completely outside every cone.
uniform float floor_visibility : hint_range(0.0, 0.5) = 0.012;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	// Soft round grain, faded well inside the quad so nothing can be cut off square.
	float shape = exp(-r * r * 6.5) * (1.0 - smoothstep(0.72, 1.0, r));
	ALBEDO = tint * COLOR.rgb;
	ALPHA = shape * COLOR.a * opacity;
	// A hint of self-shadowing across the grain, so a mote is not a flat disc of light.
	NORMAL = normalize(vec3(p * 0.35, 1.0));
}

void light() {
	// Forward scattering: brightest when the light is travelling towards the camera through the
	// mote. VIEW points at the camera, LIGHT points at the source, so they oppose in that case.
	float cos_theta = dot(-VIEW, LIGHT);
	float g = anisotropy;
	float denom = 1.0 + g * g - 2.0 * g * cos_theta;
	float phase = (1.0 - g * g) / (4.0 * PI * max(pow(denom, 1.5), 0.0001));

	float response = LIGHT_IS_DIRECTIONAL ? ambient_response : 1.0;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (phase + floor_visibility) * gain * response * ALBEDO;
}
