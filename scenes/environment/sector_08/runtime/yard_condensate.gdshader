shader_type fog;

uniform float density = 0.025;

void fog() {
	// Ellipsoid bounds dissolve before the edge. Slow folds describe condensate
	// advection without adding a texture asset or a glowing transparent card.
	vec3 p = UVW * 2.0 - 1.0;
	float envelope = pow(max(0.0, 1.0 - dot(p, p)), 2.0);
	float fold = 0.72 + 0.18 * sin(WORLD_POSITION.x * 0.8 + WORLD_POSITION.z * 1.1 - TIME * 0.24)
		+ 0.10 * sin(WORLD_POSITION.y * 2.1 + WORLD_POSITION.z * 0.7 + TIME * 0.17);
	DENSITY = density * envelope * fold;
	ALBEDO = vec3(0.48, 0.57, 0.62);
}
