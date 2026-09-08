# Sector 08 — lateral edges, the bright object, and the billboard band

Follow-up to `claude_edges_pass_20260908`, which closed the edges by a coverage test that was
wrong. Three reported defects, each traced to a cause and measured.

## 1. No floor at the left edge, and an incomplete fence

The previous pass laid **15** fill slabs and reported the walkable box covered. Its coverage test
asked whether a point fell inside each paving piece's **local bounding box**. Every slab in this
yard is rotated 53 degrees, so its bounding box covers ground the slab never touches — precisely
the ground that was missing.

Coverage is now rasterised from the paving **triangles**. Measured on the walkable box
(x −26..26, z −26..14, sampled at 1 m):

| | paved |
|---|---|
| authored only | **86.3 %** |
| after fill | **97.7 %** |

The fill is placed on the authored lattice, not on a grid of its own: orientation comes from a
slab's basis (yaw −53°) and the pitch from the spacing between slab origins (3.25 m), with the
reconstruction's residual reported in the build stats (max 0.29 m). It also runs **past** the
bounds — 13 m each side, 9 m toward the camera — because at full camera travel the frame shows
ground outside the walkable box.

A second wrong test had to be replaced along the way: cells were being skipped as "inside a
building" by **world AABB**, which excluded a 6 m run along the north edge where a player capsule
fits. Occupancy is now asked of the collision the yard already builds — the same authority that
decides where the player can stand. That took the fill from 114 to **181** slabs and the
reachable-edge ring from 80 % to **97.3 %** paved (the residual four samples are 1 m grid points
landing in 3 cm slab joints; each is reported with how many of its four neighbours are paved).

## 2. Bad collisions on the left — walking through the fence

The fence stood at x = ±25.4 while the collision bound's inner face is at x = ±26.0. The player's
capsule stops 0.4 m short of the bound, which put them **1 m past the fence they could see**.
Panels now stand on the bound face itself, the runs cover the full z extent of both sides, and a
run across the near edge closes the corners, skipping any panel within 2.6 m of an authored one so
it meets the existing fence rather than doubling it. 34 panels.

## 3. The bright white object on the right — identified, not changed

`blob_before.png`.

It is the **cyan spine lamp's specular** on the wet slab at about (-9.7, 0, -5.3). Isolated by
rendering variants: zeroing that one light's specular takes the region peak from 255 to 77, the
same as zeroing every light's specular in the scene, while the key, fill and yard lamps each move
it by nothing.

A sweep then showed there is no non-zero setting that survives: at specular 0.02 -- a seventh of
the approved 0.42 -- the highlight still clips. It is a 22-energy point source standing in for a
volumetric landmark, and the slab is authored PBR whose own roughness map reads as wet, so the
glint clips and the glow spreads it into a ball. The only lever is 0.0, which removes highlights
from the district's landmark light everywhere -- an art call on approved lighting, so the value is
left at 0.42 and this is reported rather than fixed.

`blob_after.png` in this folder shows the 0.0 variant, kept as reference for what that choice
looks like. It is not the committed state.

Two false starts worth recording. The first measurement blamed a puddle, because the patch it
sampled was centred 40 px away from the actual hotspot and so confirmed a different highlight.
And an attempt to attribute the mass at the far right by hiding perimeter layers one at a time was
meaningless: the district's emission is animated, so the *same* frame 20 frames later differs by
nearly 30 % in that region. Alternating a candidate on and off four times fixed that.

## 4. Black slabs beyond the fence

The backdrop blocks are drawn by a calibrated shader that receives its colour through
`instance uniform`, which a `MultiMeshInstance3D` clone does not inherit — so they rendered at the
shader's dark default. Clones now copy the source's instance shader parameters, and the lot beyond
the fence is built in three registers instead of one: a boundary wall (35 segments), containers
and pallet stacks standing on the new apron, and distant blocks with their authored window banks.
Nothing tall is placed within 62 m of the lens, which is what had put an east-side block in front
of the facade screen.

## 5. The billboard used too much of the frame

Measured band, top edge to the bottom of the frame: **16.1 % → 10.4 %** (12.4 % counting the
parapet cap). Its placement is also now verified rather than trusted — the ray cast at setup and
the projection read back disagreed by 40 px, which is what turned an intended 12 % band into 16 %.

## Cost

7 draw calls for the whole perimeter (one per family). Scene total 2446 → 2457. Build 208 ms.

## Validation

`validate_arena_integration` **28/28** — including four new edge checks: walkable area paved,
reachable ring paved, fence on the bound line, bounds stop the player at the fence. Plus
`pipeline`, `diorama`, `art`, `pixel`, `play`, `parallax` and the `lighting` report, all clean.

## Still open

The **blown-out specular** in section 3, if you want it gone: `light_specular = 0.0` on
`spine_cyan_light` is the only value that works.

The **`east_shed`** mass holds the right edge of the frame at **0.29** of the luminance of the
authored architecture beside it, and reads as a featureless black shape. Confirmed by alternating
its 37 meshes on and off (+5.3 mean in that region; the other candidates moved it by ~0.1). Its
material is authored PBR, so it is deliberately outside the calibrated shading path and the
`cs_architecture_fill` that keeps the skyline masses off black never reaches it. A dim omni in the
lot behind it was tried and measured: at 45 energy it moved that patch by 0.01, because the faces
in frame point away from anywhere a motivated source could stand. Fixing it means extending the
calibrated fill to authored-PBR backdrop masses, or re-aiming a directional — both changes to the
approved lighting rather than a patch to one building, so it is left for a decision.
