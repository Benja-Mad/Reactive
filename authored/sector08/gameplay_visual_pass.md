# Cooperative yard pass

Implemented directly in the gameplay scene and its shared arena resources.

- Native resolution world presentation, narrower foreground focus falloff, reduced global haze and bloom, screen-space reflections, and wet authored ground materials retaining their texture and normal maps.
- Lower foreground billboard, inward player spawns, opaque-silhouette-based player sizing, animated role rings, colored health labels and local light spill.
- Camera-relative damage firing on F with a cooldown, independent world-space projectiles, swept collision and luminous impacts. The existing MultiplayerSpawner remains responsible for projectile replication.
- Support F / heal() requests host-resolved healing with sender checks, a host cooldown and a replicated cyan link.
- Two host-controlled sentries using the existing animated atlas. Ground telegraphs allow evasion, hits reduce player health, defeated sentries reboot after eight seconds, and depleted players return to the yard.
- Responsive programming controls, role-specific snippets and control hints. Text entry suppresses movement and jump; look-development shortcuts are gated out of gameplay.

No project execution, testing, screenshot capture or validation was performed, per the requested orchestrator handoff. Visual matching, runtime behavior and multiplayer verification remain for that validation stage.

The supplied 3D asset guidance was read directly. Existing authored architecture, PBR textures, normal maps and character atlases were reused. No external asset download was authorized and no Fal credential was available in the process environment. New geometry is limited to functional energy rings and beam effects.
