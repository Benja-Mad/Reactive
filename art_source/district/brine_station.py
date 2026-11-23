"""Run inside Blender. Export the curbside modules and cabinet art beside the district models."""
from pathlib import Path
from math import sin, cos, tau, pi
import bpy
from mathutils import Vector

out = Path(__file__).resolve().parents[2] / "scenes/environment/night_district/models"
palette = {}
previous = bpy.context.window.scene
stage = bpy.data.scenes.new("Cold chain fabrication")
bpy.context.window.scene = stage

def paint(name, rgb, metal=0., glow=0., alpha=1.):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    node = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    for field, value in [('Base Color', (*rgb,1)), ('Metallic',metal), ('Roughness',.48),
                         ('Emission Color',(*rgb,1)),('Emission Strength',glow),('Alpha',alpha)]:
        node.inputs[field].default_value = value
    palette[name] = mat

paint('Basalt',(.035,.048,.065),.35)
paint('Nickel',(.31,.39,.42),.65)
paint('Enamel',(.19,.39,.39),.32)
paint('Shell',(.78,.67,.48),.24)
paint('Coral',(.76,.16,.091),.22)
paint('Violet',(.40,.10,.26),.17)
paint('Joint',(.013,.024,.029))
paint('Glass',(.12,.67,.65),.08,.20,.14)
paint('Brine',(.13,.86,.72),.1,1.8)
paint('Pilot',(.98,.47,.12),.1,1.5)

def mesh(name,vs,fs,color):
    data=bpy.data.meshes.new(name)
    data.from_pydata(vs,[],fs); data.update()
    o=bpy.data.objects.new(name,data); stage.collection.objects.link(o)
    data.materials.append(palette[color]);return o

def box(name,x,y,z,w,d,h,color):
    vs=[(x+i*w/2,y+j*d/2,z+k*h/2) for k in (-1,1) for j in (-1,1) for i in (-1,1)]
    return mesh(name,vs,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(1,3,7,5),(3,2,6,7),(2,0,4,6)],color)

def tube(name,coords,rad,color,n=8):
    pts=list(map(Vector,coords));vs=[];fs=[]
    for i,p in enumerate(pts):
        direction=(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized()
        side=direction.cross(Vector((0,0,1)))
        if side.length<.01:side=Vector((1,0,0))
        side.normalize();up=direction.cross(side).normalized()
        vs.extend([tuple(p+rad*(side*cos(tau*k/n)+up*sin(tau*k/n))) for k in range(n)])
        if i:
            fs.extend([((i-1)*n+k,(i-1)*n+(k+1)%n,i*n+(k+1)%n,i*n+k) for k in range(n)])
    fs += [tuple(reversed(range(n))),tuple((len(pts)-1)*n+k for k in range(n))]
    return mesh(name,vs,fs,color)

def drum(name,x,y,z,rx,ry,h,color,n=24):
    vs=[(x+rx*cos(tau*i/n),y+ry*sin(tau*i/n),z+k*h/2) for k in (-1,1) for i in range(n)]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]
    return mesh(name,vs,fs,color)

def label(body,x,y,z,height,material):
    font=bpy.data.curves.new(body,'FONT');font.body=body;font.size=height;font.align_x='CENTER';font.align_y='CENTER'
    o=bpy.data.objects.new(body,font);stage.collection.objects.link(o);o.location=(x,y,z);o.rotation_euler.x=pi/2
    font.materials.append(palette[material])

def finish(name,actors=()):
    groups=[([], 'Casework'),([], 'Specimen')]
    for o in list(stage.objects):
        groups[int(o in actors)][0].append(o)
    for objects,title in groups:
        if not objects:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.convert(target='MESH')
        bpy.ops.object.join()
        bpy.context.object.name=title
    bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_active_scene=True,export_animations=False)
    for o in list(stage.objects):bpy.data.objects.remove(o,do_unlink=True)

def case(x,y,z,w,h):
    box('Cast shell',x,y,z+h/2,w,.82,h,'Enamel')
    for zz in (z+.06,z+h-.06):
        box('Rubber gasket',x,y,zz,w+.06,.88,.10,'Basalt')
    for xx in (x-w*.35,x+w*.35):
        box('Tie down',xx,y,z+h+.012,.095,.86,.04,'Shell')
        box('Latch',xx,y-.43,z+h-.16,.12,.08,.26,'Nickel')
    box('Seal',x,y-.43,z+h*.50,.42,.025,.20,'Basalt')
    label('GRAFT',x,y-.45,z+h*.50,.12,'Shell')

try:
    box('Service skid',0,0,.18,4.15,1.55,.28,'Basalt')
    for x in (-1.62,1.6):
        box('Iron shoe',x,0,.09,.42,1.7,.16,'Nickel')
    # Wide oval viewing port. The rear scaffold remains visible through the brine.
    cx=-.62
    for z,rx,ry,h,c in [(.44,1.26,.74,.31,'Enamel'),(.63,1.2,.72,.13,'Shell'),(.76,1.17,.70,.08,'Brine'),
                          (1.54,1.12,.65,1.48,'Glass'),(2.31,1.18,.72,.12,'Basalt'),(2.41,1.24,.73,.13,'Enamel'),(2.49,1.08,.62,.08,'Nickel')]:
        drum('Pressure vessel',cx,0,z,rx,ry,h,c)
    drum('Inset bed',cx,0,.811,1.12,.66,.04,'Enamel')
    for x in (cx-.97,cx+.97):
        tube('Hoop upright',[(x,.17,.66),(x,.26,2.34)],.076,'Nickel')
    box('Dark inspection wall',cx,.52,1.55,1.85,.08,1.53,'Basalt')
    for z in (.95,1.23,1.51,1.79,2.07):
        box('Depth gauge',cx-.73,.45,z,.22,.03,.019,'Brine')
    box('Pressure box',1.23,0,.94,1.17,1.18,1.4,'Shell')
    box('Service fascia',1.23,-.61,1.04,1.02,.05,1.02,'Basalt')
    box('Vacuum scope',1.21,-.65,1.31,.78,.04,.34,'Enamel')
    label('-18 C',1.21,-.679,1.31,.225,'Brine')
    for k in range(5):box('Cooling louvre',1.25,-.66,.81-k*.075,.68,.04,.031,'Nickel')
    for i in range(2):
        x=.94+i*.49
        drum('Filter',x,.05,1.9,.16,.16,.53,'Coral')
        for z in (1.73,2.07):drum('Band',x,.05,z,.174,.174,.08,'Basalt')
    tube('Transfer pipe',[(.18,.12,2.45),(.18,.12,2.7),(.43,.12,2.84),(.98,.12,2.84),(1.18,.12,2.62),(1.18,.12,2.15)],.10,'Nickel')
    for j in range(3):drum('Hose ferrule',1.18,.12,2.21+.1*j,.122,.122,.035,'Joint')
    label('BRINE  /  04',cx,-.735,.45,.18,'Shell')
    for i in range(4):box('Serial bars',-1.54+i*.085,-.66,.48,.037,.022,.17,'Pilot')
    # A ray cultured around a copper spinal bus. Keep it as a separate mesh for buoyancy.
    earlier=set(stage.objects)
    vs=[(-1.44,-.04,1.51),(-.99,-.22,1.72),(-.68,-.30,1.57),(-.32,-.19,1.70),(.22,-.02,1.84),(-.23,.15,1.47),(-.64,.24,1.41),(-1.04,.1,1.43)]
    keel=len(vs);vs.append((-.66,-.19,1.37))
    fan=[(0,1,2),(0,2,7),(1,3,2),(2,3,4),(2,4,5),(2,5,6),(2,6,7)]
    mesh('Wing membrane',vs,fan+[(0,keel,2),(2,keel,4),(4,keel,5),(7,keel,0)],'Coral')
    drum('Ray body',-.66,-.23,1.53,.18,.27,.17,'Violet')
    for x in (-.78,-.56):drum('Optic',x,-.38,1.60,.040,.043,.034,'Pilot')
    tube('Mechanical spine',[(-.68,-.33,1.56),(-.65,-.1,1.58),(-.64,.15,1.50),(-.55,.17,1.34),(-.29,.15,1.24),(-.08,.11,1.27)],.053,'Shell')
    for j in range(3):
        x=-.74-.20*j
        tube('Fin rib',[(x,-.2+j*.04,1.59+j*.035),(x-.27,.05,1.48+j*.02)],.016,'Pilot')
    drum('Lens',-.69,-.32,1.60,.07,.05,.08,'Brine')
    finish('brine_station',set(stage.objects)-earlier)
    box('Cargo pallet',0,0,.085,2.65,1.62,.17,'Basalt')
    case(-.60,-.26,.18,1.16,.64);case(.66,-.18,.18,1.13,.69);case(.61,-.13,.88,1.0,.49)
    for i in range(3):
        x=-.90+i*.49
        drum('Spent canister',x,.46,.67,.21,.21,.93,'Coral')
        for z in (.33,.92):drum('Canister collar',x,.46,z,.23,.23,.09,'Shell')
        drum('Valve',x,.46,1.18,.11,.11,.12,'Nickel')
    finish('graft_freight')
    # Walkable cable trench. Its ribs leave pockets of light between the loading tracks.
    box('Recess',0,0,.026,5.9,1.02,.05,'Joint')
    for y in (-.51,.51):
        box('Outer lip',0,y,.062,5.98,.065,.075,'Nickel')
    for x in (-2.97,2.97):box('End sill',x,0,.06,.065,1.06,.07,'Basalt')
    for y,c in [(-.28,'Violet'),(0,'Enamel'),(.25,'Nickel')]:
        tube('Wrapped return', [(-2.91,y,.052),(-1.63,y,.052),(-1.4,y+.08,.052),(1.08,y+.08,.052),(1.28,y,.052),(2.9,y,.052)],.056,c)
    for i in range(27):
        x=-2.82+i*.216
        box('Grate blade',x,0,.137,.085,1.0,.055,'Basalt')
        box('Wear edge',x-.027,0,.166,.016,.97,.006,'Nickel')
    for x in (-2.52,-.76,.78,2.48):
        box('Keeper',x,-.42,.19,.21,.2,.035,'Shell')
        for y in (-.32,.31):box('Inspection tube',x+.18,y,.105,.27,.038,.03,'Brine')
    box('Service lid',.02,-.02,.167,1.0,.95,.042,'Enamel')
    for x in (-.37,.37):
        for y in (-.37,.33):drum('Quarter turn lock',x,y,.20,.037,.037,.012,'Nickel')
    for x in (-.21,-.07,.07,.21):box('Recessed pull',x,.0,.194,.063,.45,.011,'Joint')
    finish('tidal_conduit')
    # Baked cabinet illustrations sit on the front of the original WAVE furniture.
    picture=bpy.data.images.load(str(Path(__file__).with_name('ghost_wave.png')))
    paint('Screen art',(1,1,1))
    m=palette['Screen art'];node=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=picture;tex.interpolation='Closest'
    m.node_tree.links.new(tex.outputs['Color'],node.inputs['Base Color'])
    m.node_tree.links.new(tex.outputs['Color'],node.inputs['Emission Color'])
    node.inputs['Emission Strength'].default_value=.67
    def print_panel(x,y,z,w,h,crop):
        o=mesh('Screen',[(x-w/2,y,z-h/2),(x+w/2,y,z-h/2),(x+w/2,y,z+h/2),(x-w/2,y,z+h/2)],[(0,1,2,3)],'Screen art')
        a,b,c,d=crop
        uv=o.data.uv_layers.new()
        for i,(u,v) in enumerate([(a,d),(c,d),(c,b),(a,b)]):
            uv.data[i].uv=(u/384,1-v/192)
    print_panel(0,-3.08,3.68,7.52,1.06,(0,0,384,70))
    for i,x in enumerate((-.85,.7,2.25)):
        print_panel(x,-3.385,1.51,.87,.68,(128*i,73,128*i+127,149))
        print_panel(x,-3.39,.62,.82,.65,(128*i,149,128*i+127,191))
    finish('ghost_wave')

finally:
    bpy.context.window.scene=previous
    bpy.data.scenes.remove(stage)
