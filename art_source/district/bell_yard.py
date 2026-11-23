"""Build the eastern pressure-test yard in an isolated Blender scene."""
from math import cos, pi, sin, tau
from pathlib import Path

import bpy
from mathutils import Vector

root = Path(__file__).resolve().parents[2]
library = root / "unused_assets/EverythingLibrary_Buildings_001/EverythingLibrary_Buildings_001.blend"
output = root / "scenes/environment/night_district/models/bell_yard.glb"
previous = bpy.context.window.scene
stage = bpy.data.scenes.new("Bell yard fabrication")
palette = {}


def pigment(name, rgb, glow=0):
    mat = bpy.data.materials.new("Bell yard " + name)
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Roughness"].default_value = .76
    shader.inputs["Emission Color"].default_value = (*rgb, 1)
    shader.inputs["Emission Strength"].default_value = glow
    palette[name] = mat


def finish(name, tone):
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(palette[tone])
    return obj


def box(name, loc, size, tone):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = finish(name, tone)
    obj.dimensions = size
    return obj


def pin(name, a, b, radius, tone, sides=12):
    line = Vector(b) - Vector(a)
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=line.length,
                                       location=(Vector(a) + Vector(b)) * .5)
    obj = finish(name, tone)
    obj.rotation_euler = line.to_track_quat('Z', 'Y').to_euler()
    return obj


def letters(words, loc, size, tone):
    bpy.ops.object.text_add(location=loc, rotation=(pi/2, 0, 0))
    obj = finish(words, tone)
    obj.data.body = words
    obj.data.size = size
    obj.data.space_character = 1.05
    bpy.ops.object.convert(target='MESH')


def crane():
    # Remap the original painted faces and retain the two-sided lattice faces.
    with bpy.data.libraries.load(str(library), link=True) as (source, target):
        target.scenes = source.scenes[:1]
    tower = target.scenes[0].objects["TowerCrane"]
    for original in tower.children:
        geo = original.data.copy()
        geo.materials.clear()
        tones = ["tar", "zinc", "ochre", "brass"]
        for tone in tones:
            geo.materials.append(palette[tone])
        colors = geo.color_attributes["colorSet1"]
        for face in geo.polygons:
            r, g, b, _ = colors.data[face.loop_start].color
            face.material_index = (2 if r < .55 else 3) if r > b * 2 else (0 if g < .09 else 1)
        geo.color_attributes.remove(colors)
        for v in geo.vertices:
            x, y, z = v.co
            v.co = (z * .00134 - 1.60, x * .00155 - 3.62, (y + 265) * .00102)
        obj = bpy.data.objects.new("Reconditioned derrick", geo)
        stage.collection.objects.link(obj)


def workshop():
    # The sawtooth roof admits north light over the pressure bench.
    box("Boiler shop", (0, .35, 2.25), (8.9, 5.9, 4.5), "green")
    for x, top in [(-3.00, 5.71), (0, 5.50), (3.00, 5.29)]:
        roof = box("Sloping roof", (x, .32, top - .55), (3.18, 6.0, .14), "zinc")
        roof.rotation_euler.y = -.32
        box("Clerestory", (x + 1.37, .32, top - .62), (.18, 5.91, 1.16), "glass")
        # Front gable closes the wedge under the roof.
        pts = [(xx, yy, zz) for yy in (-2.63, 3.26)
               for xx, zz in [(x-1.50,4.48), (x+1.50,4.48), (x+1.50,top-.06), (x-1.50,top-1.04)]]
        mesh = bpy.data.meshes.new("Gable")
        mesh.from_pydata(pts, [], [(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)])
        mesh.materials.append(palette["green"])
        stage.collection.objects.link(bpy.data.objects.new("Gable",mesh))
    for x in (-4.32, -.56, 4.30):
        box("Seam", (x,-2.66,2.22), (.15,.13,4.45), "zinc")
    box("Shutter rebate", (1.86,-2.67,1.53), (4.34,.12,3.06), "tar")
    for i in range(14):
        box("Rolling shutter", (1.86,-2.76,.13+i*.208), (4.07,.09,.167), "slate")
    box("Office light",(-2.68,-2.68,2.07),(2.80,.08,1.13),"glass")
    for x in (-4.00,-3.41,-2.85,-2.26,-1.66,-1.31):
        box("Wire glass bars",(x,-2.75,2.08),(.065,.08,1.2),"tar")
    box("Transom",(-2.67,-2.76,2.27),(2.82,.09,.055),"tar")
    box("Fascia",(-.11,-2.75,3.78),(8.22,.20,1.03),"tar")
    letters("BY",(-3.85,-2.87,3.53),.84,"brass")
    letters("BELL YARD",(-1.05,-2.87,3.64),.66,"ivory")
    letters("DIVE  /  PRESSURE WORKS",(-1.00,-2.87,3.39),.19,"brass")
    for x in (-3.82,3.70):
        box("Lamp shade",(x,-2.96,4.44),(.73,.40,.10),"zinc")
        box("Filament",(x,-2.98,4.37),(.54,.24,.04),"lamp")
    # Racks for the bell's keel sit just above the concrete.
    for x in (.66,2.32):
        box("Keel sleeper",(x,-3.62,.14),(.29,1.81,.28),"iron")


def capsule():
    x,y = 1.50,-3.62
    rings = [(.60,.84,"iron"),(.74,.96,"iron"),(.87,.86,"ochre"),
             (1.05,.88,"ochre"),(1.89,.80,"ochre"),(2.15,.73,"brass"),
             (2.40,.57,"slate"),(2.50,.29,"iron")]
    sides = 16
    pts = [(x+r*cos(tau*j/sides), y+r*sin(tau*j/sides), h) for h,r,_ in rings for j in range(sides)]
    faces = [(i*sides+j, i*sides+(j+1)%sides, (i+1)*sides+(j+1)%sides, (i+1)*sides+j)
             for i in range(len(rings)-1) for j in range(sides)]
    mesh = bpy.data.meshes.new("Pressure hull")
    mesh.from_pydata(pts,[],[tuple(reversed(range(sides))),*faces,tuple(range(len(pts)-sides,len(pts)))])
    for _,_,tone in rings:
        mesh.materials.append(palette[tone])
    for j,face in enumerate(mesh.polygons):
        face.material_index = max(0, min(len(rings)-1, (j-1)//sides))
    stage.collection.objects.link(bpy.data.objects.new("Pressure hull",mesh))
    pin("Hatch collar",(x,y-.63,1.60),(x,y-.89,1.60),.54,"iron",20)
    pin("Porthole bezel",(x,y-.89,1.60),(x,y-.96,1.60),.42,"brass",20)
    pin("Thick glass",(x,y-.96,1.60),(x,y-.99,1.60),.32,"lens",20)
    for i in range(8):
        a = tau*i/8
        xx,zz=x+.46*cos(a),1.60+.46*sin(a)
        pin("Hatch dog",(xx,y-.89,zz),(xx,y-.93,zz),.046,"ivory",6)
    pin("Relief valve",(x-.55,y-.27,2.09),(x-1.01,y-.27,2.09),.092,"iron")
    pin("Valve lip",(x-.97,y-.27,2.09),(x-1.05,y-.27,2.09),.13,"brass")
    for dx in (-.17,.17):
        pin("Hatch guard",(x+dx-.10,y-1.00,1.35),(x+dx+.10,y-1.00,1.83),.021,"iron")
    for dx in (-.56,.56):
        pin("Bale",(x+dx,y,2.13),(x,y,2.92),.048,"zinc")
    pin("Fall",(x,y,2.89),(x,y,5.32),.037,"tar")
    pin("Return fall",(x+.08,y,2.92),(x+.08,y,5.31),.022,"zinc")


def receiver_bank():
    # Steam mains and the pressure accumulator continue past the playable seawall.
    y, h = -.34, 1.82
    for x in (5.8, 8.8):
        box("Saddle", (x,y,.49), (.54,1.68,.98), "iron")
    pin("Receiver", (5.28,y,h),(9.38,y,h),1.06,"green",20)
    for x, step in [(5.28,-1),(9.38,1)]:
        for i,r in enumerate((1.06,1.01,.88,.66,.31)):
            end = x + step*.12
            pin("Dished end",(x,y,h),(end,y,h),r,"slate",20)
            x=end
    for x in (5.85,8.83):
        pin("Tank strap",(x,y,h),(x+.10,y,h),1.09,"iron",20)
    for i in range(2):
        x = 6.93 + i*.51
        pin("Bleed pipe",(x,y,h+.57),(x,y,3.63+i*.43),.11,"zinc")
        pin("Weather cap",(x,y,3.62+i*.43),(x,y,3.70+i*.43),.17,"tar")
    box("Receiver nameplate",(7.16,-1.417,1.82),(2.12,.025,.62),"green")
    letters("AIR  /  03",(6.26,-1.44,1.67),.39,"ivory")
    for i in range(3):
        yy = -3.1 + i*.52
        pin("Harbor main",(5.02,yy,.70),(17.00,yy,.70),.22,"slate" if i else "green")
        pin("Riser",(5.02,yy,.62),(5.02,yy,1.16),.23,"iron")
        for x in (5.56,8.02,11.52,15.42):
            pin("Expansion joint",(x,yy,.70),(x+.11,yy,.70),.27,"zinc")


try:
    bpy.context.window.scene = stage
    for name, rgb in {"tar":(.020,.030,.035), "green":(.055,.125,.124),
                      "slate":(.097,.16,.17), "iron":(.09,.095,.085),
                      "zinc":(.24,.30,.28), "ochre":(.50,.19,.048),
                      "brass":(.75,.40,.115), "ivory":(.85,.78,.56)}.items():
        pigment(name,rgb,.11 if name == "ivory" else 0)
    pigment("glass",(.30,.48,.40),.12)
    pigment("lens",(.06,.42,.36),.32)
    pigment("lamp",(1,.64,.25),1.30)
    crane()
    workshop()
    capsule()
    receiver_bank()
    # Bake the stationary yard to one object with shared material surfaces.
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = next(obj for obj in stage.objects if obj.type == 'MESH')
    bpy.ops.object.join()
    bpy.context.object.name = "BellYard"
    bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_active_scene=True,
                              export_animations=False)
finally:
    bpy.context.window.scene = previous
    bpy.data.scenes.remove(stage)
