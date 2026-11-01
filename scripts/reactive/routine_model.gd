## Reads a routine the way the host will run it, before it runs. Pure data: the editor uses it
## to name a routine, to say in a sentence what it will do, and to flag the step that will stop
## it. The host still re-validates everything at execution, against the real world.
extends RefCounted

const Catalog = preload("res://scripts/matter/materials.gd")

const STEP_NAMES := {"raise": "ELEVAR", "wall": "MOLDEAR MURO", "drop": "SOLTAR", "freeze": "CONGELAR", "heat": "CALENTAR", "coat": "RECUBRIR", "impact": "IMPACTAR", "push": "IMPULSAR"}
const TRIGGER_NAMES := {"broken": "AL ROMPERSE", "hit": "AL RECIBIR DAÑO", "transformed": "AL CAMBIAR DE FASE", "pulsed": "AL RECIBIR PULSO"}
const ACTION_NAMES := {"push": "IMPULSAR", "command": "DETONAR", "freeze": "CONGELAR", "heat": "CALENTAR"}
const MATERIAL_NAMES := {"water": "agua", "ice": "hielo", "steam": "vapor"}

const DEFAULT_SLOTS := [
	{"steps": ["raise", "freeze", "coat"], "trigger": "broken", "action": "push", "chain": false},
	{"steps": ["coat"], "trigger": "pulsed", "action": "command", "chain": true},
	{"steps": ["coat", "heat"], "trigger": "pulsed", "action": "command", "chain": true},
]

## Walks the steps over a stand-in record. Returns the final state, the index of the first step
## that would stop the routine (-1 if none) and why, and whether the reaction can do anything.
static func simulate(draft: Dictionary) -> Dictionary:
	var state := {"material": "water", "shape": "patch", "properties": [], "coated": false, "suspended": false}
	var failed: int = -1
	var reason: String = ""
	var steps: Array = draft.get("steps", [])
	for index: int in steps.size():
		var step: String = steps[index]
		var problem: String = _step_problem(state, step)
		if problem != "":
			failed = index
			reason = problem
			break
		_apply(state, step)
	var reaction_note: String = ""
	if failed == -1:
		reaction_note = _reaction_problem(state, draft.get("trigger", ""), draft.get("action", ""))
	return {"state": state, "failed": failed, "reason": reason, "reaction_problem": reaction_note}

static func _has(state: Dictionary, property: String) -> bool:
	return Catalog.has_property(state, property)

static func _step_problem(state: Dictionary, step: String) -> String:
	match step:
		"raise":
			if not Catalog.can_raise(state): return "La materia ya está elevada o no se puede sostener"
		"wall":
			if not Catalog.can_wall(state): return "El muro requiere agua o hielo sin romper"
		"drop":
			if not Catalog.can_drop(state): return "Ya está en el suelo: usa raise primero"
		"freeze":
			if not Catalog.TRANSITIONS["freeze"].has(state["material"]): return "El %s no se congela más" % MATERIAL_NAMES[state["material"]]
		"heat":
			if not Catalog.TRANSITIONS["heat"].has(state["material"]): return "El %s no se calienta más" % MATERIAL_NAMES[state["material"]]
		"coat":
			if state["coated"]: return "Ya está recubierto"
			if not _has(state, "coatable"): return "Esta superficie no admite nanites"
		"impact":
			if not _has(state, "breakable"): return "El %s no se rompe" % MATERIAL_NAMES[state["material"]]
		"push":
			if not _has(state, "movable"): return "El %s no se mueve" % MATERIAL_NAMES[state["material"]]
	return ""

static func _apply(state: Dictionary, step: String) -> void:
	match step:
		"raise":
			state["suspended"] = true
			state["shape"] = "cloud" if state["material"] == "steam" else "orb"
		"wall":
			state["suspended"] = false
			state["shape"] = "wall"
		"drop":
			state["suspended"] = false
			state["shape"] = "fragments" if state["material"] == "ice" else "patch"
			if state["material"] == "steam": state["material"] = "water"
			if state["shape"] == "fragments": state["properties"] = ["movable"]
		"freeze", "heat":
			var previous: String = state["material"]
			state["material"] = Catalog.TRANSITIONS[step][previous]
			if state["material"] == "steam": state["shape"] = "cloud"
			elif previous == "steam": state["shape"] = "orb" if state["suspended"] else "patch"
			elif previous == "ice" and state["shape"] == "fragments":
				state["shape"] = "patch"
				state["properties"] = []
		"coat": state["coated"] = true
		"impact":
			if _has(state, "brittle"):
				state["shape"] = "fragments"
				state["suspended"] = false
				state["properties"] = ["movable"]

## Advisory only: the trigger may happen in a different state than the routine left it in.
static func _reaction_problem(state: Dictionary, trigger: String, action: String) -> String:
	var at_trigger: Dictionary = state.duplicate(true)
	match trigger:
		"broken", "hit":
			if not _has(at_trigger, "breakable"): return "El %s no recibe golpes: este disparador no llegará" % MATERIAL_NAMES[state["material"]]
			if trigger == "broken":
				at_trigger["shape"] = "fragments"
				at_trigger["properties"] = ["movable"]
	match action:
		"push":
			if not _has(at_trigger, "movable"): return "Impulsar requiere materia elevada, fragmentos o vapor"
		"command":
			if not at_trigger["coated"]: return "Detonar requiere recubrimiento"
		"freeze", "heat":
			if not Catalog.TRANSITIONS[action].has(at_trigger["material"]): return "No hay fase siguiente para %s" % ACTION_NAMES[action].to_lower()
	return ""

## A name that says what the routine is for, the way an operator would call it.
static func name_of(draft: Dictionary) -> String:
	var result: Dictionary = simulate(draft)
	var state: Dictionary = result["state"]
	var action: String = draft.get("action", "")
	var base: String = "CHARCO"
	match state["shape"]:
		"orb": base = "ESFERA DE " + MATERIAL_NAMES[state["material"]].to_upper()
		"wall": base = "BARRERA" if state["material"] == "ice" else "CORTINA"
		"cloud": base = "VELO"
		"fragments": base = "METRALLA"
		"patch": base = "PLACA" if state["material"] == "ice" else "CHARCO"
	if state["coated"] and action == "command": base = "NUBE MINADA" if base == "VELO" else ("MINA" if base in ["CHARCO", "PLACA"] else base + " MINADA")
	if draft.get("trigger", "") == "pulsed": base += " · RELÉ"
	return base

## One sentence, in the order things will happen.
static func describe(draft: Dictionary) -> String:
	var result: Dictionary = simulate(draft)
	var parts: PackedStringArray = ["Crea agua"]
	for step: String in draft.get("steps", []):
		match step:
			"raise": parts.append("la sostiene en el aire")
			"wall": parts.append("le da forma de muro")
			"drop": parts.append("la suelta")
			"freeze": parts.append("la congela")
			"heat": parts.append("la evapora" if parts[-1] != "la levanta en muro" else "la hierve")
			"coat": parts.append("la cubre de nanites")
			"impact": parts.append("la golpea")
			"push": parts.append("la empuja")
	var sentence: String = ", ".join(parts)
	var effect: String = {"push": "lanzará lo que quede hacia delante", "command": "detonará sus nanites", "freeze": "se congelará", "heat": "se calentará"}.get(draft.get("action", ""), "")
	var when: String = {"broken": "Cuando se rompa", "hit": "Al primer golpe", "transformed": "Cuando cambie de fase", "pulsed": "Cuando le llegue un pulso"}.get(draft.get("trigger", ""), "")
	sentence += ". " + when + ", " + effect + "."
	if draft.get("chain", false): sentence += " Se conecta a tu construcción anterior."
	return sentence
