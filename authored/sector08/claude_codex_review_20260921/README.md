# Review of the Codex passes, and what was done with them

Six passes arrived as an uncommitted working tree with handoff notes under `authored/sector08/`.
Every note states it ran no project, no tests, no imports and no validation. The notes also
disagree with each other — two of them say the camera was untouched while `main_scene.tscn`
overrode the framing, the follow dead zone and the follow limit — so the diff was the source of
truth here, not the notes.

## What the existing suites caught

| | before | after |
|---|---|---|
| `validate_arena_integration` | **FAILED** 2/30 | **PASS 32/32** |
| `validate_sector08_art` / `pixel` | assertion at `art.gd:35` | PASS |
| pipeline · diorama · play · parallax | PASS | PASS |

The two integration failures were `camera_followed` and `billboard_closes_edge_without_dominating`.
The art assertion is the guard that the art pass must not alter the authored PBR scalars.

## Reverted — decisions that had measurements behind them

- **Framing.** `main_scene.tscn` overrode the chosen 24° / 60 m with 29° / 82 m and moved the
  composition target. Measured, that override gave a 59.9 px figure against 82.4, a perspective
  gradient of 1.197 against 1.335, and put 70% of the yard in frame when the point of the choice
  was 59%. The overrides are gone; the arena's own exported framing stands.
- **The follow rig.** Dead zone 0.10/0.13 → 0.30/0.32, limit 6.3/2.1 → 3.5/1.0, speed 3.2 → 1.8.
  Measured at that framing, the player had to walk **14.9 m sideways or 17.6 m in depth** before
  the camera moved at all, and `camera_translated_m` came back **0.0**. The camera was static, and
  a static camera also cancels the depth the parallax layers exist to produce.
- **The foreground board.** `TOP_EDGE_UV` 0.935 → 1.045 put its top edge below the bottom of the
  frame: band **−0.045**, entirely invisible, with its magenta spill still lighting the yard.
- **The pixel filter.** `presentation_mode` 1 → 0 turned off the world pixelation the presentation
  and its validator are built around.
- **The players' sprites.** `configure_player_presentation` was rewritten to hide the
  AnimatedSprite3D and add a procedural mesh operative. The pixel-art figure is the game's
  identity; `operative_visual.gd` is kept, marked unused, in case that direction is revisited.
- **Authored PBR.** `_apply_art_materials` forced `roughness = 0.24`, `metallic_specular = 0.8`
  and `normal_scale = 1.25` onto every `Yard_Slab` and `Ground_Patch`, overriding the baked
  roughness maps. The wet look now comes from the art pass's own shader, which is where it belongs.
- **Environment.** The lookdev's approved fog, glow and SSR values are restored, leaving
  `yard_polish` as the single place the night-rain pass overrides them.

## Kept, and repaired

The wet-pavement pass, the rain, the reflection probe, the sentries and the combat feedback all
stay. What they were missing:

- **The lit air motes were switched off** (`particles.visible = false`). Rain is falling water;
  the motes are suspended dust that only shows inside a beam. Both are back.
- **The light shafts had lost their medium.** Volumetric fog density had gone to 0.0020, a sixth
  of the approved value, which all but extinguished the beams the fixtures are aimed through.
  Raised to 0.0090; the thin ground haze stays.
- **The perimeter did not get the wet material.** `yard_polish` iterates `MeshInstance3D`, and the
  ground that closes the lateral edges is a `MultiMeshInstance3D`, so the authored yard went wet
  while the ground covering the frame edges stayed dry — with the seam landing exactly where the
  fill was added to hide one. It now takes the same material.
- **Pools read as spilled pale paint.** The shader added a flat `sky * 0.45` straight into albedo,
  brightest where water should be darkest. Reduced to 0.08; the sky now reaches the water through
  the low roughness, as a reflection.
- **Floor lettering was illegible.** Flat `Label3D` captions read from a camera pitched 24° came
  out smeared across the slabs, in the play lane. Disabled; the painted strips and the drain carry
  the same identity without asking the frame to read text at a grazing angle.
- **The relay sat centre frame** at (−8.1, −9), competing with the players it should sit behind.
  Moved to (−15.5, −15) and its emission dropped from 3.8 to 1.5.

## Bugs fixed

1. **A mesh, a material and a tween allocated every physics tick.** `fire_attack` called
   `combat_fx.beam()` each frame while travelling — roughly sixty throwaway nodes a second per
   projectile, each with its own `StandardMaterial3D`. The bolt now owns one stretched trail.
2. **The lookdev demo loop was running in the match.** `auto_demo` defaults to true and nothing
   turned it off in game, so the district cycled waves and blackouts on a timer while people were
   fighting. Off in game; gameplay will drive those states.
3. **Two players of the same role shared a spawn point** — the slot was keyed purely on role.
4. **One mouse movement disabled keyboard facing permanently.** Moving on the keyboard hands it
   back.
5. **Support spent its cooldown healing an ally already at full health.**
6. **The health bar overwrote the player's name.** Both now fit on the label.
7. **The foreground board lagged a frame behind the camera.** Its vertical tracking ran before the
   rig moved the camera; a later `process_priority` makes the band exact — swing 0.0.

## Corrections to my own first report

I flagged that a defeated client would respawn at the world origin, because `respawn_position` is
captured in `_ready()`. That was wrong: `MultiplayerSpawner` runs the custom spawn function on
every peer with the replicated seat data, so the position is set before the body enters the tree.
Measured anchors come back as the real spawn points, and the integration suite now asserts it.

## Kept from Codex without change

The debug-key gate (`_unhandled_input` returns unless `lookdev_tools`) — those keys were live in
the shipped build. `_sync` becoming a real RPC; it had been a local call that replicated nothing.
Coyote time, jump buffering, the movement ramps. The sentries' host-authoritative model. And in
the depth shader, requiring distance as well as height before softening architecture.

## Not measured

The cost of SSR at 128 steps plus a reflection probe plus four fog volumes plus rain, on a scene
of 2990 meshes. It runs, but no frame-time comparison was taken.

---

# Second pass: the diorama look, and the cost

## The diorama filter was barely acting, and the pixel grid was invisible

Both were switched on — `pixel_presentation.get_report()` returned SOFT PIXEL and `diorama: true`
— which is why the first pass called them restored. Measured, they were not doing much. The
number is how much detail the world filter removes from a screen band, normalised by that band's
own detail so a magnified foreground cannot pass for focus:

| band | before | after |
|---|---|---|
| far architecture | 0.253 | **0.574** |
| gameplay plane | 0.102 | 0.110 |
| near foreground | 0.159 | 0.175 |

The far field was losing a quarter of its detail against a tenth on the play plane: a 2.5×
separation, which is a haze, not a depth of field. It is now 5.2×. The cause was Codex's rewrite
of the ramps — widened to 0.62–1.30 of the focus distance and then *blended* in at a fraction of
the mip instead of sampled — which the first pass kept. The approved bands are back
(0.828–1.084 near, 1.096–1.340 far, blur ×3.25, sampled directly), keeping Codex's one real
improvement: the architecture term is gated by distance as well as height, so a tall operative
standing in the yard is no longer softened for being tall.

The pixel lattice was sampling 1280×720 into a 1920×1080 frame: 1.5 screen pixels per world
pixel, non-integer and invisible. `presentation_mode` is now 2 — 960×540, a clean 2:1.

And the first video hid both: it was captured at 1600×900 and rescaled to 1280 on encode, which
destroys the lattice. It is now captured and encoded at 1920×1080 with no scaling.

## Cost

Two traps before a number came out.

Frame period is useless here: the compositor pins every configuration to exactly 60.0 fps and
16.67 ms with p95 == p50, and `window_set_vsync_mode(DISABLED)` does not lift it on this platform.
The viewport's own GPU timer reads 0.000 ms under Metal, and render-CPU time came back *lower*
for the heavier configuration — noise. So the first comparison in this file, "SSR costs about
1 ms", was measuring the vsync wait and is withdrawn.

Rendering the 3D at 2× — four times the pixels — pushes the frame past the cap and separates them:

| | frame ms p50 |
|---|---|
| shipped, SSR at 128 steps | **47.62** |
| SSR off | **6.90** |
| whole night-rain pass off | 6.90 |

Screen-space reflections were about 85% of the frame, and everything else in the pass — the rain,
the four fog volumes, the reflection probe, the wet shader — measured free, to the decimal. On a
night yard whose far field sits under a heavy depth blur anyway, 128 steps is not a trade worth
making. At **24 steps the frame is 6.90 ms**, identical to having SSR off, and the wet ground
still reflects.

At native resolution the game holds 60 fps in every configuration with no frame missing the
deadline across 240 sampled frames, at 3128 draw calls.

## The east edge fixed itself

The `east_shed` mass that held the right of the frame at **0.29** of the luminance of the
architecture beside it now measures **0.745**. Restoring the far depth band did what a dim omni in
the lot behind it could not: the blur and the haze lift it off black. Nothing was added for it.

## The exit-time leaks are the engine's, not ours

`1 shaders of type ParticlesShaderRD were never freed`, one leaked Shader RID and seven leaked
Texture RIDs print on every run. Freeing all three particle systems thirty frames before quitting
leaves all three messages exactly as they were, so they are the rendering server's own shutdown
accounting. `yard_polish` was given an `_exit_tree` anyway — it is the only one of the three that
lacked one, and deterministic release is right regardless of what the exit prints.

---

# Third pass: flatness, the magenta, and the windows

## "It feels flat" — two hypotheses tested and rejected before the real one

Plane separation said nothing was wrong: 0.134–0.148 across every fog and glow variant. Lowering
`ambient_light_energy` from 0.34 to 0.17 moved the image by **nothing** (p05 0.055 → 0.055,
stddev 0.1065 → 0.1071), so the usual suspect was not the cause either.

The number that did stand out was **warm chroma at 4–5%**, with 85% of the coloured weight inside
one 30° blue-cyan wedge. Codex had halved the sodium — the streetlight 38 → 16, the central amber
12 → 5 — while the new wet floor returned cyan across the whole yard. The two-temperature
opposition this district is built on had gone, and a blue night city with no counter-temperature
is the most generic image in the genre. Restoring the warm family, plus the glow it needed to
read as light:

| | before | after |
|---|---|---|
| warm chroma | 5.0% | **8.1%** |
| luma range p05–p95 | 0.316 | **0.373** |
| luma stddev | 0.1063 | **0.1282** |
| plane separation | 0.143 | **0.177** |

## The magenta was unreachable, not dim

`CorruptionMagenta` sat at **(−22.3, 10.6, −5.9) with a 9 m radius** — a sphere floating 10.6 m up
at the far edge. `reaches_ground: false`, and it unprojects to pixel (201, **1**), the top row of
the frame. Raising its energy to 6.0 changed the image by nothing, which is what pointed at
placement. It now sits at bay height with the reach to spill onto the slabs, and its energy is
driven by the district's `corruption` value with a floor, so the hue is in the palette at rest and
surges when the state calls for it.

## The windows were the only thing moving, on a loop

`wave_phase = fmod(effect_time * wave_speed, 1.0)` at speed 0.12 repeats every **8.3 seconds**,
identically on every building. That alone would be fine — it is the district's signal — except
that `occupancy` was *constant in time*: a window was lit or dark forever. With nothing else
changing, the 8.3 s sweep was the entire behaviour of the city, and it read as a loop.

Each cell now keeps its own hours: a slow schedule on an incommensurate period between 26 and 97
seconds, seeded per cell, crossfading rather than popping. Nothing switches in step with anything
else and the pattern does not come back around visibly.

## A measurement mistake worth recording

Six sweeps of the sodium's energy, specular and beam fog all returned a bit-identical clipped
pixel count, which is not physically possible. The test required **all three channels** ≥ 253, and
a warm blown highlight has a low blue channel — so it had been counting the neutral rain streaks
the whole time, which of course do not respond to a lamp. Re-measured per channel.

With the honest metric: the pool under the streetlight clips at every energy that keeps the yard
warm, and energy, specular, beam fog and pool roughness were each swept without clearing it. It is
left as it is. Unlike the blown spot on the dry slabs, this one sits directly under a visible
fixture with a visible beam, so it reads as the lamp rather than as an object nobody can identify.

Pool roughness did move from a perfect-mirror 0.085 to 0.19 on the way, which is the more honest
surface for water under rain and spreads the reflection into something readable.
