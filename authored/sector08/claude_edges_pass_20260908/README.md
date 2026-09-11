# Lateral edges of the yard (2026-09-08)

## What was actually wrong

Not missing geometry in the sense of forgotten pieces. The authored yard is a **rhombus** — its
paving is laid on a rotated grid — while the collision floor is an **axis-aligned box** spanning
x −26..26 by z −26..14. The four corners of the walkable area therefore fall outside the paving
entirely: a player can stand there, held up by an invisible floor, with nothing underneath.

`topdown_before.png` shows it plainly: the rotated paved lot inside a larger walkable rectangle.

That also explains a false start. A first attempt tested coverage with world AABBs and reported
every cell as covered — of course it did, since a rotated slab's bounding box spans ground it does
not actually cover. Coverage is now tested by transforming each candidate point into each piece's
own space, which is the only way to ask the question correctly.

## What was added

`sector_08_perimeter.gd`, owned by `Sector08Runtime`. Everything is an **instance of authored
geometry** — it clones the meshes and materials the GLB already ships, so nothing is modelled by
hand and no material is invented:

| | source | count |
|---|---|---|
| corner paving | `Yard_Slab` | 15 |
| side fences | `ChainlinkPanel` | 26 |
| backdrop blocks | `Skyline_Block`, scaled down | 18 |
| crates | `Container` | 10 |

One `MultiMeshInstance3D` per family, so the whole perimeter is 4 draw calls. Draw calls 2435 →
2446. The backdrop stands outside the walkable footprint, so it needs no collision, and the
existing `BoundWest`/`BoundEast` already stop the player at the fence line.

The blocks are scaled to 0.30–0.72 of their authored height: they were authored as skyline towers
and at full size would lean over the play space rather than read as the next lot along.

## Why not just clamp the camera

Shrinking the rig's travel would have hidden the symptom by making the arena smaller. The edges
are now worth looking at instead.

## Still open

The dark band beyond z = 14 — past the yard's south bound, toward the camera — is outside the
walkable area and is still empty. Nothing stands there and the player cannot reach it, but it is
visible at the extreme left of frame.

All suites pass: arena integration 22/22, plus parallax, pipeline, art, pixel and play.
