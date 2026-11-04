## A build is the player's own program: routines assembled from pieces, run by the host on its
## own. Each routine is WHEN (when and where it fires) + DO (matter steps applied to a draught
## drawn from the yard near its operator: water from a puddle, fire from a drum, current from a
## transformer, scrap from a heap, as its `from` says) + THEN (the reaction it is armed with).
## The basic attack is programmed too: `attack.steps` are DO pieces plugged into the operator's
## own weapon (see attack.gd), taken from the same box. Tools are plain passive upgrades.
extends RefCounted
const Recipe = preload("res://scripts/survivor/recipe.gd")
const Rules = preload("res://scripts/survivor/rules.gd")
const Attack = preload("res://scripts/survivor/attack.gd")
## The editor's address for the basic attack's row, beside the box (-1) and the routines (0..).
const ATTACK := -2
const SLOTS := ["when", "step", "then"]
## Programming words stay in English, the way any programmer reads them; what they do is told in
## Spanish. `name` is the identifier on the node, `text` the explanation, and `cooldown` the seconds between firings.
const SLOT_NAMES := {"when": "WHEN", "step": "DO", "then": "THEN", "tool": "TOOL"}
const MAX_ROUTINES := 4
## How far from its operator «on wade» notices a machine in a puddle (spellwork.DRAW_REACH says the same).
const DRAW_REACH := 13.0
const MAX_STEPS := 4
## Clicking the source node cycles a routine through what its operator pours.
static func next_source(from: String) -> String:
	var all: Array = Recipe.Catalog.SUBSTANCES
	return all[(all.find(from) + 1) % all.size()]
const PIECES := {
	"cerca": {"slot": "when", "name": "near", "text": "Cuando una máquina llega a nueve metros, entre tú y ella.", "cooldown": 5.0},
	"cada": {"slot": "when", "name": "every 6s", "text": "Cada seis segundos, sobre la máquina más próxima.", "cooldown": 6.0},
	"rastro": {"slot": "when", "name": "on move", "text": "Cada cuatro metros recorridos, detrás de ti.", "cooldown": 2.5},
	"grupo": {"slot": "when", "name": "on crowd", "text": "Cuando tres o más máquinas se juntan, en medio de ellas.", "cooldown": 7.0},
	"herido": {"slot": "when", "name": "on hit", "text": "Justo después de que te golpeen, delante de ti.", "cooldown": 3.5},
	"eco": {"slot": "when", "name": "echo", "text": "Justo después de la rutina de arriba, un poco más allá de su materia.", "cooldown": 0.0, "max": 2},
	"derribo": {"slot": "when", "name": "on kill", "text": "Cuando cae una máquina a diez metros de ti, donde cayó.", "cooldown": 4.0},
	"charco": {"slot": "when", "name": "on wade", "text": "Cuando una máquina pisa un charco a tu alcance, con el agua de ese mismo charco.", "cooldown": 4.0},
	"mano": {"slot": "when", "name": "on cue", "text": "Cuando haces clic, donde apuntas, hasta trece metros de ti. Las rutinas on cue listas salen juntas.", "cooldown": 4.0},
	"raise": {"slot": "step", "name": "raise", "text": "Eleva la materia y la sostiene: esfera de agua, hielo o chatarra, bola de fuego, rayo en bola, nube de vapor. Puedes lanzarla, cambiarla o soltarla.", "max": 2},
	"wall": {"slot": "step", "name": "wall", "text": "Da forma de muro: agua como cortina, hielo o chatarra como barrera sólida, fuego que quema al cruzarlo, corriente que descarga al tocarla.", "max": 2},
	"cold": {"slot": "step", "name": "cold", "text": "Frío: baja un paso la temperatura. Agua a hielo, vapor a agua; el hielo se endurece; el fuego se apaga; la corriente fría salta más lejos.", "max": 3},
	"fire": {"slot": "step", "name": "heat", "text": "Calor: sube un paso la temperatura. Hielo a agua, agua a vapor; la chatarra se pone al rojo; la corriente pasa a plasma; el fuego se aviva.", "max": 3},
	"arc": {"slot": "step", "name": "arc", "text": "Carga la materia: descarga en lo que la toque y salta por agua, metal y lo mojado. La corriente gana una descarga más.", "max": 2},
	"coat": {"slot": "step", "name": "coat", "text": "Cubre la materia de nanitos explosivos; dos veces, doble carga.", "max": 2},
	"push": {"slot": "step", "name": "push", "text": "Impulsa hacia la máquina: lo suspendido vuela; lo apoyado se desliza. Agua salpica, hielo y chatarra golpean y se rompen, el fuego prende, la corriente descarga.", "max": 2},
	"well": {"slot": "step", "name": "vortex", "text": "Remolino de 5 s: la materia gira en un anillo y arrastra a él lo que hay a 6 m. Lo que gira toca esa materia (el agua empapa, el fuego prende, la chatarra muele); al terminar, todo sale despedido y la materia estalla.", "max": 2},
	"repel": {"slot": "step", "name": "repel", "text": "Onda: lanza lejos todo lo que hay a 6 m, y lo lanzado choca con lo que pille. Luego, 4 s de burbuja donde no entra ninguna máquina.", "max": 2},
	"drop": {"slot": "step", "name": "drop", "text": "Suelta materia elevada: el hielo cae y se rompe, la chatarra aplasta, el agua salpica, el fuego prende el suelo, el vapor condensa en lluvia. En el suelo no hace nada. En el arma, detrás de raise: una bola de su materia cae sobre el blanco.", "max": 2},
	"fragmentos": {"slot": "then", "name": "release", "text": "En el momento elegido libera la materia: hielo o metralla hacia una máquina, agua en salpicón, vapor en ráfaga, fuego en chispas, corriente en cadena.", "max": 2},
	"detonar": {"slot": "then", "name": "detonate", "text": "En el momento elegido detona el recubrimiento de nanitos. Sin nanitos no hay explosión.", "max": 2},
	"estallar": {"slot": "then", "name": "scatter", "text": "En el momento elegido dispersa la materia alrededor: agua moja, hielo y chatarra golpean, vapor empuja, fuego prende, corriente descarga.", "max": 2},
	"cadena": {"slot": "then", "name": "relay", "text": "En el momento elegido envía un pulso a la siguiente rutina. El destino responde si su reacción está configurada al recibir pulso.", "max": 2},
	"colapso": {"slot": "then", "name": "converge", "text": "En el momento elegido, un remolino corto y fuerte de 1 s que luego lo suelta todo y hace estallar la materia.", "max": 2},
}
## The same pieces and tools in a few words, for the level-up cards and the HUD.
const SHORT := {
	"cerca": "máquina a 9 m de ti", "cada": "cada 6 s, a la más cercana", "rastro": "cada 4 m que caminas", "grupo": "3 o más máquinas juntas",
	"herido": "cuando te golpean", "eco": "justo tras la rutina anterior", "derribo": "donde cae una máquina", "charco": "máquina pisa un charco", "mano": "cuando haces clic, donde apuntas",
	"raise": "la eleva y la sostiene", "wall": "la para como muro", "cold": "agua a hielo, fuego apagado", "fire": "hielo a agua, agua a vapor", "arc": "electrifica, salta por lo mojado",
	"coat": "la cubre de nanitos", "push": "la lanza contra la máquina", "well": "remolino que arrastra a 6 m", "repel": "onda que aparta a 6 m",
	"drop": "deja caer lo elevado", "fragmentos": "la dispara a una máquina", "detonar": "revienta los nanitos",
	"estallar": "la esparce alrededor", "cadena": "avisa a la rutina siguiente", "colapso": "remolino de 1 s y estalla",
	"cadence": "disparas 18 % más seguido", "power": "más daño por disparo", "split": "llegas a más máquinas", "boots": "caminas 10 % más rápido",
	"repair": "recuperas 35 de vida", "pressure": "rutinas listas 15 % antes", "slot": "una rutina más",
}
const TOOLS := {
	"cadence": {"name": "Válvula abierta", "text": "Tu arma dispara un 18 % más rápido.", "max": 3},
	"power": {"name": "Doble carga", "text": "Cada disparo hace 3 puntos más de daño.", "max": 4},
	"split": {"name": "Dos bocas", "text": "Cada descarga alcanza a una máquina más.", "max": 2},
	"boots": {"name": "Botas de agua", "text": "Te mueves un 10 % más rápido y recoges chatarra desde más lejos.", "max": 3},
	"repair": {"name": "Parche de turno", "text": "Recuperas 35 de vida; cada nivel posterior repara 5 más.", "max": 3},
	"pressure": {"name": "Manómetro", "text": "Tus rutinas se recargan un 15 % más rápido.", "max": 3},
	"slot": {"name": "Otra rutina", "text": "Una línea más para programar.", "max": MAX_ROUTINES - 2},
}

static func fresh() -> Dictionary:
	var tools: Dictionary = {}
	for key: String in TOOLS: tools[key] = 0
	# The first routine ships assembled so the shift starts working, and shows how one reads; the
	# second is yours to fire: a charged puddle wherever you click.
	return {"routines": [{"when": "cerca", "steps": ["raise", "cold", "push"], "then": "fragmentos", "on": "broken"}, {"when": "mano", "steps": ["arc"], "then": "", "on": "contact"}], "attack": {"steps": []}, "box": [], "tools": tools}

## The attack's DO pieces; builds from before it was programmable have none.
static func attack_steps(build: Dictionary) -> Array:
	return build.get("attack", {}).get("steps", [])

static func empty_routine() -> Dictionary:
	return {"when": "", "steps": [], "then": "", "on": "contact"}

static func is_tool_key(key: String) -> bool:
	return TOOLS.has(key)

static func info(key: String) -> Dictionary:
	return TOOLS[key] if TOOLS.has(key) else PIECES[key]

static func slot_of(key: String) -> String:
	return "tool" if TOOLS.has(key) else PIECES[key]["slot"]

## Every piece the build holds, placed or boxed, as key -> count.
static func owned(build: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for routine: Dictionary in build["routines"]:
		for key: String in [routine["when"], routine["then"]] + Array(routine["steps"]):
			if key != "": counts[key] = int(counts.get(key, 0)) + 1
	for key: String in attack_steps(build): counts[key] = int(counts.get(key, 0)) + 1
	for key: String in build["box"]: counts[key] = int(counts.get(key, 0)) + 1
	return counts

static func offers(build: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var counts: Dictionary = owned(build)
	var pieces: Array[String] = []
	for key: String in PIECES:
		if int(counts.get(key, 0)) < int(PIECES[key].get("max", 1)): pieces.append(key)
	var tools: Array[String] = []
	for key: String in TOOLS:
		if int(build["tools"].get(key, 0)) < int(TOOLS[key]["max"]): tools.append(key)
	# Pieces are the point of levelling up: two of the three cards are always pieces.
	var result: Array[String] = []
	for pool: Array[String] in [pieces, pieces, tools]:
		var source: Array[String] = pool if not pool.is_empty() else (pieces if not pieces.is_empty() else tools)
		var left: Array = source.filter(func(key: String) -> bool: return key not in result)
		if left.is_empty(): continue
		result.append(left[rng.randi_range(0, left.size() - 1)])
	return result

static func threshold(level: int) -> int:
	return 5 + level * 3

## Where a new piece may go in the build: each destination is a whole replacement build.
## Index -1 is the box. Slot pieces replace what was there (it drops into the box).
static func place(build: Dictionary, key: String, routine_index: int) -> Dictionary:
	var next: Dictionary = build.duplicate(true)
	if routine_index == ATTACK and PIECES.has(key) and PIECES[key]["slot"] == "step":
		var placed: Dictionary = put(next, key, {"routine": ATTACK, "index": attack_steps(next).size()})
		if not placed.is_empty(): return placed
	if routine_index < 0 or routine_index >= next["routines"].size():
		next["box"].append(key)
		return next
	var routine: Dictionary = next["routines"][routine_index]
	var slot: String = PIECES[key]["slot"]
	if slot == "step":
		if routine["steps"].size() >= MAX_STEPS: return {}
		routine["steps"].append(key)
	else:
		if routine[slot] != "": next["box"].append(routine[slot])
		routine[slot] = key
	return next

## Takes one placed piece back into the box. `step` is the index in steps, or -1 for a slot.
static func unplace(build: Dictionary, routine_index: int, slot: String, step: int = -1) -> Dictionary:
	var next: Dictionary = build.duplicate(true)
	var routine: Dictionary = next["routines"][routine_index]
	if slot == "step":
		if step < 0 or step >= routine["steps"].size(): return next
		next["box"].append(routine["steps"][step])
		routine["steps"].remove_at(step)
	elif routine[slot] != "":
		next["box"].append(routine[slot])
		routine[slot] = ""
	return next

## Where a piece sits, for the node editor: {"routine": -1, "index": i} is the box; otherwise
## {"routine": r, "slot": "when"|"then"} or {"routine": r, "slot": "step", "index": k}.
## Lifts the piece out and returns [build without it, its key].
static func take(build: Dictionary, where: Dictionary) -> Array:
	var next: Dictionary = build.duplicate(true)
	var ri: int = int(where["routine"])
	if ri == ATTACK:
		var steps: Array = next["attack"]["steps"]
		var key: String = steps[int(where["index"])]
		steps.remove_at(int(where["index"]))
		return [next, key]
	if ri < 0:
		var key: String = next["box"][int(where["index"])]
		next["box"].remove_at(int(where["index"]))
		return [next, key]
	var routine: Dictionary = next["routines"][ri]
	if where["slot"] == "step":
		var key: String = routine["steps"][int(where["index"])]
		routine["steps"].remove_at(int(where["index"]))
		return [next, key]
	var key: String = routine[where["slot"]]
	routine[where["slot"]] = ""
	return [next, key]

## Sets a piece down at `where` (index for a step is the position it is inserted at). A CUANDO or
## LUEGO already there drops into the box. Returns {} where the piece cannot go.
static func put(build: Dictionary, key: String, where: Dictionary) -> Dictionary:
	var next: Dictionary = build.duplicate(true)
	var ri: int = int(where["routine"])
	if ri == ATTACK:
		if PIECES[key]["slot"] != "step" or not next.has("attack") or next["attack"]["steps"].size() >= Attack.MAX_STEPS: return {}
		next["attack"]["steps"].insert(clampi(int(where.get("index", 0)), 0, next["attack"]["steps"].size()), key)
		return next
	if ri < 0:
		next["box"].append(key)
		return next
	if ri >= next["routines"].size() or PIECES[key]["slot"] != where["slot"]: return {}
	var routine: Dictionary = next["routines"][ri]
	if where["slot"] == "step":
		if routine["steps"].size() >= MAX_STEPS: return {}
		routine["steps"].insert(clampi(int(where["index"]), 0, routine["steps"].size()), key)
		return next
	if routine[where["slot"]] != "": next["box"].append(routine[where["slot"]])
	routine[where["slot"]] = key
	return next

## What a patch of matter has become, in two words: «muro de hielo», «nube de vapor».
static func matter_text(state: Dictionary) -> String:
	return Recipe.matter_text(state)

## Seconds between firings of routine `index`, with the build's tools.
static func cooldown(build: Dictionary, index: int) -> float:
	var routine: Dictionary = build["routines"][index]
	if routine["when"] == "": return 0.0
	return (float(PIECES[routine["when"]]["cooldown"]) + routine["steps"].size() * 0.6) * pow(0.85, build["tools"]["pressure"])

## The routine a relay in routine `index` sends its pulse to: the next one that can fire.
static func relay_target(routines: Array, index: int) -> int:
	for offset: int in range(1, routines.size()):
		var other: int = (index + offset) % routines.size()
		if routines[other]["when"] != "": return other
	return -1

## The host accepts a rewritten build only if it uses exactly the pieces already owned.
static func same_pieces(a: Dictionary, b: Dictionary) -> bool:
	return owned(a) == owned(b)

static func well_formed(build: Dictionary, routine_count: int) -> bool:
	if not build.get("routines") is Array or not build.get("box") is Array: return false
	if build["routines"].size() != routine_count: return false
	for key: Variant in build["box"]:
		if not key is String or not PIECES.has(key): return false
	if not build.get("attack", {}) is Dictionary or not build.get("attack", {}).get("steps", []) is Array: return false
	if attack_steps(build).size() > Attack.MAX_STEPS: return false
	for step: Variant in attack_steps(build):
		if not step is String or not PIECES.has(step) or PIECES[step]["slot"] != "step": return false
	for routine: Variant in build["routines"]:
		if not routine is Dictionary or not routine.get("steps") is Array: return false
		if routine["steps"].size() > MAX_STEPS: return false
		if routine.get("on", "contact") not in Recipe.ON: return false
		if routine.get("from", "water") not in Recipe.Catalog.SUBSTANCES: return false
		for step: Variant in routine["steps"]:
			if not step is String or not PIECES.has(step) or PIECES[step]["slot"] != "step": return false
		for slot: String in ["when", "then"]:
			var key: Variant = routine.get(slot)
			if not key is String or (key != "" and (not PIECES.has(key) or PIECES[key]["slot"] != slot)): return false
	return true

## One sentence in the player's terms.
static func describe(routine: Dictionary) -> String:
	if routine["when"] == "": return "Sin WHEN: esta rutina no se activa."
	var state: Dictionary = Recipe.simulate(routine["steps"], routine.get("from", "water"))["state"]
	var parts: Array[String] = ["%s: %s" % [PIECES[routine["when"]]["name"], matter_text(state)]]
	if routine["then"] != "": parts.append("%s %s" % [PIECES[routine["then"]]["name"], Recipe.moment(state, routine["then"], routine.get("on", "contact"))])
	return ", ".join(parts) + "."

## The first thing keeping the routine from doing all it says, or "". Steps with no effect are
## warnings: the routine still runs.
static func problem(routine: Dictionary, routines: Array = [], index: int = -1) -> String:
	if routine["when"] == "": return "no arranca sin WHEN"
	if routine["when"] == "eco" and index == 0: return "echo no tiene una rutina arriba que lo dispare"
	var result: Dictionary = Recipe.simulate(routine["steps"], routine.get("from", "water"))
	if not result["idle"].is_empty():
		var at: int = result["idle"][0]
		var why: String = str(result["trace"][at]["text"]).trim_prefix("no hace nada").trim_prefix(", ")
		return ("%s no hace nada, %s" % [PIECES[routine["steps"][at]]["name"], why]) if why != "" else "%s no hace nada aquí" % PIECES[routine["steps"][at]]["name"]
	if routine["then"] != "" and result["state"]["shape"] == "gone": return "al THEN ya no le queda materia"
	if routine["then"] == "detonar" and result["state"]["coat"] == 0: return "detonate no revienta nada sin coat antes"
	if routine["then"] != "" and routine.get("on", "contact") == "broken" and result["state"]["material"] not in ["ice", "scrap"]: return "solo el hielo y la chatarra se rompen"
	if routine["then"] == "cadena" and not routines.is_empty():
		var target: int = relay_target(routines, index)
		if target < 0: return "el pulso no tiene a qué rutina llegar"
		if routines[target]["then"] == "" or routines[target].get("on", "contact") != "pulse": return "la rutina %d no hace nada con el pulso" % (target + 1)
	return ""

## The routine read out line by line for the editor: [keyword, text] pairs, in the order the
## host will run them.
static func explain(build: Dictionary, index: int) -> Array:
	var routines: Array = build["routines"]
	var routine: Dictionary = routines[index]
	var lines: Array = []
	if routine["when"] == "":
		lines.append(["WHEN", "vacío: esta rutina no se activa. Arrastra un WHEN de la caja."])
		return lines
	var when: Dictionary = PIECES[routine["when"]]
	if routine["when"] == "eco":
		lines.append(["WHEN echo", "justo después de la rutina %d" % index if index > 0 else "no hay rutina arriba: nunca se activa"])
	else:
		lines.append(["WHEN " + when["name"], "%s · recarga %s s" % [when["text"].trim_suffix(".").to_lower(), Recipe._num(snappedf(cooldown(build, index), 0.1))]])
	var from: String = routine.get("from", "water")
	var result: Dictionary = Recipe.simulate(routine["steps"], from)
	var drawn: String = "%s desde tus manos, que corre hasta allí" % Recipe.FROM[from]
	if routine["when"] == "charco" and from == "water": drawn = "agua del charco donde está la máquina"
	var chain: Array[String] = [drawn]
	for entry: Dictionary in result["trace"]: chain.append("%s: %s" % [PIECES[entry["key"]]["name"], entry["text"]])
	lines.append(["DO", ("  →  ".join(chain) if chain.size() > 1 else drawn + " y se queda en el suelo") + "  (clic en el origen: agua, fuego, corriente o chatarra)"])
	var state: Dictionary = result["state"]
	var traits: Array[String] = Recipe.traits(state)
	lines.append(["=", matter_text(state) + (": " + " · ".join(traits) if not traits.is_empty() else "")])
	var touch: Array[String] = Rules.touch(state)
	if not touch.is_empty(): lines.append(["TOUCH", "con lo que toque: " + "; ".join(touch)])
	if routine["then"] != "":
		lines.append(["THEN " + PIECES[routine["then"]]["name"], "%s: %s" % [Recipe.moment(state, routine["then"], routine.get("on", "contact")), Recipe.effect(state, routine["then"])]])
	if routine["then"] == "cadena":
		var target: int = relay_target(routines, index)
		if target < 0: lines.append(["LINK", "no hay otra rutina activa: el pulso no llega a nada"])
		else:
			var other: Dictionary = routines[target]
			var other_state: Dictionary = Recipe.simulate(other["steps"], other.get("from", "water"))["state"]
			var does: String = ("dispara su THEN %s: %s" % [PIECES[other["then"]]["name"], Recipe.effect(other_state, other["then"])]) if other["then"] != "" and other.get("on", "contact") == "pulse" else "no responde: configura al recibir pulso"
			lines.append(["LINK", "pulso a la rutina %d (%s): %s" % [target + 1, matter_text(other_state), does]])
	if index + 1 < routines.size() and routines[index + 1]["when"] == "eco":
		lines.append(["LINK", "al activarse, dispara la rutina %d (echo)" % (index + 2)])
	return lines

## The attack read out for the editor, like a routine: [keyword, text] pairs.
static func explain_attack(build: Dictionary, base: String) -> Array:
	var steps: Array = attack_steps(build)
	var hit: Dictionary = Attack.profile(steps, base)
	var lines: Array = [["ATTACK", "%s: %s" % [Attack.WEAPON[base]["name"], Attack.WEAPON[base]["text"]]]]
	if steps.is_empty():
		lines.append(["DO", "vacío: arrastra hasta %d DO de la caja y cada golpe hará lo que digan" % Attack.MAX_STEPS])
		return lines
	var chain: Array[String] = []
	for entry: Dictionary in hit["trace"]: chain.append("%s: %s" % [PIECES[entry["key"]]["name"], entry["text"]])
	lines.append(["DO", "  →  ".join(chain)])
	return lines

