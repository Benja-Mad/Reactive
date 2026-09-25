shader_type spatial;
render_mode cull_disabled;
uniform vec4 matter_color : source_color = vec4(0.15,0.23,0.26,1.0);
uniform bool frozen = false;
uniform bool coated = false;
uniform bool armed = false;
uniform bool wall = false;
uniform float damage = 0.0;
uniform vec3 extent = vec3(4.0,1.8,0.2);
varying vec3 local_point;
void vertex() {
 // Scalloped pressure ribs: the same silhouette survives the change of phase.
 if(wall) {
  float rib = sin(VERTEX.x*8.8 + sin(VERTEX.x*2.1)*0.7);
  VERTEX.z += sign(VERTEX.z)*rib*0.045;
  VERTEX.y *= 0.94 + 0.06*sin(VERTEX.x*5.3+0.7);
 } else {
  VERTEX.x *= 0.94 + 0.06*sin(VERTEX.z*6.1+0.5);
  VERTEX.z *= 0.94 + 0.06*sin(VERTEX.x*5.4);
 }
 local_point = VERTEX;
}
void fragment() {
 vec3 p = local_point;
 float ripple = sin(p.x*11.0 + TIME*1.8)*sin(p.z*13.0 - TIME*1.1);
 float veins = abs(sin(p.x*8.8 + p.y*0.7 + sin(p.y*4.0)*0.3));
 float fracture = pow(abs(sin(p.x*4.1+p.y*5.7+sin(p.x*9.0))),34.0);
 ALBEDO = matter_color.rgb * (frozen ? mix(0.6,1.05,veins) : 0.92 + ripple*0.08);
 ALBEDO = mix(ALBEDO,vec3(0.12,0.18,0.17),fracture*(0.15+damage*0.7));
 ROUGHNESS = frozen ? 0.48 : 0.23;
 METALLIC = 0.05;
 ALPHA = frozen ? 1.0 : 0.70;
 if (coated) {
  float trace = 1.0-smoothstep(0.07,0.18,veins);
  float bands = 1.0-smoothstep(0.04,0.11,abs(abs(p.y)-extent.y*0.28));
  float coverage = max(trace*0.65,bands);
  ALBEDO = mix(ALBEDO,vec3(0.29,0.22,0.12),coverage);
  METALLIC = mix(METALLIC,0.65,coverage);
  EMISSION = vec3(0.5,0.32,0.12)*trace*pow(max(0.0,sin(p.y*5.0-TIME*2.0)),12.0)*0.25;
 }
 if(armed) {
  float seam = 1.0-smoothstep(0.008,0.035,abs(p.y+extent.y*0.36));
  EMISSION += vec3(0.65,0.45,0.18)*seam*0.5;
 }
}
