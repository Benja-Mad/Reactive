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
