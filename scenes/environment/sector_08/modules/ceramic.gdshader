shader_type spatial;
uniform vec4 tint : source_color = vec4(0.5,0.47,0.36,1.0);
varying vec3 world;
void vertex() { world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 float grain = fract(sin(dot(floor(world*31.0),vec3(127.1,311.7,74.7)))*43758.5453);
 float streak = sin(world.x*19.0+sin(world.z*13.0))*0.5+0.5;
 float foot = 1.0-smoothstep(0.15,0.9,world.y);
 ALBEDO = tint.rgb*(0.88+grain*0.12);
 ALBEDO = mix(ALBEDO,vec3(0.12,0.105,0.07),foot*(0.22+streak*0.18));
 ROUGHNESS = 0.9;
}
