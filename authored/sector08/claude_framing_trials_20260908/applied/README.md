# Applied: pitch 24°, 60 m (trial F7)

Chosen for the diorama read. The numbers against the old P30 at 85.8 m:

| | before | after |
|---|---|---|
| figure (1.6 m, in px) | 54.7 | **82.4** |
| perspective gradient | 1.173 | **1.335** |
| parallax ratio | 1.312 | **1.498** |
| walkable box in frame | 79% | **59%** |
| floor legibility | 0.502 | **0.429** |

`follow_limit` went 9 × 3 m → 6.3 × 2.1 m, scaled by 60 / 85.8, so the follow covers the same
fraction of the frame as before rather than 43% more.

## What to watch in play

**Floor legibility 0.43.** A metre of forward movement is now worth 0.43 of a metre sideways on
screen, against 0.50 before. If depth position ever becomes hard to read — telling whether
something is in front of you or behind you — that is the number responsible, and pitch 27 puts it
back to 0.47 for a small cost in perspective (trial F4).

## Found while validating, not introduced by this

The foreground board is world geometry placed in screen space, so the rig's vertical travel slides
it across the frame:

| rig | band |
|---|---|
| camera lowered 2.1 m | 23.8% of frame height |
| composed | **7.5%** |
| camera raised 2.1 m | off frame entirely |

A 32% swing. It closes the bottom of the shot only near the middle of its vertical travel; at the
top of the travel it leaves the frame and the bottom edge opens up again. This was slightly worse
at the old framing (34.7%, from 3 m of travel against a board at 58 m), so it is pre-existing, and
it is now measured by `validate_arena_integration`, which asserts the composed band stays between
3% and 14%.

Two ways out, when it is worth doing: shorten the rig's vertical travel, or let the board follow
the camera's vertical offset only — that keeps all the lateral parallax, which is the parallax that
matters, while letting it do its compositional job at every height.

## Validation

`validate_arena_integration` **29/29**, including the new billboard band check, plus `pipeline`,
`diorama`, `art`, `pixel`, `play`, `parallax` and the `lighting` report.

One stale check had to be repaired: `validate_sector08_pipeline` pinned the camera to the literal
P30 world position, so retuning the framing broke it with nothing actually wrong. It now derives
the expected position from the arena's own declared framing, which is what the check was for.
