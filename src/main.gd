extends Node2D
## Ponto de entrada dos protótipos.
## F1–F4 trocam de fase, F9 alterna greybox/arte, F12 captura a tela, R reinicia, Tab mostra o debug. Ver README.md.

const NIVEIS := [
	"res://niveis/p1_movimento.txt",
	"res://niveis/p2_promessas.txt",
	"res://niveis/p3_corpo.txt",
	"res://niveis/sala_dos_milagres.txt",
]
const ZOOM_NORMAL := 1.0
const ZOOM_ABERTO := 0.5
const ZOOM_REVELACAO := 0.28

var nivel: Nivel
var jogadora: Protagonista
var promessas: Promessas
var oferendas: Oferendas
var arte: ArteDoNivel
var camera: Camera2D
var hud: Hud
var indice := 0
var respawn := Vector2.ZERO

var _camadas: Array[Node] = []
var _escuridao: ColorRect
var _menu_altar := ""
var _menu_opcoes: Array[Dictionary] = []
var _terminou := false
var _falas_ditas := {}


func _ready() -> void:
	Controles.registrar()
	hud = Hud.new()
	add_child(hud)
	carregar_nivel(0)


func carregar_nivel(i: int) -> void:
	indice = i
	_terminou = false
	_falas_ditas.clear()
	_fechar_menu()
	for n in [nivel, jogadora, promessas, oferendas, camera, arte]:
		if n != null:
			n.queue_free()
	for n in _camadas:
		n.queue_free()
	_camadas.clear()
	nivel = null
	jogadora = null
	promessas = null
	oferendas = null
	camera = null
	arte = null

	nivel = Nivel.new()
	add_child(nivel)
	if not nivel.carregar(NIVEIS[i]):
		return

	jogadora = Protagonista.new()
	jogadora.nivel = nivel
	add_child(jogadora)
	respawn = nivel.pe_da_celula(nivel.inicio)
	jogadora.reiniciar_em(respawn)
	if nivel.meta.has("sem_trancas"):
		jogadora.tem_trancas = false

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

	oferendas = Oferendas.new()
	oferendas.nivel = nivel
	oferendas.jogadora = jogadora
	oferendas.mensagem.connect(hud.mostrar_mensagem)
	add_child(oferendas)

	# Arte por cima do greybox (linhas "@arte" do mapa).
	arte = ArteDoNivel.new()
	arte.camera = camera
	add_child(arte)
	if arte.montar(nivel, brilho) > 0:
		nivel.modo_greybox = 1

	hud.definir_titulo("%s   ·   F1–F4 fases · R reinicia · Tab debug · F9 greybox/arte · F12 captura" % nivel.meta.get("nome", "Protótipo"))
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
	oferendas.processar()
	var cel := nivel.celula(jogadora.centro())
	var pes := nivel.celula(jogadora.global_position - Vector2(0, 10))
	if cel == "C" or pes == "C":
		var novo := nivel.pe_da_celula(Vector2i(nivel.coluna(jogadora.global_position), floori((jogadora.global_position.y - 10) / Nivel.TILE)))
		if novo != respawn:
			respawn = novo
			hud.mostrar_mensagem("Checkpoint.", 1.5)
	if cel == "~" or pes == "~" or jogadora.global_position.y > nivel.tamanho_px().y + 200:
		_renascer()
	_checar_falas()
	if cel == "G":
		_terminou = true
		jogadora.controle_ativo = false
		if nivel.meta.has("fim"):
			hud.mostrar_mensagem(nivel.meta["fim"], 999.0)
			return
		hud.mostrar_mensagem("Fim do protótipo. Promessas cumpridas: %d · quebradas: %d.  R reinicia, F1–F4 troca de fase." % [promessas.cumpridas, promessas.quebradas], 999.0)


func _process(delta: float) -> void:
	if jogadora == null:
		return
	# Câmera: segue com folga na direção do olhar; abre o zoom nas zonas "z".
	var alvo := jogadora.global_position + Vector2(jogadora.direcao * 90, -80)
	camera.global_position = camera.global_position.lerp(alvo, 1.0 - exp(-delta * 4.0))
	var aqui := nivel.celula(jogadora.centro())
	var acima := nivel.celula(jogadora.centro() - Vector2(0, Nivel.TILE))
	var z := ZOOM_NORMAL
	if aqui == "Z" or acima == "Z" or (_terminou and aqui == "G"):
		z = ZOOM_REVELACAO
	elif aqui == "z" or acima == "z":
		z = ZOOM_ABERTO
	camera.zoom = camera.zoom.lerp(Vector2(z, z), 1.0 - exp(-delta * 1.2))

	if _escuridao:
		var tela := get_viewport().get_canvas_transform()
		var mat := _escuridao.material as ShaderMaterial
		var vela := jogadora.global_position + jogadora.posicao_vela()
		mat.set_shader_parameter("centro", tela * vela)
		mat.set_shader_parameter("raio", jogadora.raio_da_luz() * tela.get_scale().x)

	var altar := _altar_proximo()
	if _menu_altar != "":
		hud.definir_dica("")
	elif _bilhete_proximo() != "":
		hud.definir_dica("E — ler o bilhete")
	elif nivel.altares_oferta.has(altar):
		hud.definir_dica("E — ofertar no altar")
	elif altar != "":
		hud.definir_dica("E — rezar no altar")
	else:
		hud.definir_dica("")

	if hud.debug_visivel():
		hud.definir_debug("FPS %d   Luz: %s   Pulos fortes: %d   Tranças: %s   Mão: %s\n%s" % [
			Engine.get_frames_per_second(),
			"acesa" if jogadora.luz_acesa else "apagada",
			jogadora.pulos_fortes,
			"sim" if jogadora.tem_trancas else "ofertadas",
			"sim" if jogadora.tem_mao else "ofertada",
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
			KEY_F3:
				carregar_nivel(2)
				return
			KEY_F4:
				carregar_nivel(3)
				return
			KEY_F12:
				_capturar_tela()
				return
			KEY_F9:
				if nivel:
					nivel.modo_greybox = (nivel.modo_greybox + 1) % 3
					hud.mostrar_mensagem(["Só greybox", "Arte + greybox translúcido", "Só arte"][nivel.modo_greybox], 1.5)
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
		var bilhete := _bilhete_proximo()
		if altar != "":
			_abrir_menu(altar)
		elif bilhete != "":
			_menu_altar = "?"
			_menu_opcoes = []
			jogadora.controle_ativo = false
			hud.abrir_menu("BILHETE\n\n%s\n\n\nEsc ou E — fechar" % bilhete)


func _altar_proximo() -> String:
	if jogadora == null or not jogadora.is_on_floor():
		return ""
	var x := nivel.coluna(jogadora.global_position)
	var y := floori((jogadora.global_position.y - 10) / Nivel.TILE)
	for lista in [nivel.altares, nivel.altares_oferta]:
		for id in lista:
			var a: Vector2i = lista[id]
			if absi(a.x - x) <= 1 and absi(a.y - y) <= 1:
				return id
	return ""


## Texto do bilhete de graça ao alcance (ou "" se não houver).
func _bilhete_proximo() -> String:
	if jogadora == null or not jogadora.is_on_floor():
		return ""
	var x := nivel.coluna(jogadora.global_position)
	var y := floori((jogadora.global_position.y - 10) / Nivel.TILE)
	for b in nivel.bilhetes:
		var c: Vector2i = b["celula"]
		if absi(c.x - x) <= 1 and absi(c.y - y) <= 1:
			return b["texto"]
	return ""


## NPCs falam uma vez, sozinhas, quando a protagonista chega perto.
func _checar_falas() -> void:
	var x := nivel.coluna(jogadora.global_position)
	var y := floori((jogadora.global_position.y - 10) / Nivel.TILE)
	for i in nivel.falas.size():
		var c: Vector2i = nivel.falas[i]["celula"]
		if not _falas_ditas.has(i) and absi(c.x - x) <= 3 and absi(c.y - y) <= 2:
			_falas_ditas[i] = true
			hud.mostrar_mensagem(nivel.falas[i]["texto"], 5.0)


## F12: salva a tela sem os textos em C:\Dev\ex-voto\capturas, para desenhar por cima.
func _capturar_tela() -> void:
	var pasta := ProjectSettings.globalize_path("res://capturas")
	DirAccess.make_dir_recursive_absolute(pasta)
	hud.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	hud.visible = true
	var nome := "%s/captura_%s.png" % [pasta, Time.get_datetime_string_from_system().replace(":", "-")]
	img.save_png(nome)
	hud.mostrar_mensagem("Captura salva em " + nome, 3.0)


func _abrir_menu(altar: String) -> void:
	if nivel.altares_oferta.has(altar):
		_abrir_menu_oferta(altar)
		return
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


func _abrir_menu_oferta(altar: String) -> void:
	if oferendas.ja_ofertado(altar):
		hud.mostrar_mensagem("O altar guarda o que você deixou.")
		return
	_menu_altar = altar
	_menu_opcoes = [{"tipo": "oferta"}]
	jogadora.controle_ativo = false
	hud.abrir_menu(oferendas.texto_do_altar(altar))


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
		if op["tipo"] == "oferta":
			oferendas.ofertar(altar)
		else:
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
