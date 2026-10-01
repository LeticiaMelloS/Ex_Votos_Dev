extends Node2D
## Ponto de entrada dos protótipos.
## F1/F2 trocam de fase, R reinicia, Tab mostra o debug. Ver README.md.

const NIVEIS := [
	"res://niveis/p1_movimento.txt",
	"res://niveis/p2_promessas.txt",
]
const ZOOM_NORMAL := 1.0
const ZOOM_ABERTO := 0.5

var nivel: Nivel
var jogadora: Protagonista
var promessas: Promessas
var camera: Camera2D
var hud: Hud
var indice := 0
var respawn := Vector2.ZERO

var _camadas: Array[Node] = []
var _escuridao: ColorRect
var _menu_altar := ""
var _menu_opcoes: Array[Dictionary] = []
var _terminou := false


func _ready() -> void:
	Controles.registrar()
	hud = Hud.new()
	add_child(hud)
	carregar_nivel(0)


func carregar_nivel(i: int) -> void:
	indice = i
	_terminou = false
	_fechar_menu()
	for n in [nivel, jogadora, promessas, camera]:
		if n != null:
			n.queue_free()
	for n in _camadas:
		n.queue_free()
	_camadas.clear()
	nivel = null
	jogadora = null
	promessas = null
	camera = null

	nivel = Nivel.new()
	add_child(nivel)
	if not nivel.carregar(NIVEIS[i]):
		return

	jogadora = Protagonista.new()
	add_child(jogadora)
	respawn = nivel.pe_da_celula(nivel.inicio)
	jogadora.reiniciar_em(respawn)

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(nivel.tamanho_px().x)
	camera.limit_bottom = int(nivel.tamanho_px().y)
	camera.global_position = respawn
	add_child(camera)
	camera.make_current()

	# Camada 1: escuridão (só em fases com "@escuro").
	_escuridao = null
	if nivel.meta.has("escuro"):
		var camada := _nova_camada(1, false)
		_escuridao = ColorRect.new()
		_escuridao.size = Vector2(1920, 1080)
		_escuridao.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = load("res://src/escuridao.gdshader")
		mat.set_shader_parameter("escuro", nivel.meta["escuro"])
		_escuridao.material = mat
		camada.add_child(_escuridao)

	# Camada 2: cera e ouro brilham acima da escuridão e acompanham a câmera.
	var brilho := _nova_camada(2, true)
	brilho.add_child(nivel.brilho)

	promessas = Promessas.new()
	promessas.nivel = nivel
	promessas.jogadora = jogadora
	promessas.camada_criaturas = brilho
	promessas.ao_ser_pega = _ao_ser_pega
	promessas.mensagem.connect(hud.mostrar_mensagem)
	add_child(promessas)

	hud.definir_titulo("%s   ·   F1/F2 fases · R reinicia · Tab debug" % nivel.meta.get("nome", "Protótipo"))
	if nivel.meta.has("dica"):
		hud.mostrar_mensagem(nivel.meta["dica"], 6.0)


func _nova_camada(n: int, segue_camera: bool) -> CanvasLayer:
	var c := CanvasLayer.new()
	c.layer = n
	c.follow_viewport_enabled = segue_camera
	add_child(c)
	_camadas.append(c)
	return c


func _physics_process(_delta: float) -> void:
	if jogadora == null or _terminou:
		return
	promessas.processar()
	var cel := nivel.celula(jogadora.centro())
	var pes := nivel.celula(jogadora.global_position - Vector2(0, 10))
	if cel == "C" or pes == "C":
		var novo := nivel.pe_da_celula(Vector2i(nivel.coluna(jogadora.global_position), floori((jogadora.global_position.y - 10) / Nivel.TILE)))
		if novo != respawn:
			respawn = novo
			hud.mostrar_mensagem("Checkpoint.", 1.5)
	if cel == "~" or pes == "~" or jogadora.global_position.y > nivel.tamanho_px().y + 200:
		_renascer()
	if cel == "G":
		_terminou = true
		jogadora.controle_ativo = false
		hud.mostrar_mensagem("Fim do protótipo. Promessas cumpridas: %d · quebradas: %d.  R reinicia, F1/F2 troca de fase." % [promessas.cumpridas, promessas.quebradas], 999.0)


func _process(delta: float) -> void:
	if jogadora == null:
		return
	# Câmera: segue com folga na direção do olhar; abre o zoom nas zonas "z".
	var alvo := jogadora.global_position + Vector2(jogadora.direcao * 90, -80)
	camera.global_position = camera.global_position.lerp(alvo, 1.0 - exp(-delta * 4.0))
	var z := ZOOM_ABERTO if nivel.celula(jogadora.centro()) == "z" else ZOOM_NORMAL
	camera.zoom = camera.zoom.lerp(Vector2(z, z), 1.0 - exp(-delta * 1.2))

	if _escuridao:
		var tela := get_viewport().get_canvas_transform()
		var mat := _escuridao.material as ShaderMaterial
		var vela := jogadora.global_position + Vector2(jogadora.direcao * 16, -jogadora.altura_atual() * 0.5 - 16)
		mat.set_shader_parameter("centro", tela * vela)
		mat.set_shader_parameter("raio", jogadora.raio_da_luz() * tela.get_scale().x)

	var altar := _altar_proximo()
	if _menu_altar != "":
		hud.definir_dica("")
	elif altar != "":
		hud.definir_dica("E — rezar no altar")
	else:
		hud.definir_dica("")

	if hud.debug_visivel():
		hud.definir_debug("FPS %d   Luz: %s   Pulos fortes: %d\n%s" % [
			Engine.get_frames_per_second(),
			"acesa" if jogadora.luz_acesa else "apagada",
			jogadora.pulos_fortes,
			promessas.resumo_debug(),
		])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				carregar_nivel(0)
				return
			KEY_F2:
				carregar_nivel(1)
				return
	if _menu_altar != "":
		_input_menu(event)
		return
	if event.is_action_pressed("reiniciar"):
		carregar_nivel(indice)
	elif event.is_action_pressed("debug"):
		hud.alternar_debug()
		nivel.mostrar_debug = hud.debug_visivel()
	elif event.is_action_pressed("interagir") and not _terminou:
		var altar := _altar_proximo()
		if altar != "":
			_abrir_menu(altar)


func _altar_proximo() -> String:
	if jogadora == null or not jogadora.is_on_floor():
		return ""
	var x := nivel.coluna(jogadora.global_position)
	var y := floori((jogadora.global_position.y - 10) / Nivel.TILE)
	for id in nivel.altares:
		var a: Vector2i = nivel.altares[id]
		if absi(a.x - x) <= 1 and absi(a.y - y) <= 1:
			return id
	return ""


func _abrir_menu(altar: String) -> void:
	_menu_opcoes = promessas.opcoes_do_altar(altar)
	if _menu_opcoes.is_empty():
		hud.mostrar_mensagem("O altar está em silêncio.")
		return
	if promessas.fita_cheia():
		hud.mostrar_mensagem("A fita não tem mais nós. Pague uma promessa antes de fazer outra.")
		return
	_menu_altar = altar
	jogadora.controle_ativo = false
	var texto := "ALTAR\n\n"
	for i in mini(_menu_opcoes.size(), 4):
		texto += "%d — %s\n\n" % [i + 1, promessas.texto_da_opcao(_menu_opcoes[i])]
	texto += "Esc — seguir sem prometer"
	hud.abrir_menu(texto)


func _input_menu(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: Key = event.keycode
	if k == KEY_ESCAPE or k == KEY_E:
		_fechar_menu()
		return
	var i: int = k - KEY_1
	if i >= 0 and i < mini(_menu_opcoes.size(), 4):
		var altar := _menu_altar
		var op := _menu_opcoes[i]
		_fechar_menu()
		promessas.escolher(op, altar)


func _fechar_menu() -> void:
	_menu_altar = ""
	_menu_opcoes = []
	hud.fechar_menu()
	if jogadora:
		jogadora.controle_ativo = not _terminou


func _ao_ser_pega() -> void:
	hud.mostrar_mensagem("A dívida a alcançou.", 2.0)
	_renascer()


func _renascer() -> void:
	jogadora.reiniciar_em(respawn)
	camera.global_position = respawn
