## What every piece does to every kind of matter, in one table. The node editor reads it to show
## a routine before it runs; the host reads the same table to pick the world operation each DO
## step compiles to, against the matter as it really is at that moment. No step stops a routine:
## a step with nothing to act on is marked «sin efecto» and the next one carries on.
extends RefCounted
const Catalog = preload("res://scripts/matter/materials.gd")

const MATTER := {"water": "agua", "ice": "hielo", "steam": "vapor", "fire": "fuego", "current": "corriente", "scrap": "chatarra"}
## Where a routine takes its matter from, as the editor names it.
const FROM := {"water": "agua", "fire": "fuego", "current": "corriente", "scrap": "chatarra"}
const WELL_RADIUS := Catalog.VORTEX_REACH
const REPEL_RADIUS := Catalog.BLAST_REACH
## Enemy-side numbers the run applies; the editor quotes them.
const SPLASH_RADIUS := 4.0
const BURST_RADIUS := 3.5
const GUST_DAMAGE := 6.0
const DROP_SOAK_RADIUS := 3.5

## A routine's matter as the properties the world keeps: `substance` (what it was drawn as),
## `temp` (-2..+2, which also gives water its phase), `grav` (+1 well, -1 repulsor), `charge`
## (0..2, from arc; a draught of current comes with its own), `coat` (nanite layers), plus its
## shape and whether it was set moving. `material`, `mass`, `hard`, `scald`, `well` and `repel`
## are read off those after every step, for the words and drawings that want them by name.
static func source(from: String = "water") -> Dictionary:
	var substance: String = from if from in Catalog.SUBSTANCES else "water"
	return _derive({"substance": substance, "temp": Catalog.PHASE_TEMP[substance], "grav": 0, "charge": Catalog.CURRENT_CHARGE if substance == "current" else 0,
		"shape": "patch", "coat": 0, "moving": false, "suspended": false, "fierce": false})

static func _derive(state: Dictionary) -> Dictionary:
	var temp: int = state["temp"]
	state["material"] = Catalog.phase(temp) if state.get("substance", "water") == "water" else state["substance"]
	state["mass"] = Catalog.MASS[state["material"]]
	state["hard"] = temp <= -2
	state["scald"] = temp >= 2
	state["well"] = state["grav"] > 0
	state["repel"] = state["grav"] < 0
	return state

## The editor's view of a live record, for the host to choose the same branch the editor showed.
static func state_of(record: Dictionary) -> Dictionary:
	var state: Dictionary = source(Catalog.substance_of(record["material"]))
	state["fierce"] = record.get("fierce", false)
	state["temp"] = Catalog.temp_of(record)
	state["grav"] = int(record.get("grav", 0))
	state["charge"] = int(record.get("charge", 0))
	state["shape"] = record["shape"]
	state["suspended"] = record.get("suspended", false)
	state["moving"] = record.get("velocity", Vector3.ZERO).length_squared() > 0.01
	state["coat"] = int(record["attachments"]["nanites"].get("charge", 1)) if record["attachments"].has("nanites") else 0
	return _derive(state)

## One DO step on `state`: {"op": world operation or "", "text": what happens, "tag": the change
## in a word for under the node, "next": the state after}. An empty op is a step with nothing to act on.
## DO pieces that change no matter: they ask about the machine nearest it when they run, and
## when the answer is no, the DO after them is skipped. Key -> what the machine must be.
const GATES := {"si_mojada": "mojada", "si_arde": "ardiendo"}

static func step(state: Dictionary, key: String) -> Dictionary:
	if GATES.has(key):
		return {"op": "gate", "text": "si la máquina más cercana está %s sigue; si no, salta el DO siguiente" % GATES[key], "tag": "¿%s?" % GATES[key], "next": state.duplicate()}
	var result: Dictionary = _step(state, key)
	_derive(result["next"])
	return result

static func _step(state: Dictionary, key: String) -> Dictionary:
	var next: Dictionary = state.duplicate()
	var temp: int = state["temp"]
	var material: String = state["material"]
	var shape: String = state["shape"]
	if shape == "gone": return _none(state, "ya no queda materia")
	if state.get("substance", "water") != "water": return _step_drawn(state, key)
	match key:
		"raise":
			if not Catalog.can_raise(state): return _none(state, "ya está elevada o su forma no permite sostenerla")
			next["suspended"] = true
			next["shape"] = "cloud" if material == "steam" else "orb"
			return _did("raise", "queda suspendida como " + ("nube de vapor" if material == "steam" else "esfera de " + MATTER[material]), "flota", next)
		"wall":
			if not Catalog.can_wall(state): return _none(state, "un muro requiere agua o hielo sin romper")
			next["shape"] = "wall"
			next["suspended"] = false
			next["moving"] = false
			return _did("wall", "se extiende en " + ("barrera sólida" if material == "ice" else "cortina de agua"), "muro", next)
		"cold":
			# Cold is energy that takes one step of temp; steam, however hot, condenses straight to water.
			if temp <= -2: return _none(state, "ya está endurecido")
			next["temp"] = 0 if temp >= 1 else temp - 1
			if temp >= 1:
				next["shape"] = "orb" if state["suspended"] else "patch"
				next["moving"] = false
				return _did("freeze", "se condensa en agua" + (" suspendida" if state["suspended"] else " en el suelo"), "agua", next)
			if temp == 0: return _did("freeze", "se congela", "hielo", next)
			return _did("harden", "se endurece y aguanta más", "duro", next)
		"fire":
			# Fire is energy that gives one step of temp; ice, however hard, melts straight to water.
			if temp >= 2: return _none(state, "ya hierve")
			next["temp"] = 0 if temp <= -1 else temp + 1
			if temp <= -1:
				if shape == "fragments": next["shape"] = "patch"
				return _did("heat", "se derrite", "agua", next)
			if temp == 0:
				next["shape"] = "cloud"
				return _did("heat", "hierve en vapor", "vapor", next)
			return _did("scald", "vapor hirviendo que quema", "hirviendo", next)
		"coat":
			if state["coat"] >= 2: return _none(state, "ya lleva doble carga")
			next["coat"] = state["coat"] + 1
			if state["coat"] == 0: return _did("coat", "se cubre de nanitos", "+nanitos", next)
			return _did("charge", "doble carga de nanitos", "carga ×2", next)
		"arc":
			if state["charge"] >= 2: return _none(state, "ya lleva carga doble")
			next["charge"] = state["charge"] + 1
			return _did("arc", "se carga y descarga en lo que la toque" if state["charge"] == 0 else "con carga doble salta más veces", "carga" if state["charge"] == 0 else "carga ×2", next)
		"push":
			next["moving"] = true
			if shape == "orb": return _did("push", "lanza la esfera, que " + ("salpica al chocar" if material == "water" else "golpea y se quiebra al chocar"), "proyectil", next)
			if material == "steam" or shape == "fragments": return _did("push", "va hacia la máquina", "en marcha", next)
			if material == "water": return _did("slide", "avanza como ola, empapa y empuja", "ola", next)
			return _did("slide", "se desliza como ariete y se quiebra al chocar", "ariete", next)
		"well":
			if state["grav"] > 0: return _none(state, "ya es un pozo")
			next["grav"] = 1
			return _did("well", "gira en un remolino que arrastra a su anillo lo que hay a %d m y lo suelta a los 5 s" % WELL_RADIUS, "remolino", next)
		"repel":
			if state["grav"] < 0: return _none(state, "ya repele")
			next["grav"] = -1
			return _did("repel", "onda que lanza lo que hay a %d m; luego una burbuja de %d m" % [REPEL_RADIUS, int(Catalog.BUBBLE)], "onda", next)
		"drop":
			if not Catalog.can_drop(state): return _none(state, "ya está en el suelo; usa raise primero")
			next["suspended"] = false
			next["moving"] = false
			if material == "steam":
				next["temp"] = 0
				next["shape"] = "patch"
				return _did("drop", "llueve y empapa a %s m" % _num(DROP_SOAK_RADIUS), "lluvia", next)
			if material == "water":
				next["shape"] = "patch"
				return _did("drop", "se vuelca y empapa" if shape == "wall" else "cae en aguacero y empapa a %s m" % _num(DROP_SOAK_RADIUS), "aguacero", next)
			# Ice crushes what is under it and breaks; shards are spent in the fall.
			next["shape"] = "gone" if shape == "fragments" else "fragments"
			return _did("drop", "se vuelca y se hace añicos" if shape == "wall" else "cae y golpea a 2,5 m", "se gasta" if shape == "fragments" else "añicos", next)
	return _none(state, "")

## The same pieces on fire, current and scrap. Each acts by itself: fire lights and is consumed,
## current looks for ground and is spent a discharge at a time, scrap is weight and metal.
static func _step_drawn(state: Dictionary, key: String) -> Dictionary:
	var next: Dictionary = state.duplicate()
	var temp: int = state["temp"]
	var material: String = state["material"]
	var shape: String = state["shape"]
	var name: String = MATTER[material]
	match key:
		"raise":
			if not Catalog.can_raise(state): return _none(state, "ya está elevada o su forma no permite sostenerla")
			next["suspended"] = true
			next["shape"] = "orb"
			return _did("raise", {"fire": "bola de fuego suspendida", "current": "rayo en bola, suspendido", "scrap": "bola de chatarra suspendida"}[material], "flota", next)
		"wall":
			if not Catalog.can_wall(state): return _none(state, "un muro requiere la materia entera")
			next["shape"] = "wall"
			next["suspended"] = false
			next["moving"] = false
			return _did("wall", {"fire": "muro de llamas que quema al que cruza", "current": "valla viva que descarga al que la toca", "scrap": "barricada de chatarra que bloquea el paso"}[material], "muro", next)
		"cold":
			if material == "fire":
				next["shape"] = "gone"
				return _did("quench", "se apaga en humo y ya no queda fuego", "se apaga", next)
			if temp <= -1: return _none(state, "ya está fría")
			next["temp"] = temp - 1
			if material == "current": return _did("chill", "superconduce y salta más lejos" if temp == 0 else "se enfría y deja de quemar", "fría" if temp == 0 else "se enfría", next)
			return _did("chill", "el metal helado se quiebra en más metralla" if temp == 0 else "se enfría", "helada" if temp == 0 else "se enfría", next)
		"fire":
			if material == "fire":
				if state["fierce"]: return _none(state, "ya arde avivado")
				next["fierce"] = true
				return _did("stoke", "se aviva y arde %s s más, más fuerte" % _num(Catalog.STOKE), "avivado", next)
			if temp >= 2: return _none(state, "ya está al rojo")
			next["temp"] = temp + 1
			if material == "current": return _did("warm", "pasa a plasma, que quema y prende al descargar" if temp >= 0 else "se templa", "plasma" if temp >= 0 else "templada", next)
			if temp == 0: return _did("warm", "se calienta, seca y calienta lo que toca", "caliente", next)
			return _did("warm", "se pone al rojo y prende lo que toca" if temp == 1 else "se templa", "al rojo" if temp == 1 else "templada", next)
		"coat":
			if state["coat"] >= 2: return _none(state, "ya lleva doble carga")
			next["coat"] = state["coat"] + 1
			var fuse: String = {"fire": "el fuego los detona en el próximo pulso", "current": "estallan con la descarga", "scrap": "metralla cebada"}[material]
			if material == "scrap" and temp >= 1: fuse = "el metal al rojo los detona"
			return _did("coat" if state["coat"] == 0 else "charge", ("se cubre de nanitos; " if state["coat"] == 0 else "lleva doble carga; ") + fuse, "+nanitos" if state["coat"] == 0 else "carga ×2", next)
		"arc":
			var most: int = Catalog.MAX_CURRENT if material == "current" else 2
			if state["charge"] >= most: return _none(state, "ya lleva toda la carga")
			next["charge"] = state["charge"] + 1
			var does: String = {"fire": "el aire ionizado conduce y descarga en lo que arda", "current": "otra descarga más", "scrap": "el metal cargado descarga en lo que toque"}[material]
			return _did("arc", does, "carga ×%d" % next["charge"] if next["charge"] > 1 else "carga", next)
		"push":
			next["moving"] = true
			if shape == "orb": return _did("push", {"fire": "lanza la bola, que prende lo que toca", "current": "lanza el rayo, que descarga al tocar", "scrap": "lanza la chatarra, que golpea fuerte"}[material], "proyectil", next)
			if shape == "fragments": return _did("push", "metralla hacia la máquina", "en marcha", next)
			return _did("slide", {"fire": "avanza como lengua de fuego, prendiendo", "current": "corre por el suelo buscando tierra", "scrap": "baja en avalancha, arrolla y se hace metralla"}[material], "en marcha", next)
		"well":
			if state["grav"] > 0: return _none(state, "ya es un pozo")
			next["grav"] = 1
			return _did("well", "gira en un remolino que arrastra a su anillo lo que hay a %d m y lo suelta a los 5 s" % WELL_RADIUS, "remolino", next)
		"repel":
			if state["grav"] < 0: return _none(state, "ya repele")
			next["grav"] = -1
			return _did("repel", "onda que lanza lo que hay a %d m; luego una burbuja de %d m" % [REPEL_RADIUS, int(Catalog.BUBBLE)], "onda", next)
		"drop":
			if not Catalog.can_drop(state): return _none(state, "ya está en el suelo; usa raise primero")
			next["suspended"] = false
			next["moving"] = false
			next["shape"] = "patch"
			return _did("drop", {"fire": "cae y prende el suelo", "current": "cae a tierra y descarga a %s m" % _num(DROP_SOAK_RADIUS), "scrap": "cae y aplasta a 2,5 m"}[material], "cae", next)
	return _none(state, "")

static func _did(op: String, text: String, tag: String, next: Dictionary) -> Dictionary:
	return {"op": op, "text": text, "tag": tag, "next": next}

static func _none(state: Dictionary, why: String) -> Dictionary:
	return {"op": "", "text": "no hace nada" + (", " + why if why != "" else ""), "tag": "sin efecto", "next": state.duplicate()}

## Walks every DO step. Returns {"state", "trace": [{key, op, text, state}], "idle": indices with no effect}.
static func simulate(steps: Array, from: String = "water") -> Dictionary:
	var state: Dictionary = source(from)
	var trace: Array[Dictionary] = []
	var idle: Array[int] = []
	for index: int in steps.size():
		var result: Dictionary = step(state, steps[index])
		if result["op"] == "": idle.append(index)
		state = result["next"]
		trace.append({"key": steps[index], "op": result["op"], "text": result["text"], "tag": result["tag"], "state": state})
	return {"state": state, "trace": trace, "idle": idle}

# --- Words --------------------------------------------------------------------------------------

static func _num(value: float) -> String:
	return ("%.1f" % value).replace(".", ",").trim_suffix(",0")

## What a patch of matter has become, in two words: «muro de hielo», «nube de vapor».
static func matter_text(state: Dictionary) -> String:
	if state["shape"] == "gone": return "nada (se gastó)"
	var made: String = MATTER[state["material"]]
	if state["hard"] and state["material"] == "ice": made += " duro"
	if state["scald"] and state["material"] == "steam": made += " hirviendo"
	if state["material"] == "fire" and state.get("fierce", false): made += " avivado"
	if state["material"] in ["current", "scrap"] and state["temp"] != 0: made += " fría" if state["temp"] < 0 else (" en plasma" if state["material"] == "current" else " al rojo" if state["temp"] >= 2 else " caliente")
	var text: String = {"orb": "esfera de %s", "patch": "charco de %s", "wall": "muro de %s", "cloud": "nube de %s", "fragments": "esquirlas de %s"}.get(state["shape"], "%s") % made
	if state["material"] == "ice" and state["shape"] == "patch": text = "placa de " + made
	if state["moving"] and state["shape"] in ["patch", "wall"]: text = {"water": "ola de ", "ice": "ariete de ", "fire": "lengua de ", "current": "reguero de ", "scrap": "avalancha de "}[state["material"]] + made
	if state["material"] == "fire" and state["shape"] == "orb": text = text.replace("esfera de fuego", "bola de fuego")
	# On the floor each is its own thing: a burning slick, live paving, a heap.
	if state["shape"] == "patch" and not state["moving"]: text = {"fire": "fuego en el suelo", "current": "corriente en el suelo", "scrap": "montón de chatarra"}.get(state["material"], text) + made.trim_prefix(MATTER[state["material"]])
	if state.get("suspended", false): text += " suspendida" if not state["moving"] else " lanzada"
	if state["well"]: text += " · remolino"
	if state["repel"]: text += " · onda"
	if state["charge"] > 0 and state["material"] != "current": text += " · cargado" + (" ×2" if state["charge"] > 1 else "")
	if state["material"] == "current": text += " · %d descargas" % state["charge"] if state["charge"] != 1 else " · 1 descarga"
	if state["coat"] > 0: text += " + nanitos" + (" ×2" if state["coat"] > 1 else "")
	return text

## What the finished matter does to machines just by being there.
static func traits(state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var material: String = state["material"]
	match state["shape"]:
		"gone": return out
		"orb": out.append("se puede lanzar o soltar" if not state["moving"] else {"water": "salpica al chocar", "fire": "prende al chocar", "current": "descarga al chocar"}.get(material, "se quiebra al chocar"))
		"wall": out.append({"ice": "bloquea el paso", "scrap": "bloquea el paso", "fire": "quema al cruzarla", "current": "descarga al tocarla"}.get(material, "cortina: moja al cruzarla"))
		"patch": out.append({"water": "frena 25 %", "ice": "hace resbalar %d %%" % (55 if state["hard"] else 45), "fire": "prende lo que la pisa", "current": "descarga en lo que pisa", "scrap": "frena 35 %"}.get(material, ""))
		"cloud": out.append("tapa la vista · frena 50 %")
		"fragments": out.append("esquirlas sueltas")
	if material == "ice" and state["shape"] in ["wall", "patch", "orb"]:
		out.append("aguante %d" % roundi((27.2 if state["shape"] == "wall" else 25.6 if state["shape"] == "orb" else 20.48) * (1.6 if state["hard"] else 1.0)))
	if material == "fire": out.append("arde %s s y se consume" % _num(Catalog.FIRE_LIFETIME + (Catalog.STOKE if state.get("fierce", false) else 0.0)))
	if material == "current": out.append("busca la máquina más cercana")
	if material == "scrap" and state["temp"] >= 2: out.append("al rojo: prende lo que toca")
	if state["well"]: out.append("gira 5 s y lo suelta todo · muros y fuentes no se mueven")
	if state["repel"]: out.append("onda y 4 s de burbuja")
	return out.filter(func(item: String) -> bool: return item != "")

## The reaction moment is an explicit instruction, independent of material.
const ON := ["contact", "broken", "timer", "pulse", "mano"]
const ON_NAMES := {"contact": "al contacto", "broken": "al romperse", "timer": "tras 2 s", "pulse": "al recibir pulso", "mano": "al hacer clic"}
## How long matter armed «on click» must stand before a click lets it go, so the click that
## made it does not also spend it.
const CLICK_ARMING := 0.3
const REACTION_DELAY := 2.0
## Whether `record` is `peer`'s matter armed «on click» and ready for the click.
static func click_ready(record: Dictionary, peer: int) -> bool:
	var reaction: Dictionary = record.get("reaction", {})
	return int(record.get("owner", 0)) == peer and reaction.get("trigger", "") == "survivor" and reaction.get("on", "") == "mano" and float(reaction.get("after", REACTION_DELAY)) <= REACTION_DELAY - CLICK_ARMING

static func moment(state: Dictionary, _then: String, on: String = "contact") -> String:
	if state["shape"] == "gone": return "nunca: no queda materia"
	return ON_NAMES.get(on, "al contacto")

## What a THEN does with this matter when its moment comes.
static func effect(state: Dictionary, then: String) -> String:
	var material: String = state["material"]
	var text: String = ""
	match then:
		"fragmentos":
			text = {"ice": "esquirlas disparadas a la máquina más próxima", "water": "salpica, empapa y empuja a %s m" % _num(SPLASH_RADIUS), "steam": "sale en ráfaga y empuja a %s m" % _num(SPLASH_RADIUS) + (" y quema" if state["scald"] else ""),
				"fire": "suelta chispas que prenden a %s m" % _num(SPLASH_RADIUS), "current": "descarga en cadena a la máquina más próxima", "scrap": "metralla disparada a la máquina más próxima"}[material]
		"detonar":
			return "detona los nanitos" + (" (doble carga)" if state["coat"] > 1 else "") if state["coat"] > 0 else "no detona nada sin coat"
		"estallar":
			text = {"water": "salpica, empapa y empuja", "ice": "se rompe y proyecta esquirlas", "steam": "se dispersa y empuja", "fire": "estalla en llamas y prende",
				"current": "descarga en todo", "scrap": "revienta en metralla"}[material] + " a %s m" % _num(BURST_RADIUS)
		"cadena":
			text = "envía un pulso; el destino responde si reacciona al recibir pulso"
		"colapso":
			text = "remolino fuerte de 1 s a %d m; al soltar, la materia estalla" % WELL_RADIUS
	return text
