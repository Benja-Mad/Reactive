# Cinematic dust layers — parallax in depth (2026-09-08)

Three optical layers at fixed distances in front of the approved framing — 14 m, 37 m and 64 m
against a scene focused around 88 m — anchored in the world and never parented to or moved with
the camera, so the shift comes from the rig genuinely translating.

| layer | depth | count | shift over a 12 m dolly |
|---|---|---|---|
| LensMotes | 14 m | 22 | **2530 px** |
| ForegroundDrift | 37 m | 52 | 889 px |
| MiddleDust | 64 m | 90 | 514 px |
| gameplay plane | ~88 m | — | 372 px |
| architecture | far | — | 316 px |

164 particles total, 3 draw calls, 1 shared shader, no lights, no shadow casters.
Draw calls 2430 -> 2433.

## What each revision got wrong

**First version** — too faint to read as anything.

**Second** — overshot into 0.55 m discs at 0.30 opacity that filled the frame and buried the
combat.

**Third** — three real defects. Motes were cut off square, because the shape was divided by the
per-mote aspect without renormalising the other axis. They were laid over the scene rather than
in it: `depth_test_disabled` and `fog_disabled` meant a mote at 64 m drew over buildings standing
in front of it. And every mote was identical.

**Fourth** — overcorrected the third. Fixing "no variation" produced three different shape
characters, free rotation, aspect from 0.55 to 2.6, turbulence up to 0.75 influence, ±7 rad/s
spin and 0.85 emission randomness. That is noise, not dust. It also had the near layer wrong in
principle: a *dim* speck 14 m from the lens does not render as an aperture disc with a bright
rim — that only happens to a bright point source — it renders as a large, very soft, low-contrast
smudge.

## Where it landed

One shape family with a `softness` parameter instead of three characters, and much less stray
around it (`variation` 0.85 -> 0.30). Motion calmed across the board:

| | fourth | now |
|---|---|---|
| emission spread | 34° | 9° |
| turbulence influence (max) | 0.75 | 0.22 |
| turbulence wavelength | 2.4 | 0.7 |
| angular velocity | ±7.0 | ±0.5 |
| emission randomness | 0.85 | 0.25 |
| lifetimes | 26 / 32 / 38 s | 62 / 74 / 86 s |
| counts | 52 / 100 / 150 | 22 / 52 / 90 |

`dust_drift_static_camera.mp4` is 4 s with the camera held still, which is the only way to judge
the motes' own motion with no dolly to hide behind: one near mote crosses slowly, the fine ones
barely move. Measured frame-to-frame change over that sequence is 1.34 mean / 6.88 max on a scale
where a genuinely moving camera reads 5.49.

## Integrity

`proof_occlusion.png` is the 64 m layer cranked to 900 particles: the red building and the central
structures carry no motes at all, because they stand in front of that plane. The layers are depth
tested and fog affected, and skip depth *writing* only, as any transparent sprite does.

All suites pass: arena integration 22/22, plus parallax, diorama, pipeline, art, pixel and play.
Basis and FOV 30 preserved throughout. They dim on the same power/blackout supply curve as every
other emitter here.

Evidence: `still_center.png`, `dolly_left.png`, `dolly_right.png`, `sweep_strip.png`,
`drift_strip.png`, `dust_parallax_sweep.mp4`, `dust_drift_static_camera.mp4`,
`proof_occlusion.png`, `dust.json`.

---

# Light scattering on the scene motes (2026-09-08, later)

The scene dust (`sector_08_particles.gd`, separate from the optical layers above) did not brighten
when it crossed a beam. Isolating its own contribution — render the frame with the motes and
without, and subtract — showed it was doing the opposite of what dust does:

| region | before | after |
|---|---|---|
| sodium beam | 0.235 | **1.051** |
| beam pool | 0.334 | 0.482 |
| open shadow | 0.510 | **0.025** |
| beam / shadow | **0.46x** (inverted) | **42x** |

## Why it was inverted

Two causes, both structural rather than a matter of tuning.

**Alpha blending with a fixed alpha.** A mote was a constant grey wash at 0.55 alpha. Over a dark
wall it *adds* brightness; inside a bright beam it is darker than what it covers, so it
*subtracts*. Additive blending fixes this by construction: an unlit mote adds nothing and is
invisible, a lit one glows.

**Diffuse N·L on a camera-facing billboard.** The quad's normal points at the lens, so N·L barely
changes as the mote crosses a cone — the lighting was nearly constant by geometry. Scattering is
now computed in a `light()` function with a Henyey-Greenstein phase term.

## Two things measurement caught that intuition got wrong

The phase function was first set to a strong forward lobe (g = 0.62), which is right for looking
towards a source through dust. This camera looks down at 30° at lamps that also point down, so the
geometry is mostly *back* scattering — the strong lobe made motes darkest exactly where they should
be brightest. g is now 0.22 and the isotropic term carries the response; being inside the cone at
all is the dominant cue.

And the densest warm field was centred at (2, 2.6, 3), the front of the yard, while the floodlight
beam runs from (-3.65, 4.6, -22) down to about (2.35, 0.3, -10). The thickest dust was in the one
place no lamp could pick it out. Moving it onto the beam changed the ratio more than every
parameter tweak combined.

## Honest limits

- The quads are ~2-3 px. Physically sized dust is about 0.7 px at this distance, which additive
  blending cannot resolve at all, so they are sized to read rather than to measure.
- Only three fields. The cyan spine and the magenta facade get whatever the broad drift field
  happens to carry; neither has dust sited on it the way the floodlight now does.
- `open_shadow` at 0.025 means motes are close to absolutely invisible outside light. Real dust
  keeps a faint ambient presence; `floor_visibility` is the knob if that reads as too absolute.

Shadow reception is on, so a mote drifting behind the fence goes dark inside the cone rather than
glowing through it.

All suites still pass: arena integration 22/22, parallax, diorama, pipeline, art, pixel, play.
Draw calls unchanged at 2433.

## Dust on the spine and the facade screen (2026-09-08, later still)

The cyan shaft and the magenta facade screen had no dust sited on them, so the district's landmark
light and its only magenta source had nothing to pick out. Two fields added, placed from the
lights' measured positions rather than by eye:

| field | sited on | position |
|---|---|---|
| SpineHalo | cyan shaft, which descends (-19, 19.6, -13) -> (-6, -1.5, 2) | (-12, 7.5, -5), extents (4.5, 8.5, 5) |
| FacadeHaze | screen spill at (18.7, 16.9, 24.8), 17 m reach | (18.5, 15, 24), extents (6.5, 5, 4) |

The facade field was first spread across the whole board and barely registered: the spill reaches
only 17 m and attenuates fast, so most motes sat where nothing lit them. Tightening it onto the
spill roughly quintupled the contribution.

| region | contribution | over open shadow |
|---|---|---|
| sodium beam | 1.147 | 52x |
| spine shaft | 0.653 | 30x |
| facade screen | 1.030 | 47x |
| open shadow | 0.022 | — |

Five fields now, five draw calls, one shared shader.

## Where to tune this

`sector_08_particles.gd` holds a `SCATTERING` dictionary — `gain`, `anisotropy`,
`ambient_response`, `floor_visibility`. The shader declares defaults for the same uniforms, but
the dictionary is applied on top at setup, so **editing the shader alone does nothing**. The
dictionary is the one place.
