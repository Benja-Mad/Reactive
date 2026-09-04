shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D ground_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ground_normal_roughness : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float tile_scale = 5.2;
uniform vec3 moss_tint : source_color = vec3(0.54, 0.7, 0.5);
uniform vec3 earth_tint : source_color = vec3(0.42, 0.29, 0.17);

void fragment() {
	vec2 moss_uv = UV * tile_scale;
	vec2 earth_uv = UV * (tile_scale * 1.35) + vec2(0.23, 0.41);
	vec4 moss_sample = texture(ground_albedo, moss_uv);
	vec4 earth_sample = texture(ground_albedo, earth_uv);
	float broad_pattern = 0.5 + sin(UV.x * 13.0 + sin(UV.y * 7.0)) * 0.24 + sin(UV.y * 9.0) * 0.18;
	float earth_mask = smoothstep(0.64, 0.82, broad_pattern) * 0.58;
	ALBEDO = mix(moss_sample.rgb * moss_tint, earth_sample.rgb * earth_tint, earth_mask);
	vec4 normal_roughness = texture(ground_normal_roughness, moss_uv);
	NORMAL_MAP = normal_roughness.rgb;
	NORMAL_MAP_DEPTH = 0.62;
	ROUGHNESS = mix(0.78, 0.94, normal_roughness.a);
	SPECULAR = 0.18;
}
