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
  // Height alone is not a background layer: it also catches operatives, cover,
  // and the reactor silhouette. Require distance before softening architecture.
  float architecture=smoothstep(7.0,18.0,world.y)
      *smoothstep(1.04*focus_distance,1.28*focus_distance,distance);
  float far_amount=max(smoothstep(1.30*focus_distance,1.65*focus_distance,distance),architecture*0.48);
  // Reserve near softness for the framing rail and foliage. The broad interval
  // between 0.82 and 1.30 stays at native resolution throughout the play plane.
  float near_amount=1.0-smoothstep(0.62*focus_distance,0.82*focus_distance,distance);
  float blur=max(far_amount*2.6,near_amount*3.1);
  // Blend the transition instead of sampling a softened mip across the whole yard.
  vec3 layered_color=textureLod(world_color,uv,blur).rgb;
  color=mix(color,layered_color,smoothstep(0.04,0.55,max(far_amount,near_amount)));
  color=mix(color,vec3(0.055,0.090,0.12),far_amount*0.10);
  vec2 edge=SCREEN_UV*2.0-1.0;
  color*=1.0-0.08*smoothstep(0.65,1.4,length(edge));
 }
 if(subtle_dither){
  ivec2 p=ivec2(floor(uv*pixel_grid));
  const float b[16]=float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
  color+=(b[(p.y%4)*4+p.x%4]/16.0-0.5)/255.0;
 }
 if(subtle_quantization) color=floor(color*127.0+0.5)/127.0;
 ALBEDO=max(color,vec3(0.0)); ALPHA=1.0;
}
