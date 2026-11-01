## The basic attack as a program. Each operator's weapon is their own matter -- Brasa's arm pours a
## jet of fire, the Sereno's ward looses ánimas that burst into water -- and up to three DO pieces
## shape what every hit does, read with the same words as a routine: heat warms what it hits, cold
## chills it, arc charges it and jumps, push shoves, attract gathers, repel throws, raise reaches
## what flies, wall leaves the matter on the floor, coat plants nanites, and drop -- after raise, as
## in a routine -- lifts a ball of the weapon's matter over the lead machine and lets it fall.
## Bare, a weapon only hurts: what it does beyond that is what the player put there.
## `profile` is read by the host (run.gd) and by the editor, so both say the same thing.
extends RefCounted
const MAX_STEPS := 3
## What the weapon is when nothing is plugged into it: damage a hit (+ per «Doble carga»), seconds
## between hits, and reach in metres. The host fires with these and the editor prints them.
const WEAPON := {
	"fire": {"name": "llama", "text": "chorro de fuego en abanico a 6 m que calienta un paso lo que toca", "damage": 3.2, "power": 0.8, "every": 0.14, "reach": 6.0, "ball": "una bola de fuego", "fall": 9.0},
	"water": {"name": "ánimas", "text": "ánimas que revientan en agua sobre la máquina, empapan y salpican a 2 m", "damage": 5.0, "power": 2.2, "every": 0.45, "reach": 11.0, "ball": "una esfera de agua", "fall": 10.0},
}
## Drop after raise: every FALL_EVERY seconds a ball goes up from the operator's hands to
## FALL_HEIGHT over where the lead machine is headed and falls, FALL_TIME from leaving the hands
## to the floor. It hits everything within FALL_RADIUS of where it lands (`fall` damage at the
## centre, 60 % at the edge), brings down what flies under it, and is a hit of the weapon's own.
const FALL_EVERY := 1.6
const FALL_TIME := 0.7
const FALL_HEIGHT := 4.5
const FALL_RADIUS := 1.8

## The weapon `base` with `steps` plugged in: what a hit does, plus a line per step for the editor.
## {"temp", "charge", "knock", "gather", "scatter", "aloft", "trail", "coat", "slam", "trace": [{"key", "text", "idle"}]}
static func profile(steps: Array, base: String) -> Dictionary:
	# Fire heats what it touches before anything is plugged in; water only wets.
	var hit: Dictionary = {"base": base, "temp": 1 if base == "fire" else 0, "charge": 0, "knock": 0, "gather": false, "scatter": false, "aloft": false, "trail": false, "coat": 0, "slam": false, "trace": []}
	for key: Variant in steps:
		var text: String = ""
		var idle: bool = false
		match key:
			"fire":
				if hit["temp"] >= 2: idle = true
				else:
					hit["temp"] += 1
					text = _heat_text(hit["temp"], base)
			"cold":
				if hit["temp"] <= -2: idle = true
				else:
					hit["temp"] -= 1
					text = _heat_text(hit["temp"], base)
			"arc":
				if hit["charge"] >= 2: idle = true
				else:
					hit["charge"] += 1
					text = "cada golpe descarga y salta %d máquinas por lo mojado y el metal" % (1 + hit["charge"])
			"push":
				if hit["knock"] >= 2: idle = true
				else:
					hit["knock"] += 1
					text = "empuja %s, y lanzada contra otra golpea a las dos" % ("fuerte" if hit["knock"] > 1 else "hacia atrás")
			"well":
				if hit["gather"] or hit["scatter"]: idle = true
				else:
					hit["gather"] = true
					text = "atrae lo golpeado hacia el blanco y junta el grupo"
			"repel":
				if hit["gather"] or hit["scatter"]: idle = true
				else:
					hit["scatter"] = true
					text = "aparta todo lo que toca lejos de ti"
			"raise":
				if hit["aloft"]: idle = true
				else:
					hit["aloft"] = true
					text = "alcanza lo que vuela" + (" y llega 3 m más lejos" if base == "water" else "")
			"wall":
				if hit["trail"]: idle = true
				else:
					hit["trail"] = true
					text = "deja %s donde golpea, de lo que llevas encima" % ("fuego en el suelo" if base == "fire" else "un charco")
			"coat":
				if hit["coat"] >= 2: idle = true
				else:
					hit["coat"] += 1
					text = "planta nanitos%s que estallan al caer la máquina o al arder" % (" (doble carga)" if hit["coat"] > 1 else "")
			"drop":
				if hit["slam"]: idle = true
				elif not hit["aloft"]:
					# Same word as in a routine: only what was raised can fall.
					idle = true
					text = "en el suelo no cae nada; pon raise antes"
				else:
					hit["slam"] = true
					text = "cada %s s alza %s sobre el blanco y la deja caer; golpea a %s m y derriba lo que vuela" % [_num(FALL_EVERY), WEAPON[base]["ball"], _num(FALL_RADIUS)]
			_: idle = true
		if idle and text == "": text = "ya lo hace, no suma nada"
		hit["trace"].append({"key": key, "text": text, "idle": idle})
	return hit

static func _num(value: float) -> String:
	return str(value).replace(".", ",")

static func _heat_text(temp: int, base: String) -> String:
	if base == "fire":
		match temp:
			2: return "la llama avivada prende al primer golpe"
			1: return "la llama calienta un paso en cada golpe y acaba prendiendo"
			0: return "la llama templada golpea sin prender"
			-1: return "el chorro helado enfría un paso y congela lo mojado"
			-2: return "el chorro gélido congela lo mojado al instante"
	match temp:
		2: return "ánimas de vapor hirviendo que queman y no empapan"
		1: return "ánimas tibias que secan y calientan un paso"
		0: return "ánimas de agua que empapan"
		-1: return "granizo que empapa y enfría; lo mojado se congela"
	return "granizo duro que congela lo que empapa"

## The weapon in one line for the editor and the HUD.
static func describe(steps: Array, base: String) -> String:
	var hit: Dictionary = profile(steps, base)
	var does: Array[String] = []
	for entry: Dictionary in hit["trace"]: if not entry["idle"]: does.append(entry["text"].get_slice(":", 0))
	return WEAPON[base]["text"] + ("" if does.is_empty() else " · " + " · ".join(does))
