extends ProgramBlock


func execute(context: ProgramContext) -> void:
	context.stopped = true
	context.trace.append("fin de ciclo")
	flash()
