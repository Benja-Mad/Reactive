shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform vec4 shaft_color : source_color = vec4(0.45,0.7,1.0,1.0);
uniform float strength = 0.10;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
void fragment(){
 float scene_z=textureLod(scene_depth,SCREEN_UV,0.0).r;
 vec4 scene_view=INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.0-1.0,scene_z,1.0);
 float separation=-scene_view.z/scene_view.w+VERTEX.z;
 float soft_contact=smoothstep(0.0,0.8,separation);
 float longitudinal=smoothstep(0.0,0.08,UV.y)*(1.0-smoothstep(0.65,1.0,UV.y));
 // A static fan of light through an aperture. No TIME, moving noise or temporal history.
 float x=(UV.x-0.5)/mix(0.035,1.0,UV.y)+0.5;
 float rays=0.0;
 rays+=exp(-pow((x-0.22)/0.065,2.0))*0.75;
 rays+=exp(-pow((x-0.47)/0.085,2.0));
 rays+=exp(-pow((x-0.76)/0.06,2.0))*0.65;
 ALBEDO=shaft_color.rgb;
 ALPHA=clamp(rays*longitudinal*soft_contact*strength,0.0,0.25);
}
