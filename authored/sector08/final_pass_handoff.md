# Final implementation pass

Implemented directly in the existing Godot scene and scripts. No project launch, import, tests, screenshots, or validation was performed, as requested. Dream Loop was not invoked. The requested `assets-3d.md` guidance was read; external asset downloads were not authorized and no Fal credentials were present. Existing imported geometry, foliage atlases/normals, and the authored rain pavement texture were retained and refined.

## Visual changes

- Reframed the main game to 82 m / 29 degrees with a higher, slightly leftward focal point and a wider vertical follow dead zone.
- Repositioned the relay toward the rear-left composition; reduced its specular spill.
- Reduced amber power baselines and specular intensity through the existing reactive controller, preserving blackout transitions.
- Applied filmic tonemapping, restrained glow, brighter cool fill, softer shadows, and stronger foreground depth blur.
- Retuned the existing scanned pavement: broader wet/dry variation, less normal-map sparkle, dielectric reflection response, and a higher minimum roughness.
- Hid redundant opaque ground-stain cards, reduced moss cards, and retained foliage atlases with two-sided backlighting.
- Added curved shoulder armor, hip plates, brighter suit materials, a small character fill, subtle stride lean, larger role/health labels, and damage flashes.

## Play and UI changes

- Added mouse-directed aiming with a local floor reticle and replicated aim direction; F remains the fire/heal control. Keyboard-only movement-facing aim remains available until mouse movement.
- Tightened targeting assistance while mouse aiming, and resolved aim before firing.
- Added 100 ms coyote time and 140 ms jump buffering.
- Connected the existing position correction method to an authority-only unreliable ordered RPC; large discontinuities snap, smaller corrections interpolate.
- Return defeated players to their own spawn and immediately synchronize that position.
- Sentries now recheck line of sight at impact, so moving into cover during telegraphing prevents damage.
- Added a rate-limited support range hint and traveling variation in the healing beam.
- Added role-specific objective/control text, clearer code-add buttons, Enter to finish editing, Escape to dismiss, and automatic popup dismissal after inserting a program.

The orchestrator should perform all runtime, rendering, shader, and multiplayer validation. Visual improvements above describe implementation intent, not a measured screenshot match.
