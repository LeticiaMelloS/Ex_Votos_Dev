class_name Controles
## Registra as ações de entrada em código, para não depender do editor.
## Teclado + botões básicos de controle (padrão Xbox).

static func registrar() -> void:
	_acao("mover_esquerda", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_acao("mover_direita", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_acao("pular", [KEY_SPACE, KEY_W, KEY_UP], [JOY_BUTTON_A])
	_acao("ajoelhar", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	_acao("correr", [KEY_SHIFT], [JOY_BUTTON_RIGHT_SHOULDER])
	_acao("interagir", [KEY_E], [JOY_BUTTON_X])
	_acao("luz", [KEY_Q], [JOY_BUTTON_Y])
	_acao("reiniciar", [KEY_R], [JOY_BUTTON_BACK])
	_acao("debug", [KEY_TAB], [])
	_eixo("mover_esquerda", JOY_AXIS_LEFT_X, -1.0)
	_eixo("mover_direita", JOY_AXIS_LEFT_X, 1.0)
	_eixo("ajoelhar", JOY_AXIS_LEFT_Y, 1.0)


static func _eixo(nome: String, eixo: JoyAxis, valor: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = eixo
	ev.axis_value = valor
	InputMap.action_add_event(nome, ev)


static func _acao(nome: String, teclas: Array, botoes: Array) -> void:
	if InputMap.has_action(nome):
		return
	InputMap.add_action(nome)
	for tecla in teclas:
		var ev := InputEventKey.new()
		ev.physical_keycode = tecla
		InputMap.action_add_event(nome, ev)
	for botao in botoes:
		var jb := InputEventJoypadButton.new()
		jb.button_index = botao
		InputMap.action_add_event(nome, jb)
