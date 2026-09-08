## Lookdev-only translation: preserve the complete approved camera basis and projection.
extends Node
const EXTENT := 1.2
var camera: Camera3D
var center: Transform3D
var offset := 0.0
var sweep := false
var phase := 0.0
var label: Label
## When play mode is active the follow rig is the single writer of the camera transform, and
## this offset is folded in as its lateral term instead of being applied here.
var rig: Node
func setup(owner_scene: Node) -> void:
 camera = owner_scene.gameplay_camera
 center = camera.global_transform
 label = Label.new()
 label.position = Vector2(740,12)
 label.add_theme_font_size_override("font_size",12)
 owner_scene.debug_layer.add_child(label)
 set_offset(0.0)
func set_offset(meters: float) -> void:
 offset = clampf(meters,-EXTENT,EXTENT)
 if rig != null and rig.enabled:
  rig._apply()
 else:
  camera.global_transform = Transform3D(center.basis,center.origin+center.basis.x*offset)
 label.text = "CAM F1 LEFT / F2 CENTER / F3 RIGHT / F4 SWEEP\nLateral %.2f m | P30 orientation locked" % offset
func _process(delta: float) -> void:
 if sweep:
  phase += delta*TAU/12.0
  set_offset(sin(phase)*EXTENT)
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode in [KEY_F1,KEY_F2,KEY_F3]:
   sweep = false
   set_offset({KEY_F1:-EXTENT,KEY_F2:0.0,KEY_F3:EXTENT}[event.keycode])
  elif event.keycode == KEY_F4:
   sweep = not sweep
   phase = asin(offset/EXTENT)
