shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float opacity = 0.52;
uniform float softness = 0.0;
uniform float fixture_power = 1.0;
uniform vec3 amber_anchor = vec3(4.0,6.0,-16.0);
uniform vec3 cyan_anchor = vec3(-18.0,4.0,-15.0);
varying vec3 world;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	// A slight slant reads as wind even when each particle uses a fixed quad.
	float edge = 1.0-smoothstep(mix(0.08,0.0,softness),0.5,abs(UV.x-0.5+(UV.y-0.5)*0.32));
	edge = pow(edge, 1.0 + softness*1.5);
	float taper = smoothstep(0.0,0.18,UV.y)*(1.0-smoothstep(0.6,1.0,UV.y));
	float ground_fade = smoothstep(0.03,0.7,world.y);
	float warm = exp(-dot(world.xz-amber_anchor.xz,world.xz-amber_anchor.xz)/32.0)*fixture_power;
	float cool = exp(-dot(world.xz-cyan_anchor.xz,world.xz-cyan_anchor.xz)/48.0)*fixture_power;
	ALBEDO = mix(vec3(0.26,0.35,0.46),vec3(0.85,0.56,0.27),warm*0.85);
	EMISSION = vec3(0.025,0.04,0.06)+vec3(0.025,0.16,0.24)*cool+vec3(0.26,0.12,0.025)*warm;
	ALPHA = edge*taper*ground_fade*opacity*(0.68+0.32*max(warm,cool));
}
