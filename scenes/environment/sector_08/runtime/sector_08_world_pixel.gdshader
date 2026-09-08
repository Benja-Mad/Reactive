shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D world_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D world_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec2 pixel_grid = vec2(1280.0,720.0);
uniform bool pixel_enabled = false;
uniform bool diorama_enabled = false;
uniform bool subtle_dither = false;
uniform bool subtle_quantization = false;
void vertex(){ POSITION=vec4(VERTEX.xy,1.0,1.0); }
void fragment(){
 vec2 uv=SCREEN_UV;
 if(pixel_enabled) uv=(floor(uv*pixel_grid)+0.5)/pixel_grid;
 vec3 color=textureLod(world_color,uv,0.0).rgb;
 if(diorama_enabled){
  float depth=textureLod(world_depth,uv,0.0).r;
  vec4 view=INV_PROJECTION_MATRIX*vec4(uv*2.0-1.0,depth,1.0);
  float distance=-view.z/view.w;
  vec3 world=(INV_VIEW_MATRIX*vec4(view.xyz/view.w,1.0)).xyz;
  // The perimeter walls are close to P30, so camera distance alone misses them.
  float architecture=smoothstep(2.8,13.0,world.y);
  float far_amount=max(smoothstep(94.0,115.0,distance),architecture*0.92);
  // The ramp used to be spent by 85 m, which put the cable tray at 74.8 m on full blur and the
  // access panel at 83.6 m on almost none: an 18x jump across 8 m, so the sign read as a razor
  // sharp object floating inside a soft foreground. Widening it makes the band continuous.
  float near_amount=1.0-smoothstep(71.0,93.0,distance);
  float blur=max(far_amount,near_amount)*3.25;
  color=textureLod(world_color,uv,blur).rgb;
  color=mix(color,vec3(0.028,0.047,0.058),far_amount*0.16);
  vec2 edge=SCREEN_UV*2.0-1.0;
  color*=1.0-0.13*smoothstep(0.55,1.4,length(edge));
 }
 if(subtle_dither){
  ivec2 p=ivec2(floor(uv*pixel_grid));
  const float b[16]=float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
  color+=(b[(p.y%4)*4+p.x%4]/16.0-0.5)/255.0;
 }
 if(subtle_quantization) color=floor(color*127.0+0.5)/127.0;
 ALBEDO=max(color,vec3(0.0)); ALPHA=1.0;
}
