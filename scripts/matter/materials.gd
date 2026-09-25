## Small data catalog: material transitions are explicit, multi-step recipes are not.
extends RefCounted
const MATERIALS := {
	"water": {"spawnable": true, "initial_states": ["wet"], "properties": ["reshapeable", "coatable"], "color": Color(0.12, 0.22, 0.25), "integrity": 20.0},
	"ice": {"spawnable": false, "initial_states": ["frozen"], "properties": ["solid", "breakable", "brittle", "coatable"], "color": Color(0.65, 0.76, 0.77), "integrity": 20.0},
}
const TRANSITIONS := {"freeze": {"water": "ice"}}
const COATINGS := {"nanites": {"requires": "coatable", "commands": ["detonate"], "radius": 4.0, "damage": 18.0}}

static func has_property(record: Dictionary, property: String) -> bool:
	if property in record.get("properties", []):
		return true
	return property in MATERIALS[record["material"]]["properties"]
