"""Fabricate the sounding works, sail loft and tidal landing in an isolated Blender scene."""
from math import cos, sin, pi, tau
from pathlib import Path
from random import Random

import bpy
from mathutils import Matrix, Vector

models = Path(__file__).resolve().parents[2] / "scenes/environment/night_district/models"
previous = bpy.context.window.scene
stage = bpy.data.scenes.new("Sounding Works fabrication")
materials = {}
# Linear pigments. The same enamel ages from dark petrol to verdigris across all four sites.
for name, color, emission in [
    ("Pitch", (.019,.030,.038), 0), ("Iron", (.061,.089,.097), 0),
    ("Zinc", (.26,.32,.30), 0), ("Teal", (.054,.27,.25), 0),
    ("Oxide", (.36,.074,.041), 0), ("Flame", (.68,.17,.064), 0),
    ("Bone", (.77,.64,.39), 0), ("Canvas", (.46,.32,.17), 0),
    ("Mustard", (.70,.37,.079), 0), ("Lamp", (1,.55,.20), 1.35),
    ("Glass", (.13,.78,.64), .65), ("Net", (.25,.37,.31), 0),
    ("Timber", (.18,.115,.075), 0), ("Bark", (.085,.092,.075), 0),
    ("Reed", (.085,.23,.12), 0), ("Leaf", (.18,.36,.12), 0),
    ("Bud", (.40,.46,.14), 0), ("Moss", (.05,.105,.085), 0)
]:
    m = bpy.data.materials.new("Quayside " + name)
    m.use_nodes = True
    n = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    n.inputs["Base Color"].default_value = (*color,1)
    n.inputs["Roughness"].default_value = .78
    if emission:
        n.inputs["Emission Color"].default_value = (*color,1)
        n.inputs["Emission Strength"].default_value = emission
    materials[name] = m

# One mesh per site with shared material slots. Coordinates use Blender Z up, front at -Y.
verts, faces, indices = [], [], []
swatches = list(materials)
def part(points, polygons, color):
    start = len(verts)
    verts.extend(points)
    for poly in polygons:
        faces.append(tuple(start+i for i in poly))
        indices.append(swatches.index(color))

def block(x,y,z,w,d,h,c):
    points=[(x+i*w/2,y+j*d/2,z+k*h/2) for k in (-1,1) for j in (-1,1) for i in (-1,1)]
    part(points,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(1,3,7,5),(3,2,6,7),(2,0,4,6)],c)

def rod(points,r,c,sides=7):
    pts=list(map(Vector,points))
    rings=[]
    for i,p in enumerate(pts):
        axis=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
        side=axis.cross(Vector((0,1,0)))
        if side.length < .05: side=axis.cross(Vector((1,0,0)))
        side.normalize()
        up=axis.cross(side)
        rings += [p+r*(side*cos(tau*j/sides)+up*sin(tau*j/sides)) for j in range(sides)]
    walls=[(i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j)
           for i in range(len(pts)-1) for j in range(sides)]
    part(rings,[tuple(reversed(range(sides))),*walls,tuple(range(len(rings)-sides,len(rings)))],c)

def plate(profile,y,depth,c):
    n=len(profile)
    part([(x,yy,z) for yy in (y,y+depth) for x,z in profile],
         [tuple(range(n)),tuple(reversed(range(n,2*n)))]+
         [(j,(j+1)%n,n+(j+1)%n,n+j) for j in range(n)],c)

def sign(words,x,y,z,size,color):
    data=bpy.data.curves.new(words,'FONT')
    data.body=words
    data.size=size
    data.align_y='CENTER'
    ob=bpy.data.objects.new(words,data)
    stage.collection.objects.link(ob)
    ob.location=(x,y,z)
    ob.rotation_euler.x=pi/2
    data.materials.append(materials[color])

def bake_mesh(name):
    geo=bpy.data.meshes.new(name)
    geo.from_pydata(verts,[],faces)
    for m in materials.values(): geo.materials.append(m)
    for poly,idx in zip(geo.polygons,indices): poly.material_index=idx
    geo.update()
    ob=bpy.data.objects.new(name,geo)
    stage.collection.objects.link(ob)
    verts.clear()
    faces.clear()
    indices.clear()
    return ob

def finish(name):
    bake_mesh(name)
    bpy.ops.export_scene.gltf(filepath=str(models/(name+'.glb')),export_format='GLB',
                              use_active_scene=True,export_animations=False)
    for item in list(stage.objects): bpy.data.objects.remove(item,do_unlink=True)

def survey_van_rack():
    # Winch drum, rollers, coiled trawl cable and a belted marker float ride on the old van rack.
    x=-.65
    for y in (-.58,.58):
        block(x,y,2.16,2.34,.095,.14,'Zinc')
        for end in (-1.48,.18):
            block(end,y,2.32,.155,.14,.36,'Oxide')
    rod([(-1.50,0,2.50),(.11,0,2.50)],.21,'Timber',16)
    for i in range(11):
        xx=-1.28+i*.096
        rod([(xx,0,2.50),(xx+.078,0,2.50)],.258,'Net' if i%4 else 'Canvas',16)
    for xx in (-1.41,-.18):
        rod([(xx,0,2.50),(xx+.07,0,2.50)],.348,'Oxide',16)
    for y in (-.46,.48):
        rod([(-1.58,y,2.27),(-1.44,y,2.68),(-1.15,y,2.68)],.032,'Bone')
    rod([(.05,-.6,2.22),(.43,-.6,2.22)],.135,'Mustard',8)
    finish('net_winch')

def sounding_works():
    # Enamel slip board covers the old hoarding. A faded tide scale is visible behind the rig.
    block(-2.4,-1.86,4.73,11.48,.23,3.62,'Iron')
    for i in range(27):
        x=-7.97+i*.43
        block(x,-2.0,4.73,.033,.058,3.50,'Pitch')
        block(x,-2.04,3.23,.032,.03,.18 if i%5 else .36,'Zinc')
    for z in (3.0,6.46): block(-2.4,-1.98,z,11.56,.32,.11,'Zinc')
    # The diver's survey sled hangs in two copper slings on a riveted rail.
    for x in (-6.6,-1.55):
        rod([(x,-1.99,5.21),(x,-2.90,6.24),(x,-1.98,6.24)],.077,'Oxide')
        rod([(x,-2.78,6.25),(x,-2.78,5.93)],.08,'Zinc')
    block(-4.1,-2.84,6.15,6.10,.12,.16,'Oxide')
    for x in (-5.8,-2.18):
        rod([(x,-2.86,6.18),(x+.04,-2.86,5.58)],.031,'Bone')
        rod([(x,-2.86,5.7),(x-.38,-3.07,4.78),(x-.31,-3.15,4.21)],.044,'Canvas')
    # Lofted hull. Long cream belly, green flanks, an oxide spine and angled nose.
    stations=[(-6.38,4.69,.13,.14),(-5.68,4.68,.37,.36),(-4.65,4.73,.60,.63),
              (-3.35,4.79,.70,.72),(-2.40,4.82,.65,.71),(-1.70,4.88,.45,.49),(-1.32,4.88,.16,.23)]
    for a,b in zip(stations,stations[1:]):
        for j in range(12):
            sides=[]
            for station,k in ((a,j),(a,j+1),(b,j+1),(b,j)):
                x,z,ry,rz=station
                sides.append((x,-2.73+ry*cos(tau*k/12),z+rz*sin(tau*k/12)))
            part(sides,[(0,1,2,3)],'Oxide' if j in (1,2,3,4) else 'Bone' if j in (7,8,9,10) else 'Teal')
    # Forked rudder, foils and dorsal sonar aerial. Outline follows actual metal panels.
    tail=[(-6.17,4.69),(-7.58,5.57),(-7.43,5.12),(-7.08,4.68),(-7.72,3.83),(-7.27,3.94)]
    plate(tail,-2.86,.23,'Flame')
    rod([(-7.48,-2.89,5.47),(-6.99,-2.89,4.84),(-6.36,-2.89,4.69)],.028,'Bone')
    plate([(-4.97,5.12),(-4.34,5.84),(-3.64,6.02),(-3.47,5.32)],-2.80,.13,'Mustard')
    for i in range(4):rod([(-4.66+i*.24,-2.83,5.26),(-4.32+i*.19,-2.83,5.66+i*.07)],.019,'Bone')
    plate([(-4.27,4.66),(-3.54,4.58),(-4.69,3.67),(-5.13,3.62)],-3.39,.13,'Oxide')
    rod([(-5.02,-3.42,3.67),(-3.71,-3.42,4.52)],.042,'Flame')
    for x,z,r in [(-2.21,4.97,.34),(-2.98,4.98,.18),(-3.59,4.98,.15)]:
        for y,rad,c in [(-3.36,r,'Pitch'),(-3.40,r*.83,'Zinc'),(-3.44,r*.64,'Glass')]:
            rod([(x,y+.08,z),(x,y,z)],rad,c,16)
    for i in range(10):
        x=-5.74+i*.32
        block(x,-3.36 if -4.70<x<-2.6 else -3.20,4.58,.055,.035,.046,'Zinc')
    rod([(-1.52,-2.77,4.9),(-1.24,-2.77,4.91),(-.70,-2.77,5.48),(-.54,-2.77,5.52)],.046,'Zinc')
    rod([(-.54,-2.77,5.55),(-.54,-2.77,5.32)],.105,'Lamp',12)
    # Yard name, ship number and the mechanic's fan of depth marks.
    block(1.00,-2.03,4.75,3.85,.09,2.91,'Teal')
    block(-.77,-2.10,4.77,.075,.04,2.72,'Mustard')
    # Expansion rings and a copper capillary describe how the pressure hull is assembled.
    for x,z,ry,rz in (stations[2],stations[3],stations[4]):
        hoop=[(x,-2.73+(ry+.014)*cos(tau*i/24),z+(rz+.014)*sin(tau*i/24)) for i in range(25)]
        rod(hoop,.024,'Zinc',6)
    rod([(-6.25,-2.89,4.70),(-5.70,-3.12,4.83),(-4.78,-3.28,4.91),
         (-4.51,-3.34,5.04),(-3.86,-3.39,5.11)],.037,'Mustard')
    for i in range(7):
        x=-5.63+i*.17
        rod([(x,-3.08-i*.029,4.79),(x+.10,-3.14-i*.026,4.97)],.033,'Pitch',5)
    for x in [-6.65,-1.54]:
        rod([(x,-2.84,6.18),(x,-2.84,6.48)],.078,'Iron')
        rod([(x,-2.86,6.25),(x,-2.98,6.25)],.13,'Zinc',12)
    finish('sounding_works')

def sail_loft():
    # A converted brick smokehouse. Tall vents and the asymmetric drying frame break the roofline.
    block(0,.17,3.18,8.7,5.2,6.36,'Oxide')
    for x,h in [(-3.20,1.49),(-2.43,1.91)]:
        rod([(x,.4,6.1),(x,.4,6.1+h)],.23,'Iron',12)
        rod([(x,.4,5.98+h),(x,.4,6.13+h)],.30,'Zinc',12)
    block(0,-.05,6.33,8.96,5.12,.18,'Iron')
    block(.63,-2.55,1.72,5.8,.26,3.42,'Pitch')
    for j in range(14):block(.63,-2.73,.25+j*.215,5.67,.12,.12,'Iron')
    for x in (-3.8,-2.65):
        block(x,-2.59,4.85,.92,.14,1.7,'Pitch')
        for n in range(3):block(x,-2.69,4.32+n*.48,.70,.06,.36,'Net' if n==1 else 'Zinc')
    for x in (-3.82,2.79):
        rod([(x,-3.33,.05),(x,-3.33,5.63)],.098,'Timber')
        rod([(x,-2.45,4.35),(x,-3.36,5.50)],.08,'Zinc')
    # Diamond mesh follows sagging cords with uneven weights on its lower edge.
    def netpoint(u,v):
        return (-3.73+4.29*u,-3.39-.22*sin(pi*u)-.09*v,5.36-.54*sin(pi*u)-v*(1.43+.64*sin(pi*u)))
    rod([netpoint(i/16,0) for i in range(17)],.054,'Bone')
    for slope in (-1,1):
        for j in range(-6,22):
            coords=[]
            for i in range(25):
                v=i/24
                u=(j+slope*4.5*v)/16
                if 0<=u<=1:coords.append(netpoint(u,v))
            if len(coords)>1: rod(coords,.020,'Net',4)
    for i in range(9):
        x,y,z=netpoint(i/8,0)
        rod([(x,y,z-.011),(x+.08,y,z+.02)],.072,'Mustard')
    block(2.29,-2.89,4.81,2.61,.17,1.55,'Bone')
    sign('NET',1.16,-2.99,5.03,.51,'Pitch')
    sign('LOFT',1.16,-2.99,4.48,.56,'Oxide')
    for i in range(5):
        block(-2.85+i*.13,-2.77,1.20,.055,.05,1.25,'Mustard')
    # Net needles, seine floats and a leaning repair ladder flank the painted roller door.
    for x in (-3.88,-3.27):
        rod([(x,-3.18,.08),(x+.20,-2.61,2.63)],.058,'Mustard')
    for i in range(7):
        k=i/7
        rod([(-3.86+.18*k,-3.16+.54*k,.26+.31*i),(-3.27+.18*k,-3.16+.54*k,.26+.31*i)],.040,'Zinc')
    for x,z in [(3.66,2.31),(3.94,1.83),(3.35,1.54)]:
        rod([(x,-2.60,z+.39),(x+.01,-2.74,z+.12)],.024,'Canvas')
        rod([(x,-2.74,z+.09),(x,-2.74,z-.20)],.105,'Mustard')
    for i in range(6):
        pts=[(3.66+.43*cos(j*tau/18),-2.89+.26*sin(j*tau/18),.12+.063*i) for j in range(19)]
        rod(pts,.038,'Canvas',5)
    finish('net_loft')

def salt_willow():
    # A tree rooted inside a cut-open salt tank. Bent boughs carry overlapping sprays of salt leaves.
    rng=Random(93)
    for z,r,c in [(.13,.95,'Iron'),(.45,.84,'Teal'),(.67,.89,'Zinc'),(.70,.76,'Moss')]:
        rod([(0,0,z-.12),(0,0,z+.05)],r,c,16)
    rod([(-.31,0,.65),(-.17,-.09,1.32),(.13,.01,2.11),(.02,.16,2.92)],.21,'Bark',8)
    rod([(-.28,-.14,.73),(-.17,-.24,1.36),(.03,-.17,2.08)],.047,'Timber')
    sprays=[(-2.11,.20,3.01,1.03),(-1.55,-.52,3.28,1.12),(-.97,.40,4.05,1.18),
            (-.18,.47,4.35,1.15),(.55,-.15,4.06,1.1),(1.29,.09,3.57,1.05),
            (1.72,.29,3.18,.76),(-.48,-.49,3.31,1.22),(.64,-.49,3.18,.86)]
    for x,y,z,r in sprays:
        rod([(.05,.05,1.72),(.26*x,.08,2.47),(.72*x,y*.7,z-.52),(x,y,z-.14)],.096,'Bark')
        for j in range(14):
            a=rng.uniform(0,tau)
            dist=r*rng.random()**.5
            xx,yy=x+dist*cos(a),y+.72*dist*sin(a)
            zz=z+.33*(1-dist/r)+rng.uniform(-.16,.15)
            size=rng.uniform(.35,.60)
            shade=rng.choice(('Moss','Reed','Leaf','Leaf','Bud')) if j>3 else 'Moss'
            # Serrated sprays taper outward. The free tip droops below the main leaf mass.
            ang=a+.3
            dx,dy=cos(ang),sin(ang)
            contour=[(-.45,0),(-.10,.34),(.19,.32),(.12,.48),(.61,.22),(.54,.35),
                     (1.12,.02),(.85,-.15),(.94,-.22),(.46,-.26),(.52,-.39),(.02,-.29)]
            pts=[(xx+size*(u*dx-v*dy),yy+size*(u*dy+v*dx),zz-size*(.24*u+.21*abs(v))) for u,v in contour]
            mid=len(pts)
            pts.append((xx+.08*dx,yy+.08*dy,zz+.115))
            part(pts,[(mid,(i+1)%mid,i) for i in range(mid)],shade)
            if j%3==0:
                end=pts[6]
                rod([end,(end[0]+.06,end[1],end[2]-.24),(end[0]+.01,end[1],end[2]-.39)],.016,shade,4)
    finish('salt_willow')

def tidal_landing():
    # Water level is at 0. The existing wall caps at .78. Slipped boards step down to the pontoon.
    rng=Random(51)
    for y in (.5,1.65,2.8,4.03):
        for x in (-1.35,1.38):
            rod([(x,y,-.25),(x,y,1.01+rng.random()*.34)],.112,'Timber')
            rod([(x,y,.73),(x,y,.83)],.13,'Zinc')
    for i in range(19):
        y=.40+i*.203
        h=.75-.11*min(i,5)
        block(rng.uniform(-.035,.035),y,h,2.81+rng.uniform(-.10,.09),.18,.13,'Timber' if i%4 else 'Canvas')
    for x in [-1.35,1.38]:
        for y in [.5,1.65,2.8]:
            rod([(x,y,.99),(x,y+.56,.78),(x,y+1.15,.97)],.028,'Canvas')
    bake_mesh("Landing boards")
    # Mooring float in the shape of an angler, lowered between two tyre fenders.
    cx,cy=3.29,3.56
    def bodyring(z,rx,ry):
        return [(cx+rx*cos(i*tau/16),cy+ry*sin(i*tau/16),z) for i in range(16)]
    rings=[(0,1.1,.80),(.21,1.64,1.14),(.52,1.59,1.10),(.68,1.49,1.04),
           (1.10,1.19,.88),(1.35,.76,.62),(1.46,.53,.43)]
    for i,(r,s) in enumerate(zip(rings,rings[1:])):
        part(bodyring(*r)+bodyring(*s),[(j,(j+1)%16,16+(j+1)%16,16+j) for j in range(16)],
             ['Pitch','Teal','Bone','Teal','Iron','Oxide'][i])
    rod([(cx,cy,1.39),(cx,cy,1.49)],.47,'Oxide',16)
    for x in [cx-.55,cx+.48]:
        rod([(x,cy+.63,.92),(x,cy+.93,.98)],.235,'Pitch',16)
        rod([(x,cy+.92,.98),(x,cy+.97,.99)],.164,'Glass',16)
    rod([(cx+.22,cy,1.45),(cx+.50,cy,1.93),(cx+.88,cy-.12,2.29),(cx+1.26,cy-.16,2.22),(cx+1.43,cy-.18,1.95)],.059,'Mustard')
    rod([(cx+1.43,cy-.18,1.99),(cx+1.43,cy-.18,1.76)],.145,'Lamp',12)
    for i in range(9):
        a=(i+.5)*pi/9
        xx,yy=cx+1.40*cos(a),cy+.97*sin(a)
        rod([(xx,yy,.60),(xx+.08*cos(a),yy+.08*sin(a),.80)],.045,'Mustard',6)
    rod([(cx-.47,cy+.47,1.27),(cx-.46,cy+.56,1.49),(cx+.04,cy+.57,1.50),
         (cx+.12,cy+.46,1.32)],.044,'Zinc')
    float_mesh=bake_mesh('SoundingFloat')
    # Put the pivot on the waterline to let the hull roll around its mooring.
    float_mesh.data.transform(Matrix.Translation((-cx,-cy,0)))
    float_mesh.location=(cx,cy,0)
    for i in range(2):
        x=1.57
        y=2.64+i*.95
        pts=[(x,y+.26*cos(tau*j/14),.32+.31*sin(tau*j/14)) for j in range(15)]
        rod(pts,.097,'Pitch')
    rod([(1.38,4.02,1.04),(2.44,4.09,.30),(cx,cy+.71,.68)],.035,'Canvas')
    # A mechanical tide staff gives the boat a scale against the seawall.
    block(-1.75,.78,1.18,.30,.16,2.93,'Bone')
    for i in range(11):
        block(-1.79,.88,.13+i*.238,.20 if i%2==0 else .095,.055,.049,'Oxide')
    finish('tidal_landing')

try:
    bpy.context.window.scene=stage
    sounding_works()
    sail_loft()
    survey_van_rack()
    salt_willow()
    tidal_landing()
finally:
    bpy.context.window.scene=previous
    bpy.data.scenes.remove(stage)
