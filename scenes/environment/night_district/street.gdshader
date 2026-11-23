shader_type spatial;
varying vec3 world_pos;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){
 vec2 i=floor(p),f=fract(p); f=f*f*(3.-2.*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);
}
// A tar seam follows a jogged joint where the dock apron was cut open and relaid.
float line_segment(vec2 p, vec2 a, vec2 b) {
 vec2 ab=b-a;
 return length(p-a-ab*clamp(dot(p-a,ab)/dot(ab,ab),0.,1.));
}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=floor(world_pos.xz*42.)/42.;
 float grit=hash(floor(p*35.)), patch=noise2(p*vec2(.53,1.25));
 vec3 road=mix(vec3(.044,.054,.064),vec3(.095,.105,.112),noise2(p*.22))+(grit-.5)*.009;
 vec2 slab=vec2(p.x/1.8+mod(floor(p.y),2.)*.5,p.y); vec2 edge=min(fract(slab),1.-fract(slab));
 vec3 quay=vec3(.17,.20,.21)*(.83+.25*hash(floor(slab)))*mix(.59,1.,step(.016,min(edge.x,edge.y)));
 float walk=step(9.5,abs(p.y)); vec3 c=mix(road,quay,walk);
 // The old narrow-gauge freight tracks curve towards the western loading bay.
 // Asphalt resurfaced over the old weighbridge, with an offset strip of exposed aggregate.
 vec2 repair=p-vec2(10.5,-4.3);
 repair.x+=.19*repair.y;
 vec2 cut=abs(repair)-vec2(5.7,1.58);
 float lip=max(cut.x,cut.y)+.055*noise2(p*7.);
 c=mix(c,c*vec3(.67,.76,.83),1.-step(0.,lip));
 c=mix(c,vec3(.092,.103,.096),1.-step(.045,abs(lip)));
 float seam=min(line_segment(p,vec2(-22.,-7.1),vec2(-14.5,-6.5)),
                min(line_segment(p,vec2(-14.5,-6.5),vec2(-13.7,-5.75)),
                    line_segment(p,vec2(-13.7,-5.75),vec2(-4.8,-5.84))));
 c=mix(c,vec3(.029,.034,.036),1.-step(.055,seam+.043*noise2(p*6.)));
 float track=abs(abs(p.y-2.5+1.8*sin(p.x*.067))-.62);
 c=mix(c,vec3(.027,.034,.038),1.-step(.088,track));
 c=mix(c,vec3(.27,.29,.27),1.-step(.037,track));
 float bay=step(abs(mod(p.x+4.,8.)-4.),.065)*step(abs(p.y+6.5),1.8);
 float paint=max(bay,step(abs(p.y+8.24),.071)*step(.16,fract(p.x*.2)));
 float crossing=step(abs(p.x+10.),1.15)*step(abs(p.y+.7),6.)*step(.6,fract(p.y));
 float wear=smoothstep(.16,.54,noise2(p*5.)+.15*grit);
 c=mix(c,vec3(.53,.35,.15),paint*wear*.85); c=mix(c,vec3(.47,.48,.40),crossing*wear*.67);
 // Worn diagonal strokes bound the eastern loading ramp. The crossing remains the west landmark.
 vec2 ramp=p-vec2(21.7,5.35);
 float ramp_edge=step(abs(ramp.x),3.4)*step(abs(ramp.y),1.45);
 float hatch=(1.-step(.14,fract((ramp.x+ramp.y*.8)*.95))) * ramp_edge;
 c=mix(c,vec3(.39,.32,.17),hatch*wear*.68);
 float wet=smoothstep(.55,.68,patch+.20*noise2(p*vec2(1.4,5.))-.08*grit);
 float smear=.26+.74*noise2(vec2(p.x*2.,p.y*20.+TIME*.35));
 vec3 reflected=vec3(0.);
 for(int i=0;i<4;i++){
  float dx=p.x-(-6.6+float(i)*2.68);
  reflected+=vec3(.33,.115,.032)*exp(-dx*dx*.65-abs(p.y+10.5)*.22);
 }
 reflected+=vec3(.06,.17,.16)*exp(-pow(abs(p.x-10.),2.)*.27-abs(p.y+10.)*.23);
 // Broken CRT colours reflected below the two ends of the market sign.
 reflected+=vec3(.035,.28,.25)*exp(-pow(abs(p.x+4.8),2.)*.32-abs(p.y+9.)*.24);
 reflected+=vec3(.20,.135,.050)*exp(-pow(abs(p.x-2.6),2.)*.55-abs(p.y+9.)*.24);
 reflected+=vec3(.025,.31,.26)*exp(-pow(abs(p.x-5.2),2.)*.9-abs(p.y+8.2)*.52);
 ALBEDO=c*(1.-wet*.22); EMISSION=reflected*smear*wet*(.62+.38*exp(-abs(p.y+9.)*.55));
 // Beyond the low seawall the quay gives way to the tidal basin.
 if (p.y > 18.5) {
  float tide=p.y-18.5;
  float ripple=noise2(vec2(p.x*1.3+TIME*.28,p.y*8.-TIME*.7));
  float crest=smoothstep(.66,.8,ripple);
  float shelf=noise2(p*vec2(.39,.82));
  float shallows=(1.-smoothstep(.15,2.2,tide+.65*shelf));
  vec3 basin=mix(vec3(.027,.079,.094),vec3(.039,.113,.125),step(.57,shelf));
  ALBEDO=mix(basin,vec3(.065,.131,.11),shallows*(.4+.55*shelf));
  float quay_glint=exp(-abs(p.x+4.72)*1.5)*exp(-abs(tide-4.4)*.44);
  EMISSION=crest*(vec3(.018,.043,.046)+vec3(.29,.14,.054)*quay_glint);
  wet=1.;
 }
 ROUGHNESS=mix(.94,.35,wet);SPECULAR=.19;
}
