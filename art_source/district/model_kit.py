# Authored through MCP for Blender. X horizontal, -Y street-facing, Z up; metres.
import bpy, math
from mathutils import Vector
OUT = '/Users/semati/Documents/Reactive/scenes/environment/night_district/models'
SOURCE = '/Users/semati/Documents/Reactive/art_source/district/district.blend'
SCENE_NAME = 'Reactive - Distrito 08'
ROOT = None
M = {}

def mat(name, rgb, rough=.75, metal=0, emission=0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes=True
    n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    n.inputs['Base Color'].default_value=(*rgb,1)
    n.inputs['Roughness'].default_value=rough
    n.inputs['Metallic'].default_value=metal
    n.inputs['Emission Color'].default_value=(*rgb,1)
    n.inputs['Emission Strength'].default_value=emission
    m.diffuse_color=(*rgb,1)
    M[name]=m
    return m

def palette():
    for n,c,r,met,e in [
      ('Ink',(.027,.043,.059),.8,0,0),('Steel',(.10,.16,.18),.6,.35,0),
      ('Edge',(.27,.35,.35),.6,.4,0),('Blue',(.12,.21,.25),.85,0,0),
      ('Plaster',(.31,.37,.35),.9,0,0),('Rust',(.32,.19,.13),.8,.1,0),
      ('Brick',(.18,.20,.22),.9,0,0),('Glass',(.025,.10,.13),.22,.3,0),
      ('Wood',(.28,.17,.10),.85,0,0),('Cream',(.68,.64,.47),.8,0,0),
      ('Red',(.36,.09,.08),.8,0,0),('Leaf',(.10,.24,.16),.9,0,0),
      ('LeafLight',(.21,.35,.19),.85,0,0),('Rubber',(.018,.025,.03),.9,0,0),
      ('Amber',(1.0,.45,.12),.45,0,2.5),('Cyan',(.12,.77,.72),.4,0,2.2),
      ('Rose',(.67,.19,.32),.5,0,1.6),('WindowWarm',(.43,.33,.16),.6,0,.35),
      ('WindowCool',(.12,.28,.29),.45,0,.3)]: mat(n,c,r,met,e)

def root(name):
    global ROOT
    ROOT=bpy.data.objects.new(name,None);bpy.context.scene.collection.objects.link(ROOT)
    return ROOT

def obj(name,mesh,material):
    o=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(o)
    o.parent=ROOT
    if material: o.data.materials.append(M[material])
    return o

def box(name,p,s,material='Steel',bevel=.025):
    x,y,z=[v/2 for v in s]
    vs=[(-x,-y,-z),(-x,-y,z),(-x,y,-z),(-x,y,z),(x,-y,-z),(x,-y,z),(x,y,-z),(x,y,z)]
    fs=[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
    o=obj(name,me,material);o.location=p
    if bevel:
        b=o.modifiers.new('Edge chamfer','BEVEL');b.width=min(bevel,min(s)*.2);b.segments=2
        b=o.modifiers.new('Corner normals','WEIGHTED_NORMAL')
    return o

def cylinder(name,p,r,depth,material='Steel',vertices=16,rotation=None):
    vs=[]
    for z in [-depth/2,depth/2]:
        vs += [(r*math.cos(i*math.tau/vertices),r*math.sin(i*math.tau/vertices),z) for i in range(vertices)]
    fs=[tuple(reversed(range(vertices))),tuple(range(vertices,vertices*2))]
    fs += [(i,(i+1)%vertices,(i+1)%vertices+vertices,i+vertices) for i in range(vertices)]
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
    o=obj(name,me,material);o.location=p
    if rotation:o.rotation_euler=rotation
    b=o.modifiers.new('Rim chamfer','BEVEL');b.width=.012;b.segments=2
    o.modifiers.new('Corner normals','WEIGHTED_NORMAL')
    return o

def tube(name,points,r,material='Edge'):
    c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=1
    c.bevel_depth=r;c.bevel_resolution=1
    sp=c.splines.new('POLY');sp.points.add(len(points)-1)
    for q,p in zip(sp.points,points):q.co=(*p,1)
    return obj(name,c,material)

def text(body,p,size=.5,material='Cream'):
    c=bpy.data.curves.new('Lettering '+body,'FONT');c.body=body;c.size=size
    c.align_x='CENTER';c.align_y='CENTER';c.extrude=.008;c.bevel_depth=.002
    o=obj('Sign '+body,c,material);o.location=p;o.rotation_euler=(math.pi/2,0,0)
    return o

def window(x,z,w=1.3,h=1.7,lit='WindowWarm',y=-2.55):
    box('Window recess',(x,y+.03,z),(w+.2,.15,h+.2),'Ink')
    box('Glazing',(x,y-.06,z),(w,.035,h),lit,.0)
    for dx in [-w/2,w/2]:box('Jamb',(x+dx,y-.10,z),(.07,.12,h+.13),'Edge')
    for dz in [-h/2,h/2]:box('Lintel',(x,y-.10,z+dz),(w+.14,.12,.07),'Edge')
    box('Mullion',(x,y-.14,z),(.05,.08,h),'Steel',.005)
    box('Sill',(x,y-.2,z-h/2),(w+.3,.4,.09),'Plaster')
    for i in range(3):box('Blind',(x,y-.10,z+h/2-.13-i*.12),(w,.05,.035),'Steel',.003)

def door(x,y=-2.6,color='Blue'):
    box('Door frame',(x,y,1.35),(1.5,.16,2.7),'Ink')
    box('Door leaf',(x,y-.10,1.34),(1.25,.1,2.48),color)
    box('Door glass',(x,y-.17,1.85),(.94,.02,1.05),'Glass',.004)
    box('Door handle',(x+.44,y-.24,1.2),(.04,.08,.30),'Cream',.01)
    box('Door light',(x,y-.2,2.7),(1.1,.05,.07),'Amber',.005)
    box('Threshold',(x,y-.22,.08),(1.6,.55,.16),'Steel')

def aircon(x,z,y=-2.85):
    box('AC housing',(x,y,z),(1.25,.6,.85),'Plaster',.07)
    cylinder('Fan recess',(x-.15,y-.32,z),.32,.04,'Ink',24,(math.pi/2,0,0))
    cylinder('Fan hub',(x-.15,y-.36,z),.07,.06,'Edge',12,(math.pi/2,0,0))
    for a in range(8):
        t=math.tau*a/8
        tube('Fan grille',[(x-.15+math.cos(t)*.08,y-.4,z+math.sin(t)*.08),(x-.15+math.cos(t)*.3,y-.4,z+math.sin(t)*.3)],.012,'Edge')
    for a in [-.23,-.1,.03,.16]:box('AC vent',(x+.44,y-.32,z+a),(.18,.025,.035),'Ink',0)

def shell(height,color='Blue'):
    box('Main shell',(0,.2,height/2),(8.8,5.4,height),color,.07)
    box('Foundation',(0,-.02,.18),(9,5.25,.36),'Steel',.04)
    for x in [-4.3,4.3]:box('Corner pier',(x,-2.58,height/2),(.23,.28,height),'Steel')
    for z in [3.2,height-.15]:box('Floor cornice',(0,-.02,z),(9.15,5.6,.22),'Edge')
    box('Roof coping',(0,.2,height+.08),(9.2,5.8,.18),'Steel')
    box('Roof inset',(0,.2,height+.12),(8.5,5.0,.12),'Ink')
    for x in [-4.4,4.4]:box('Parapet side',(x,.2,height+.4),(.16,5.5,.7),'Steel')
    box('Roof rear parapet',(0,2.95,height+.4),(8.8,.16,.7),'Steel')
    tube('Drain pipe',[(4.02,-2.83,.3),(4.02,-2.83,height-.6),(3.6,-2.83,height-.2)],.065,'Edge')
    for z in [1,3.4,5.8]:box('Pipe bracket',(4.02,-2.78,z),(.20,.16,.08),'Ink')
    box('Roof equipment',(1.8,.2,height+.6),(1.8,1.5,1.0),'Steel',.06)
    for k in range(6):box('Roof ventilation',(1.8,-.57,height+.3+k*.11),(1.5,.04,.04),'Edge',0)

def ramen():
    root('NoodleCorner');shell(7.4,'Blue')
    for x in [-2.8,-.1,2.4]:window(x,5.25,1.65,2.05,'WindowWarm')
    box('Kitchen recess',(-1.5,-2.63,1.65),(4.7,.18,2.5),'Ink')
    box('Kitchen back',(-1.5,-2.76,1.85),(4.3,.03,1.9),'Wood')
    box('Counter',(-1.5,-3.07,.95),(4.7,.95,1.15),'Steel',.08)
    box('Counter top',(-1.5,-3.15,1.55),(4.95,1.15,.12),'Wood',.04)
    for x in [-3,-1.9,-.8,.3]:
        cylinder('Serving bowl',(x,-3.2,1.68),.15,.13,'Cream')
    for x in [-3.25,-1.5,.25]:
        cylinder('Stool seat',(x,-3.7,.72),.29,.12,'Red')
        cylinder('Stool stem',(x,-3.7,.34),.06,.65,'Steel')
        cylinder('Stool foot',(x,-3.7,.05),.22,.07,'Steel')
    door(2.6,color='Red')
    roof=box('Sloping canopy',(-1.5,-3.1,3.12),(5.25,1.7,.14),'Steel');roof.rotation_euler.x=math.radians(9)
    box('Canopy light',(-1.5,-3.94,2.98),(4.9,.07,.07),'Amber',.008)
    for i in range(7):box('Fabric noren',(-3.6+i*.69,-3.95,2.7),(.63,.035,.47),'Red',.015)
    text('BROTH',(-1.5,-4.0,2.72),.28)
    box('Shop sign',(-.8,-2.81,3.85),(5.2,.18,.85),'Ink',.08)
    text('RAMEN 08',(-.8,-2.93,3.85),.58,'Amber')
    aircon(3.2,6.25)
    cylinder('Roof water tank',(-2.1,.3,8.4),.8,1.7,'Rust',24)
    for z in [7.65,8.4,9.15]:cylinder('Tank band',(-2.1,.3,z),.83,.07,'Steel',24)
    for z in [4.8,5.8]:
        box('Side vertical sign',(4.6,-2.9,z),(.8,.25,1.0),'Steel')
    text('08',(4.6,-3.05,5.3),.48,'Cyan')
    return ROOT

def repair():
    root('CircuitRepair');shell(8.7,'Brick')
    # Alternating inlaid masonry courses, deliberate rhythm rather than random scratches.
    for row in range(12):
        for col in range(8):
            x=-3.8+col*1.05+(.52 if row%2 else 0)
            if x<4.0:box('Masonry joint',(x,-2.516,3.65+row*.4),(.95,.012,.012),'Steel',0)
    window(-2.25,6.3,2.0,2.3,'WindowCool')
    window(.3,6.3,1.8,2.3,'Glass')
    box('Workshop shutter',(-2.45,-2.65,1.58),(3.0,.16,2.8),'Steel')
    for i in range(14):box('Shutter rib',(-2.45,-2.76,.28+i*.19),(2.9,.08,.045),'Edge',.005)
    door(.25,color='Steel')
    window(2.5,1.8,2.0,2.2,'Glass',y=-2.72)
    for x,z in [(1.9,1.4),(2.7,1.4),(2.3,2.2)]:
        box('Monitor chassis',(x,-2.88,z),(.53,.2,.44),'Ink',.05)
        box('Monitor phosphor',(x,-3.0,z),(.4,.025,.29),'Cyan',.02)
    box('Workshop fascia',(0,-2.85,3.65),(8.1,.3,.65),'Blue')
    text('CIRCUIT',(0,-3.02,3.67),.52,'Cream')
    box('Fascia underline',(0,-3.04,3.3),(7.8,.05,.05),'Cyan',.007)
    aircon(2.9,7.5);aircon(2.9,6.35)
    tube('Conduit',[(-4,-2.85,7.8),(-3.4,-2.85,7.8),(-3.4,-2.85,4.4),(3,-2.85,4.4),(3,-2.85,3.9)],.05)
    # Real projecting maintenance balcony with an open rail.
    box('Balcony floor',(-1,-3.1,4.85),(5.5,1.1,.12),'Steel')
    for x in [-3.6,-2.7,-1.8,-.9,0,.9,1.7]:box('Balustrade',(x,-3.63,5.3),(.055,.06,.9),'Edge',.007)
    box('Balcony handrail',(-1,-3.63,5.76),(5.5,.09,.08),'Edge')
    return ROOT

def clinic():
    root('LumenClinic');shell(9.8,'Plaster')
    for x in [-2.85,0,2.85]:
        for z in [5.15,7.9]:window(x,z,1.85,1.9,'WindowCool')
    door(0,color='Blue')
    window(-2.8,1.7,2.0,2.15,'WindowCool')
    window(2.8,1.7,2.0,2.15,'Glass')
    for x in [-4.0,4.0]:box('Clinic piers',(x,-2.8,1.6),(.35,.55,3.2),'Blue')
    box('Clinic fascia',(0,-2.83,3.55),(7.7,.4,.72),'Blue')
    text('L U M E N',(0,-3.05,3.55),.46,'Cream')
    box('Entrance canopy',(0,-3.12,2.95),(3.6,1.3,.18),'Steel')
    box('Canopy neon',(0,-3.8,2.96),(3.45,.05,.055),'Cyan',.005)
    box('Cross panel',(4.58,-2.9,5.0),(1.15,.32,1.6),'Steel',.12)
    box('Cross vertical',(4.58,-3.08,5.0),(.22,.045,.95),'Cyan',.02)
    box('Cross horizontal',(4.58,-3.08,5.0),(.8,.045,.23),'Cyan',.02)
    aircon(-3.0,9.15,y=-2.8)
    return ROOT

def arcade():
    root('OndaArcade');shell(8.0,'Steel')
    # One tall screened bay and a louver tower break the other buildings' window grid.
    box('Upper bay',(0,-2.65,5.75),(5.2,.3,3.0),'Ink',.05)
    for x in [-1.65,0,1.65]:window(x,5.75,1.3,2.7,'Glass',y=-2.85)
    for z in [4.65,4.9,5.15,5.4,5.65,5.9,6.15,6.4,6.65]:
        box('Vent louver',(3.45,-2.9,z),(1.15,.22,.08),'Edge',.01)
    tube('Industrial duct',[(-3.6,-2.9,3.8),(-3.6,-2.9,7.8),(-2.5,-2.9,8.6),(-2.5,-1,8.6)],.24,'Edge')
    box('Arcade entrance',(0,-2.65,1.5),(7,.18,2.8),'Ink')
    door(-2.65,color='Red')
    for x in [-.85,.7,2.25]:
        box('Arcade cabinet',(x,-2.96,.9),(.95,.8,1.75),'Blue',.09)
        hood=box('Screen hood',(x,-3.08,1.55),(.88,.4,.75),'Ink',.06);hood.rotation_euler.x=math.radians(-8)
        box('Arcade screen',(x,-3.31,1.58),(.64,.025,.43),'Rose',.015)
        box('Control deck',(x,-3.45,1.03),(.9,.45,.12),'Steel')
        cylinder('Joystick',(x-.2,-3.47,1.18),.025,.2,'Red',8)
        cylinder('Arcade button',(x+.2,-3.51,1.11),.035,.025,'Amber',12)
    box('Arcade canopy',(0,-3.2,2.97),(7.4,1.45,.18),'Ink')
    box('Arcade neon',(0,-3.94,2.97),(7.3,.04,.06),'Rose',.008)
    box('Sign plate',(0,-2.87,3.65),(7.6,.24,.9),'Ink',.1)
    text('W A V E',(0,-3.02,3.65),.62,'Rose')
    return ROOT

BUILDERS={'noodle_corner':ramen,'circuit_repair':repair,'lumen_clinic':clinic,'onda_arcade':arcade}

def initialize():
    scene=bpy.data.scenes.get(SCENE_NAME)
    if scene is None:scene=bpy.data.scenes.new(SCENE_NAME)
    bpy.context.window.scene=scene
    for o in list(scene.objects):bpy.data.objects.remove(o,do_unlink=True)
    palette()


def planter():
    root('StreetPlanter')
    box('Concrete trough',(0,0,.26),(2.6,.85,.52),'Plaster',.08)
    box('Trough rim',(0,0,.54),(2.7,.94,.12),'Steel',.03)
    box('Soil',(0,0,.59),(2.45,.7,.04),'Ink')
    for x in [-.9,-.3,.3,.9]:
        tube('Stem',[(x,0,.58),(x+.06,0,1.1)],.018,'Wood')
        for i in range(6):
            a=i*math.tau/6+x
            tip=Vector((x+math.cos(a)*.46,math.sin(a)*.30,.92+(i%2)*.18))
            base=Vector((x,0,.7));mid=(base+tip)/2+Vector((0,0,.15))
            side=Vector((-math.sin(a)*.12,math.cos(a)*.12,0))
            mesh=bpy.data.meshes.new('Leaf blade');mesh.from_pydata([base,mid-side,tip,mid+side,mid],[],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)]);mesh.update()
            o=obj('Leaf',mesh,'LeafLight' if i%3==0 else 'Leaf');mod=o.modifiers.new('Leaf thickness','SOLIDIFY');mod.thickness=.009
    box('Planter marker',(0,-.49,.32),(.7,.025,.035),'Cyan',.005)
    return ROOT

def bench():
    root('TransitBench')
    for x in [-1,1]:
        box('Bench foot',(x,0,.25),(.13,.8,.5),'Steel')
        tube('Back leg',[(x,.25,.12),(x,.25,.5),(x,.40,1.05)],.055,'Edge')
    for y in [-.28,-.1,.08,.26]:box('Seat slat',(0,y,.5),(2.5,.14,.07),'Wood')
    for z in [.72,.89,1.06]:box('Back slat',(0,.36,z),(2.5,.07,.12),'Wood')
    for x in [-1.2,1.2]:tube('Arm rest',[(x,-.3,.5),(x,-.3,.79),(x,.35,.79)],.035,'Edge')
    return ROOT

def terminal():
    root('TransitTerminal')
    box('Terminal foot',(0,0,.09),(.8,.65,.18),'Steel',.07)
    box('Pedestal',(0,0,.75),(.56,.48,1.4),'Blue',.08)
    head=box('Ticket head',(0,-.08,1.6),(.78,.58,.9),'Steel',.1)
    box('Ticket display',(0,-.39,1.72),(.59,.02,.40),'Cyan',.02)
    box('Screen graphic',(0,-.405,1.74),(.40,.008,.07),'Ink',.004)
    for i in range(3):box('Screen line',(-.07,-.405,1.65+i*.065),(.24,.008,.018),'Ink',0)
    for x in [-.15,0,.15]:
        for z in [1.19,1.29,1.39]:box('Key',(x,-.39,z),(.08,.03,.055),'Cream',.01)
    box('Ticket slot',(0,-.39,1.06),(.38,.025,.07),'Ink')
    box('Terminal cap',(0,-.08,2.1),(.9,.65,.13),'Blue',.05)
    text('08',(0,-.34,.65),.2,'Cream')
    return ROOT

def van():
    root('ServiceVan')
    profile=[(-2,.45),(2,.45),(2,1.02),(1.35,1.18),(.85,1.95),(-1.7,1.95),(-2,1.65)]
    n=len(profile);vs=[(x,y,z) for y in [-.82,.82] for x,z in profile]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new('Van formed shell');mesh.from_pydata(vs,[],fs);mesh.update()
    o=obj('Van shell',mesh,'Blue');m=o.modifiers.new('Pressed panel edges','BEVEL');m.width=.07;m.segments=3;o.modifiers.new('Panel normals','WEIGHTED_NORMAL')
    for side in [-1,1]:
        y=side*.845
        vs=[(-.05,y,1.23),(1.2,y,1.23),(.77,y,1.81),(-.05,y,1.81)]
        me=bpy.data.meshes.new('Cab window');me.from_pydata(vs,[],[(0,1,2,3)] if side<0 else [(3,2,1,0)]);me.update();obj('Cab glass',me,'Glass')
        box('Cargo inset',(-1.05,y,1.35),(1.5,.025,.9),'Steel',.025)
        box('Cargo livery',(-1.05,y+side*.02,1.05),(1.5,.025,.10),'Cream',.005)
        box('Door trim',(-.12,y+side*.02,1.16),(.025,.03,1.0),'Ink',.003)
        box('Door handle',(.15,y+side*.04,1.12),(.23,.04,.045),'Edge',.008)
        for x in [-1.3,1.25]:
            cylinder('Tyre',(x,side*.78,.41),.39,.27,'Rubber',20,(math.pi/2,0,0))
            cylinder('Steel rim',(x,side*.94,.41),.24,.04,'Edge',16,(math.pi/2,0,0))
            cylinder('Wheel hub',(x,side*.97,.41),.10,.05,'Steel',12,(math.pi/2,0,0))
    for y in [-.55,.55]:box('Headlight',(2.02,y,.91),(.035,.28,.17),'Amber',.025)
    box('Front bumper',(2.04,0,.55),(.2,1.78,.18),'Steel',.06)
    box('Roof rack',(-.6,0,2.04),(1.8,1.55,.08),'Steel')
    for x in [-1.3,.1]:box('Rack slat',(x,0,2.1),(.08,1.55,.06),'Edge')
    return ROOT

PROP_BUILDERS={'planter':planter,'bench':bench,'terminal':terminal,'service_van':van}

# Export only the chosen module and merge evaluated geometry by material for low draw cost.
# The editable source parts in the .blend are preserved.
def export_asset(name,asset):
    deps=bpy.context.evaluated_depsgraph_get();inverse=asset.matrix_world.inverted()
    groups={}
    for child in asset.children_recursive:
        if child.type not in {'MESH','CURVE','FONT','SURFACE'}:continue
        evaluated=child.evaluated_get(deps);me=evaluated.to_mesh()
        if me is None:continue
        transform=inverse @ child.matrix_world
        normal_transform=transform.to_3x3().inverted().transposed()
        for poly in me.polygons:
            material=me.materials[poly.material_index] if me.materials else M['Steel']
            group=groups.setdefault(material.name,{'verts':[],'faces':[],'normals':[],'material':material})
            start=len(group['verts']);face=[]
            for li in poly.loop_indices:
                loop=me.loops[li];group['verts'].append(transform @ me.vertices[loop.vertex_index].co)
                group['normals'].append((normal_transform @ me.corner_normals[li].vector).normalized())
                face.append(start+len(face))
            group['faces'].append(face)
        evaluated.to_mesh_clear()
    export_root=bpy.data.objects.new(name,None);bpy.context.scene.collection.objects.link(export_root)
    created=[]
    for name_mat,group in groups.items():
        mesh=bpy.data.meshes.new(name+'_'+name_mat);mesh.from_pydata(group['verts'],[],group['faces']);mesh.update()
        for poly in mesh.polygons:poly.use_smooth=True
        mesh.normals_split_custom_set(group['normals']);mesh.materials.append(group['material'])
        o=bpy.data.objects.new(name_mat,mesh);bpy.context.scene.collection.objects.link(o);o.parent=export_root;created.append(o)
    bpy.ops.object.select_all(action='DESELECT');export_root.select_set(True)
    for o in created:o.select_set(True)
    bpy.context.view_layer.objects.active=export_root
    bpy.ops.export_scene.gltf(filepath=OUT+'/'+name+'.glb',export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_cameras=False,export_lights=False)
    print(name, len(groups), 'material meshes')
    for o in created:bpy.data.objects.remove(o,do_unlink=True)
    bpy.data.objects.remove(export_root,do_unlink=True)


def rebuild_library():
    initialize()
    for index,(name,build) in enumerate(BUILDERS.items()):
        asset=build(); export_asset(name,asset); asset.location.x=-13.5+index*9.0
    for index,(name,build) in enumerate(PROP_BUILDERS.items()):
        asset=build(); export_asset(name,asset); asset.location=(-9+index*6,-7,0)
    bpy.ops.wm.save_as_mainfile(filepath=SOURCE)
