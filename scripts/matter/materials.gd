## Small data catalog: material transitions are explicit, multi-step recipes are not.
extends RefCounted
const MATERIALS := {
	"water": {"spawnable": true, "initial_states": ["wet"], "properties": ["reshapeable", "coatable"], "color": Color(0.12, 0.22, 0.25), "integrity": 20.0},
	"ice": {"spawnable": false, "initial_states": ["frozen"], "properties": ["solid", "breakable", "brittle", "coatable"], "color": Color(0.65, 0.76, 0.77), "integrity": 20.0},
	# Steam keeps the water's identity, so condensing gives the same construct back. It hides
	# whatever is behind it from line of sight, drifts when pushed, and is never solid.
	"steam": {"spawnable": false, "initial_states": ["vapor"], "properties": ["obscuring", "movable", "coatable"], "color": Color(0.62, 0.68, 0.7), "integrity": 20.0},
	# Burning fuel, taken from the yard's drums: it lights what it touches, eats its own fuel and is
	# gone, and the air in it carries a charge.
	"fire": {"spawnable": true, "initial_states": ["burning"], "properties": ["coatable", "conductive"], "color": Color(0.9, 0.42, 0.14), "integrity": 20.0},
	# Current drawn from a transformer: it looks for ground, jumping to the nearest body, and is
	# spent one discharge at a time.
	"current": {"spawnable": true, "initial_states": ["live"], "properties": ["coatable", "conductive"], "color": Color(0.96, 0.9, 0.42), "integrity": 20.0},
	# Scrap off a wreck or a junk heap: heavy, metal, it conducts, holds heat and breaks into shrapnel.
	"scrap": {"spawnable": true, "initial_states": [], "properties": ["solid", "breakable", "brittle", "coatable", "conductive"], "color": Color(0.32, 0.28, 0.24), "integrity": 30.0},
}
## Where each routine can draw from: the substance, and the materials of it that can be taken.
const SUBSTANCES := ["water", "fire", "current", "scrap"]
static func substance_of(material: String) -> String:
	return "water" if material in ["water", "ice", "steam"] else material
## Two directions around the same phase cycle: ice <- water <- steam, and back.
const TRANSITIONS := {
	"freeze": {"water": "ice", "steam": "water"},
	"heat": {"ice": "water", "water": "steam"},
}
## The vocabulary a routine, a manual key or a reaction may use. The host re-checks all of it.
const STEPS := ["raise", "wall", "freeze", "heat", "coat", "impact", "push", "drop"]
const TRIGGERS := ["broken", "hit", "transformed", "pulsed"]
const REACTIONS := ["push", "command", "freeze", "heat"]
## A conduit carries a reaction's pulse to one other construct of the same owner.
const LINK_RANGE := 14.0
const PULSE_SPEED := 9.0
const COATINGS := {"nanites": {"requires": "coatable", "commands": ["detonate"], "radius": 4.0, "damage": 18.0}}
## Nanites suspended in a cloud burn as one front: the same energy over a wider sphere.
const SUSPENDED_BLAST_RADIUS := 1.6
## Shape each phase settles into, when the phase has one of its own.
const STEAM_SIZE := Vector3(4.4, 2.6, 3.4)
const PATCH_SIZE := Vector3(4, 0.12, 3)
const STEAM_LIFETIME := 7.0
## Raise changes elevation; wall explicitly changes shape. A 1.4 m orb holds the patch's volume.
const ORB_SIZE := Vector3(1.4, 1.4, 1.4)
const HOLD_HEIGHT := 0.55
const WALL_SIZE := Vector3(4, 1.8, 0.2)
const FIELD_ACCEL := 36.0
const FIELD_SPEED := 7.0
## Standing water is counted in draughts: one routine takes one, and a puddle's size follows what
## it holds. Water is never made, only moved: a routine draws it from the yard and, spent, it
## lands back on the floor as a puddle.
const MAX_VOLUME := 3.0
## A drum's fire, a transformer's terminals: small sources that are not puddles on the floor.
const SOURCE_SIZE := Vector3(1.4, 1.0, 1.4)
## How long drawn fire burns before its fuel is gone, and how much longer stoking keeps it.
const FIRE_LIFETIME := 7.0
const STOKE := 4.0
## Discharges a draught of current holds.
const CURRENT_CHARGE := 2
const MAX_CURRENT := 3

static func puddle_size(volume: float) -> Vector3:
	var spread: float = sqrt(clampf(volume, 0.35, MAX_VOLUME))
	return Vector3(PATCH_SIZE.x * spread, PATCH_SIZE.y, PATCH_SIZE.z * spread)

## Whether a routine may draw from this record: liquid water lying still on the floor, owned by
## the yard or left by the crew, and nothing a player has set working: no routine taking shape, no
## reaction armed, no charge, field or coat on it.
## Fire and current are drawn only from the yard's own (a drum, a transformer, a fire the yard
## lit); scrap from any pile lying still.
static func drawable(record: Dictionary, substance: String = "water") -> bool:
	if record["material"] != substance or record["shape"] != "patch" or record.get("suspended", false): return false
	if record.get("forming", false) or record.has("reaction") or record["velocity"].length_squared() > 0.01: return false
	if int(record.get("grav", 0)) != 0 or not record["attachments"].is_empty(): return false
	if substance == "current": return true
	return int(record.get("charge", 0)) == 0

static func can_raise(record: Dictionary) -> bool:
	return not record.get("suspended", false) and record["shape"] in ["patch", "cloud"]

static func can_wall(record: Dictionary) -> bool:
	return record["material"] in ["water", "ice", "fire", "current", "scrap"] and record["shape"] in ["patch", "orb"]

static func can_drop(record: Dictionary) -> bool:
	return record.get("suspended", false) or record["shape"] in ["wall", "cloud"]

static func field_mobile(record: Dictionary) -> bool:
	return record["shape"] != "wall" and int(record.get("grav", 0)) == 0

static func has_property(record: Dictionary, property: String) -> bool:
	if property == "movable" and record.get("suspended", false): return true
	if property in record.get("properties", []):
		return true
	return property in MATERIALS[record["material"]]["properties"]

# --- Properties --------------------------------------------------------------------------------
# Matter and machines share a short vocabulary: `temp` (-2 frozen .. +2 burning), `wet`, `charge`
# (0..2), `grav` (-1 repels, +1 pulls), `mass` and `code` (reserved). Water's phase follows from
# its temp, and the old flags read off the properties: hard ice is -2, scalding steam +2, a well
# is grav +1, a repulsor grav -1.
const PHASE_TEMP := {"ice": -1, "water": 0, "steam": 1, "fire": 2, "current": 0, "scrap": 0}
const MASS := {"water": 1.0, "ice": 2.0, "steam": 0.2, "fire": 0.1, "current": 0.0, "scrap": 3.0}

static func phase(temp: int) -> String:
	return "ice" if temp <= -1 else ("steam" if temp >= 1 else "water")

static func temp_of(record: Dictionary) -> int:
	return int(record.get("temp", PHASE_TEMP.get(record["material"], 0)))

static func mass_of(record: Dictionary) -> float:
	return float(record.get("mass", MASS.get(record["material"], 1.0)))

## Gravity is a whirlpool or a blast, never a number to work out. A well spins its own matter out
## into a ring and draws what is loose within VORTEX_REACH onto that ring, where it goes round with
## it -- through water, through flame, against tumbling scrap -- until the well lets go and all of
## it flies off along the ring like a sling. A repulsor throws a wave out from its matter to
## BLAST_REACH, flinging what the front meets, then holds a bubble no machine walks into. The
## strength is the same for every substance: weight shows in what the throw hits, not in the pull.
const VORTEX_RING := 2.4
const VORTEX_REACH := 6.0
const ORBIT_SPEED := 5.0
## How close to the ring counts as riding in it.
const RING_BAND := 0.9
const BLAST_REACH := 6.0
## The front runs out this fast, so a machine 6 m away is thrown 0.6 s after one beside the matter.
const WAVE_SPEED := 10.0
const BUBBLE := 3.0
static func gravity(record: Dictionary) -> float:
	return clampf(float(record.get("grav_power", 1.0)), 0.5, 2.5)

## Where a field stands: the matter's foot on the floor.
static func field_center(record: Dictionary) -> Vector3:
	return Vector3(record["position"].x, float(record.get("ground_y", record["position"].y)), record["position"].z)

## The way round a well's ring at `point`: counter-clockwise seen from above, the same for every
## well, so a player learns which way things will fly when it lets go.
static func orbit_tangent(center: Vector3, point: Vector3) -> Vector3:
	var gap := Vector3(point.x - center.x, 0, point.z - center.z)
	if gap.length_squared() < 0.0025: gap = Vector3.RIGHT * 0.05
	return Vector3(-gap.z, 0, gap.x).normalized()

## A body caught by a well: drawn onto the ring (out from the middle, in from beyond it) and carried
## round it. `power` scales both, for a collapse's short hard pull.
static func orbit_velocity(velocity: Vector3, center: Vector3, point: Vector3, delta: float, power: float = 1.0) -> Vector3:
	var gap := Vector3(point.x - center.x, 0, point.z - center.z)
	var distance: float = gap.length()
	if distance > VORTEX_REACH: return velocity
	var outward: Vector3 = gap / distance if distance > 0.05 else Vector3.RIGHT
	var onto: float = clampf((VORTEX_RING - distance) * 2.4, -6.0, 4.0)
	var wanted: Vector3 = orbit_tangent(center, point) * ORBIT_SPEED * minf(1.0, distance / VORTEX_RING + 0.3) + outward * onto
	return velocity.move_toward(wanted * power, FIELD_ACCEL * power * delta)

## What a well lets go of flies off along the ring and a little out from it.
static func sling(center: Vector3, point: Vector3) -> Vector3:
	var gap := Vector3(point.x - center.x, 0, point.z - center.z)
	var outward: Vector3 = gap.normalized() if gap.length() > 0.05 else Vector3.RIGHT
	return (orbit_tangent(center, point) * 0.8 + outward * 0.6).normalized() * (ORBIT_SPEED + 4.0)

## How far a repulsor's front has run, `age` seconds after it was set off.
static func wave_front(age: float) -> float:
	return minf(BLAST_REACH, age * WAVE_SPEED)

## The throw a repulsor's front gives what it meets: hardest beside the matter.
static func blast_velocity(center: Vector3, point: Vector3) -> Vector3:
	var gap := Vector3(point.x - center.x, 0, point.z - center.z)
	var outward: Vector3 = gap.normalized() if gap.length() > 0.05 else Vector3.RIGHT
	return outward * lerpf(11.0, 7.0, clampf(gap.length() / BLAST_REACH, 0.0, 1.0))

## "well", "repel" or "" from the record's gravity.
static func field(record: Dictionary) -> String:
	var grav: int = int(record.get("grav", 0))
	return "well" if grav > 0 else ("repel" if grav < 0 else "")

static func hard(record: Dictionary) -> bool:
	return record["material"] == "ice" and temp_of(record) <= -2

static func scald(record: Dictionary) -> bool:
	return record["material"] == "steam" and temp_of(record) >= 2

## Impulse: what a moving thing does to what it hits, mass times speed. Shards weigh half a sheet.
const IMPULSE := 0.85
const IMPULSE_CAP := 14.0
static func impact(record: Dictionary, speed: float) -> float:
	var mass: float = mass_of(record) * (0.5 if record["shape"] == "fragments" else 1.0)
	return minf(IMPULSE_CAP, mass * speed * IMPULSE)
