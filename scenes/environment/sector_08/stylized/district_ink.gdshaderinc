// Shared graphic lighting vocabulary: coloured shadow floor, broad face values,
// geometric cast shadows and no specular sparkle. Dynamic lights still describe form.
vec3 district_shadow(vec3 pigment, vec3 normal_world, float pavement, float depth_tier) {
	float upward = max(normal_world.y,0.0);
	vec3 ink = mix(vec3(0.48,0.46,0.65),vec3(0.46,0.57,0.72),upward);
	float fill = mix(0.13,0.075,pavement);
	return mix(pigment*ink*fill,vec3(0.034,0.058,0.063),depth_tier*0.7);
}
float district_face(float facing) {
	float band = facing < 0.2 ? 0.025 : (facing < 0.65 ? 0.28 : 1.15);
	return mix(facing,band,0.85);
}

// Preserve broad face values without threshold contours on a single flat wall.
float district_local_face(float facing) {
	float band = 0.025 + 0.255*smoothstep(0.10,0.30,facing)
		+ 0.87*smoothstep(0.48,0.82,facing);
	return mix(facing,band,0.85);
}

// Deliberate ordered light texture. Keep actual shadow-map coordinates intact:
// the pattern changes luminosity inside a surface, never the silhouette.
float district_print_light(float value, vec3 world_point, vec3 world_normal) {
	if (value <= 0.00001) { return value; }
	vec3 n = abs(world_normal);
	vec2 plane = n.y >= max(n.x,n.z) ? world_point.xz : (n.x > n.z ? world_point.zy : world_point.xy);
	ivec2 cell = ivec2(mod(floor(plane*8.0),4.0));
	mat4 ordered = mat4(vec4(0.0,8.0,2.0,10.0),vec4(12.0,4.0,14.0,6.0),vec4(3.0,11.0,1.0,9.0),vec4(15.0,7.0,13.0,5.0));
	float threshold = (ordered[cell.x][cell.y]+0.5)/16.0;
	// Relative quantization limits contrast even under powerful distant lamps.
	float printed = exp2(floor(log2(value)*3.0+threshold)/3.0);
	return mix(value,printed,0.9);
}
