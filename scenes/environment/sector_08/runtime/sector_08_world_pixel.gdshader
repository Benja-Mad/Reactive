shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D world_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D world_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec2 pixel_grid = vec2(1280.0,720.0);
uniform bool pixel_enabled = false;
uniform bool diorama_enabled = false;
// Distance the framing is composed from. The blur band is expressed as multiples of it rather
// than in metres, because it used to be hardcoded around 85.8 m: dolly the camera to 60 m and
// the whole yard fell inside the *near* ramp, so the gameplay plane went soft and the level
// looked like it had lost its depth when in fact only the focus had been left behind.
uniform float focus_distance = 85.8;
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
  // Height gated by distance: height alone also caught operatives and cover standing in the
  // yard, which is a real defect worth keeping fixed. The bands themselves are back to the
  // approved ramp -- widened to 0.62..1.30 of focus and blended in at a fraction of the mip, it
  // stopped separating anything: measured, the far architecture lost a quarter of its detail and
  // the play plane a tenth, which is not a depth of field, it is a haze.
  float architecture=smoothstep(2.8,13.0,world.y)
      *smoothstep(1.02*focus_distance,1.20*focus_distance,distance);
  float far_amount=max(smoothstep(1.096*focus_distance,1.340*focus_distance,distance),architecture*0.92);
  // The ramp used to be spent by 85 m, which put the cable tray at 74.8 m on full blur and the
  // access panel at 83.6 m on almost none: an 18x jump across 8 m, so the sign read as a razor
  // sharp object floating inside a soft foreground. Widening it makes the band continuous.
  float near_amount=1.0-smoothstep(0.828*focus_distance,1.084*focus_distance,distance);
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
