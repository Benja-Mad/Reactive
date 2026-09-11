# Sector 08 — framing trials: angle × zoom

Twelve candidate framings rendered from the real game scene, each built *as* that framing rather
than nudged into it. Nothing here is applied: the shipped framing is still P30 at 85.8 m.

## What had to be fixed before any of this could be judged

Three things were written in absolute metres against the 85.8 m framing, so any closer camera
would have looked broken for a reason that had nothing to do with the camera:

- **The depth-of-field band** in `sector_08_world_pixel.gdshader` ramped from 71→93 m. At a 72 m
  framing the gameplay plane would sit at blur **3.23 of a maximum 3.25** — the whole yard on full
  blur. That is the mechanism behind "getting closer might ruin the depth": it would have, and it
  was the ramp's fault. The band is now stated as multiples of the framing distance
  (0.828–1.084 near, 1.096–1.340 far), which reproduces today's numbers exactly at 85.8 m and puts
  the gameplay plane at blur **0.82 in every variant**.
- **The foreground board** sat at a hardcoded 58 m — behind the yard at a 60 m framing. Now
  0.676 × framing distance, scaled to match.
- **The parallax dust layers** sat at 14/37/64 m. Now fractions of the framing distance, so they
  stay at the same screen depths.

## Reading the images

`labelled/contact_sheet.png` is all twelve in one grid, each captioned with its parameters and its
four numbers, laid out as the comparison: dolly across the top row, lens on the second, pitch on
the third, yaw on the fourth. `labelled/<id>_labelled.png` is each frame again at full size with
the same caption burned in.

The sheet is rendered into a SubViewport rather than screenshotted from the window: the OS clamps
a window to the display, which silently cropped the bottom row off the first attempt.

## The trials

`figure` = screen height of 1.6 m at the gameplay plane, i.e. apparent closeness.
`gradient` = a 1 m post at z = +10 against one at z = −22, in pixels. **1.0 is orthographic — no
perspective depth at all**; higher means the lens is telling you about distance.
`parallax` = screen travel of a near marker against a far one over a 12 m dolly. This is the depth
cue the translating camera actually generates in motion.
`yard` = fraction of the walkable box on screen at once.

| | pitch/yaw/dist/fov | figure | gradient | parallax | yard |
|---|---|---|---|---|---|
| **A0** *shipped* | 30 / 35 / 85.8 / 30 | 54.7 | 1.173 | 1.312 | 0.787 |
| A1 | 30 / 35 / **72** / 30 | 64.8 | **1.207** | **1.378** | 0.683 |
| A2 | 30 / 35 / **60** / 30 | 77.1 | **1.249** | **1.463** | 0.582 |
| A3 | 30 / 35 / 85.8 / **25** | 66.4 | 1.174 | 1.312 | 0.670 |
| A4 | 30 / 35 / 85.8 / **21** | 79.6 | 1.176 | 1.312 | 0.552 |
| B1 | **24** / 35 / 72 / 30 | 69.1 | **1.276** | **1.405** | 0.697 |
| B2 | **36** / 35 / 72 / 30 | 59.8 | 1.127 | 1.347 | 0.668 |
| B3 | **42** / 35 / 72 / 30 | 54.4 | **1.037** | 1.313 | 0.633 |
| C1 | 30 / **25** / 72 / 30 | 64.9 | 1.232 | 1.411 | 0.695 |
| C2 | 30 / **45** / 72 / 30 | 64.6 | 1.176 | 1.333 | 0.668 |
| D1 | 30 / 35 / 72 / **26** | 75.4 | 1.208 | 1.378 | 0.598 |
| E1 | **34** / 35 / **76** / **27** | 65.4 | 1.148 | 1.337 | 0.638 |

## What the numbers say

**Dollying in adds depth; it does not cost it.** 85.8 → 60 m raises the perspective gradient
1.173 → 1.249 and the parallax ratio 1.312 → 1.463. The worry was well-placed but aimed at the
wrong cause: what a dolly-in used to destroy was the *focus*, not the perspective.

**Narrowing the lens is a pure crop.** A3 and A4 leave the gradient at 1.174/1.176 and the
parallax ratio at 1.312 — identical to A0 to three decimals, because a focal change scales every
screen displacement equally and cancels in a ratio. All they buy is magnification, and A4 pays
for it with a quarter of the yard. `A4_p30_y35_d86_f21.png` is the flattest image in the set: the
pavement fills the frame and the buildings are cropped away, so it reads as an isometric map
rather than a lit box you are looking into.

**Pitch is the depth dial.** At 42° the gradient collapses to **1.037** — within 4% of an
orthographic projection, a flat top-down map. At 24° it is the highest in the set, 1.276, and
`B1_p24_y35_d72_f30.png` is the most cinematic frame here — but the walkable floor compresses into
a narrow band and the near railing intrudes, which costs gameplay legibility.

**Yaw barely touches depth** (1.232 at 25° against 1.176 at 45°). It is a composition choice.

## Recommendation

**A1: distance 85.8 → 72, everything else unchanged.** The figure grows 18%, the perspective
gradient and the parallax ratio both *improve* on the shipped framing, and 68% of the yard is
still in frame. One line in `DioramaArena.framing_distance`.

If that is still not close enough, **D1** (72 m with FOV 26) reaches 75.4 px, but at 60% of the
yard visible. **A2** (60 m) has the best depth cues of the set and the same 58% context cost;
`A2_p30_y35_d60_f30.png` shows what that looks like — mostly pavement, with the spine landmark
gone from frame.

Do not raise the pitch to get more floor on screen: it is the one dial that genuinely flattens the
scene.

## One thing to change with it

`follow_limit` is 9 m in world units, so a closer framing turns the same travel into more screen
movement. At 72 m the camera would swing about 19% further across the frame than it does now;
7.5 m keeps the screen-space travel identical.
