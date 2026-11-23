"""Draw the harbor enemies as flat ink-and-paint sprites. Run from the repository root."""
import math
from pathlib import Path

OUT = Path("materials/harbor_crew")
INK, SHADOW = "#141526", "#302c40"
STEEL, STEEL_HI = "#495467", "#9baeb6"
COPPER, RUST, GOLD, LIGHT = "#c37b43", "#764438", "#eab36c", "#ffe3ae"
TEAL, SEA = "#334f59", "#56767b"
RED, CORAL = "#a84649", "#ee7361"
EYE, GLOW = "#ffab42", "#fff5bd"

def path(d, fill, stroke=INK, width=1.4):
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>'

def line(d, color, width=1):
    return path(d,"none",color,width)

def oval(x,y,rx,ry,fill,stroke=INK,w=1):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{stroke}" stroke-width="{w}"/>'

def group(shapes, transform):
    return '<g transform="'+transform+'">'+''.join(shapes)+'</g>'

def diver(direction,phase):
    side=round(math.sin(direction*math.pi/4),2)
    rear=direction in (3,4,5)
    step=[0,1,0,-1][phase]
    legs=[]
    for sign in [-1,1]:
        legs.append(group([
            path("M-7 0 L5 -2 9 4 8 14 4 18 -6 17 -9 8Z",TEAL),
            path("M-7 3 L5 1 6 6 -5 9Z",COPPER),line("M-5 11l10-2",STEEL_HI),
            path("M-6 14 L6 13 6 18 11 21 10 25 -9 25 -11 22 -10 18Z",SHADOW),
            path("M-9 19 L0 17 4 19 3 21 -9 22Z",STEEL),line("M-8 23h16",STEEL_HI)
        ],f"translate({47+sign*10+side*2} {64+step*sign*2})"))
    body=[path("M30 39 L40 34 56 35 65 43 64 58 62 68 55 72 44 69 32 72 28 62Z",TEAL),
          path("M33 40 L39 38 42 50 38 58 30 56Z",SEA),path("M49 38 L58 39 64 45 61 53 53 54 50 50Z",SEA),
          path("M32 40 L37 38 44 57 56 60 56 66 40 62Z",RUST),line("M36 40l7 16",GOLD,1.5),
          path("M29 59 Q45 65 64 57 L64 64 Q47 72 30 65Z",SHADOW),
          path("M41 61l10 1-1 6-10-1Z",COPPER),path("M44 63h5v2h-5Z",INK,"none"),
          path("M28 60l9 2-1 9-8-2Z",RUST),line("M30 63l5 1",GOLD)]
    for sign in [-1,1]:
        body.append(group([path("M-6 -3 L4 -5 9 1 8 13 4 18 -5 17 -8 9Z",SEA),
            path("M-8 -1 Q-7 -9 2 -8 L8 -4 10 1 5 4 -8 3Z",COPPER),line("M-5 -4l7-2 4 1",LIGHT,1.4),
            path("M-6 11L7 10 7 16-5 18Z",RUST),line("M-4 13l9-1",GOLD),
            path("M-6 17 L5 15 8 20 6 27 0 28 -5 25 -8 21Z",SHADOW),
            line("M1 20l-1 5m4-6-1 5",STEEL)],f"translate({47+sign*19} {44-sign*step*2}) rotate({sign*7})"))
    head=[path("M28 31 Q24 20 31 12 L36 8 48 5 58 8 64 15 66 26 62 35 57 40 37 41Z",RUST),
          path("M29 26 Q28 12 39 9 Q51 4 59 12 L62 18 56 17 49 14 37 17Z",COPPER,"none"),
          line("M32 18q3-8 14-9",LIGHT,2),
          path("M27 31 Q40 38 63 31 L65 36 Q48 46 29 39Z",COPPER),line("M30 35q18 6 32-1",GOLD,2)]
    # Separate enamel, canvas and brass at the actual in-game pixel size.
    head.extend([line("M32 17l2-3m1-1 4-2m8-2 4 1",LIGHT,1.2),
                 line("M57 13l4 4 2 5",RUST,2),line("M32 32l4 2m5 1 5 .5",LIGHT,1.2)])
    body.extend([path("M35 50l6 4-5 1-5-2Zm19 4 6-4-1 5-4 2Z",SHADOW,"none"),
                 line("M33 56l3 1m15-1 5-2",STEEL_HI),
                 oval(52,47,4.2,4.4,COPPER),oval(52,47,2.9,3,LIGHT),
                 line("M51 48l3-3",INK,1.1)])
    if not rear:
        vx=46+side*9
        head.append(group([oval(0,0,13.6,11.6,COPPER),oval(0,0,10.8,9,SHADOW),oval(0,0,7.8,6.5,"#a34632"),
                    path("M-6 0l4-4 6 1 3 2-3 4-6 1Z",EYE),path("M-2 -2l4-1 2 2-4 2Z",GLOW,"none"),
                    line("M-8 -7l3-2m10 16 2-2",LIGHT,1.6)],f"translate({vx} 25) scale({1-abs(side)*.21} 1)"))
        head.append(group([oval(0,0,4.3,5.3,RUST),oval(0,0,2.8,3.7,GOLD),
                           line("M-2 -1l4 2m-2-4v6",RUST,1.3)],f"translate({46-side*14} 23)"))
        head.append(line(f"M{vx-12} 28 Q{vx-24} 28 26 43 Q25 58 32 55 L34 49",INK,4))
        head.append(line(f"M{vx-12} 28 Q{vx-24} 28 26 43 Q25 58 32 55",STEEL_HI,1))
    else:
        head.extend([line("M31 24q12-13 29-10",GOLD,1.8),oval(49+side*7,28,5,5,STEEL)])
        for x in [38,51]:
            body.append(path(f"M{x} 36q5-4 9 1v22q-4 6-9 1Z",STEEL))
            body.append(line(f"M{x+2} 40v13m-2-3h9",STEEL_HI))
    return ''.join(legs)+group(body+head,f"translate(0 {abs(step)*-1})")

def crab(direction,phase):
    # Pivot legs in alternate tripods. Outer claws open around an inset cutting edge.
    angle=direction*45
    step=[0,1,0,-1][phase]
    parts=[]
    for s in [-1,1]:
        limb=[]
        for j in range(3):
            y=41+j*8;k=(1 if j%2 else -1)*step
            limb.append(path(f"M-9 {y} L-23 {y-9} -30 {y-8} -36 {y+3+k*2} -41 {y+10+k*2} -39 {y+11+k*2} -32 {y+6} -26 {y-3} -16 {y+4}Z",RUST))
            limb.append(line(f"M-19 {y-3}l-7-3-6 7",CORAL,1.8));limb.append(oval(-26,y-6,2.4,2.5,GOLD))
        limb.extend([path("M-11 57 L-19 55 -25 61 -29 66 -24 70 -16 67Z",STEEL),
         path("M-22 62 Q-36 59 -39 68 Q-42 78 -31 85 L-23 88 -29 77 -27 73 -21 76 -16 83 -15 76 Q-13 68 -22 62Z",RED),
         path("M-37 68 Q-34 61 -25 64 L-20 67 -25 69 -33 72Z",CORAL,"none"),
         path("M-32 80l9 8-4-8Z",LIGHT),path("M-20 77l4 6 1-7Z",LIGHT)])
        parts.append(group(limb,f"translate(48 0) scale({s} 1)"))
    parts.extend([path("M27 40 L25 34 33 36 36 30 41 33 47 28 51 32 59 30 61 36 69 34 66 42 71 47 66 58 56 65 42 67 29 59 24 48Z",RUST),
     path("M26 44 L35 38 43 36 49 31 58 35 65 40 68 48 59 53 49 55 37 51Z",RED),
     path("M29 43l8-5 7-1 3-3 7 1-6 5-11 1-6 5Z",CORAL,"none"),
     path("M39 53l9 4 11-4-4 8-9 2Z",SHADOW),
     path("M32 43l7 2-2 3-6-2Zm23-2 7-3 2 3-8 4Z",LIGHT,"none"),
     line("M44 39l4 6 5-7",RUST,2)])
    for x in (31,38,57,63):
        parts.append(oval(x,45+(x%3),1.3,1.1,GOLD,INK,.65))
    parts.extend([line("M33 52l6 3m17-1 6-3",SHADOW,1.7),
                  path("M43 35l5-3 5 2-4 3Z",GOLD,INK,.8),
                  line("M29 49l5 2m27-3 4-2",CORAL,1.2)])
    for x in (35,59):
        parts.extend([path(f"M{x-2} 56l-2 8h6l1-9Z",STEEL),oval(x,65,4,4,SHADOW),oval(x,66,2.6,2,EYE),oval(x-1,65,1,1,GLOW,"none")])
    return group(parts,f"translate(0 15) translate(48 48) scale(.82 .67) rotate({-angle}) translate(-48 -48)")

def atlas(name,draw):
    cells=[]
    for phase in range(4):
        for direction in range(8):
            cells.append(group([draw(direction,phase)],f"translate({direction*96} {phase*96})"))
    (OUT/(name+".svg")).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="768" height="384">'+''.join(cells)+'</svg>')

if __name__ == "__main__":
    atlas("diver",diver)
    atlas("crab",crab)
