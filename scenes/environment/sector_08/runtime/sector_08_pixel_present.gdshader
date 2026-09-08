shader_type canvas_item;
render_mode unshaded;
uniform bool subtle_dither = false;
uniform bool subtle_quantization = false;

float ordered_threshold(ivec2 pixel) {
 const float bayer[16] = float[16](0.0,8.0,2.0,10.0,12.0,4.0,14.0,6.0,3.0,11.0,1.0,9.0,15.0,7.0,13.0,5.0);
 return (bayer[(pixel.y % 4) * 4 + pixel.x % 4] + 0.5) / 16.0 - 0.5;
}
void fragment() {
 vec4 color = texture(TEXTURE, UV);
 // Fixed internal-pixel lattice; no frame/time noise. Operates after PBR, fog and glow.
 float steps = 127.0;
 if (subtle_dither) {
  float amplitude = subtle_quantization ? 0.7 / steps : 1.0 / 255.0;
  color.rgb += vec3(ordered_threshold(ivec2(floor(UV * vec2(textureSize(TEXTURE, 0))))) * amplitude);
 }
 if (subtle_quantization) {
  color.rgb = floor(clamp(color.rgb, 0.0, 1.0) * steps + 0.5) / steps;
 }
 COLOR = vec4(clamp(color.rgb, 0.0, 1.0), color.a);
}
