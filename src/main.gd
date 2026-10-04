extends Node2D
## Ponto de entrada do jogo.
## Começa no modo Mundo (as salas da Cidade, ligadas pelo mapa em mundo/).
## F6 volta ao Mundo · F8 recomeça o Mundo do zero · M mostra o mapa
## F1–F4 abrem os protótipos · R reinicia · Tab debug · F12 captura a tela. Ver README.md.

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
var camera: Camera2D
var hud: Hud
var indice := 0
var respawn := Vector2.ZERO

## Modo Mundo (null nos protótipos).
var mundo: Mundo
var sala_atual := ""
var respawn_sala := ""

var _camadas: Array[Node] = []
var _camada_brilho: CanvasLayer
var _camada_escuro: CanvasLayer
var _escuridao: ColorRect
var _menu_altar := ""
var _menu_opcoes: Array[Dictionary] = []
var _terminou := false
var _falas_ditas := {}
var _area_atual := ""
var _ultimo_aviso := ""
var _tempo_aviso := 0.0
var _trava_transicao := 0.0


func _ready() -> void:
	Controles.registrar()
	hud = Hud.new()
	add_child(hud)
	iniciar_mundo()


# ------------------------------------------------------------ montagem

func _limpar() -> void:
	_terminou = false
	_falas_ditas.clear()
	_fechar_menu()
	for n in [nivel, jogadora, promessas, oferendas, camera]:
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
	_camada_escuro = null
	_escuridao = null


## Monta a fase (ou a primeira sala) com tudo o que é comum aos dois modos.
func _montar(caminho: String) -> bool:
	nivel = Nivel.new()
	add_child(nivel)
	if not nivel.carregar(caminho):
		return false

	jogadora = Protagonista.new()
	jogadora.nivel = nivel
	add_child(jogadora)
	respawn = nivel.pe_da_celula(nivel.inicio)
	jogadora.reiniciar_em(respawn)
	if nivel.meta.has("sem_trancas"):
		jogadora.tem_trancas = false

	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	_ajustar_camera(true)

	_atualizar_escuridao()
	_camada_brilho = _nova_camada(2, true)
	_camada_brilho.add_child(nivel.brilho)

	promessas = Promessas.new()
	promessas.nivel = nivel
	promessas.jogadora = jogadora
	promessas.camada_criaturas = _camada_brilho
	promessas.ao_ser_pega = _ao_ser_pega
	promessas.mensagem.connect(hud.mostrar_mensagem)
	add_child(promessas)

	oferendas = Oferendas.new()
	oferendas.nivel = nivel
	oferendas.jogadora = jogadora
	oferendas.mensagem.connect(hud.mostrar_mensagem)
	add_child(oferendas)
	return true


func carregar_nivel(i: int) -> void:
	mundo = null
	sala_atual = ""
	hud.mapa.visible = false
	indice = i
	_limpar()
	if not _montar(NIVEIS[i]):
		return
	hud.definir_titulo("%s   ·   F6 Mundo · F1–F4 protótipos · R reinicia · Tab debug · F12 captura" % nivel.meta.get("nome", "Protótipo"))
	if nivel.meta.has("dica"):
		hud.mostrar_mensagem(nivel.meta["dica"], 6.0)


func _nova_camada(n: int, segue_camera: bool) -> CanvasLayer:
	var c := CanvasLayer.new()
	c.layer = n
	c.follow_viewport_enabled = segue_camera
	add_child(c)
	_camadas.append(c)
	return c


## Escuridão (camada 1): só em fases ou salas com "@escuro".
func _atualizar_escuridao() -> void:
	if nivel.meta.has("escuro"):
		if _escuridao == null:
			_camada_escuro = _nova_camada(1, false)
			_escuridao = ColorRect.new()
			_escuridao.size = Vector2(1920, 1080)
			_escuridao.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var mat := ShaderMaterial.new()
			mat.shader = load("res://src/escuridao.gdshader")
			_escuridao.material = mat
			_camada_escuro.add_child(_escuridao)
		(_escuridao.material as ShaderMaterial).set_shader_parameter("escuro", nivel.meta["escuro"])
	elif _escuridao != null:
		_camadas.erase(_camada_escuro)
		_camada_escuro.queue_free()
		_camada_escuro = null
		_escuridao = null


func _ajustar_camera(encaixar: bool) -> void:
	var t := nivel.tamanho_px()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(t.x)
	camera.limit_bottom = int(t.y)
	if encaixar:
		camera.global_position = jogadora.global_position + Vector2(jogadora.direcao * 90, -80)


# ------------------------------------------------------------ modo Mundo

func iniciar_mundo(do_zero := false) -> void:
	mundo = Mundo.new()
	mundo.carregar_dados()
	if do_zero:
		mundo.apagar_save()
	var save := mundo.carregar_save()
	var sala: String = save.get("sala", "C1-01")
	if not mundo.existe(sala):
		sala = "C1-01"
	if not mundo.existe(sala):
		hud.mostrar_mensagem("Não encontrei as salas do Mundo (niveis/salas/). Abrindo o protótipo P1.", 6.0)
		carregar_nivel(0)
		return
	_limpar()
	_montar(mundo.arquivo(sala))
	sala_atual = sala
	if save.has("x"):
		jogadora.tem_trancas = save.get("trancas", true)
		jogadora.tem_mao = save.get("mao", true)
		jogadora.pode_agarrar = jogadora.tem_mao
		jogadora.reiniciar_em(Vector2(save["x"], save["y"]))
		_ajustar_camera(true)
	respawn = jogadora.global_position
	respawn_sala = sala
	_area_atual = ""
	_ao_entrar_sala()
	if do_zero:
		hud.mostrar_mensagem("Mundo recomeçado do zero.", 3.0)


func _trocar_sala(codigo: String, ponto_mundo: Vector2) -> void:
	var local := ponto_mundo - mundo.origem(codigo)
	# Tira a sala antiga da árvore na hora: senão as paredes dela ainda colidem
	# neste quadro e empurram a protagonista de volta.
	nivel.brilho.get_parent().remove_child(nivel.brilho)
	nivel.brilho.queue_free()
	remove_child(nivel)
	nivel.queue_free()
	nivel = Nivel.new()
	add_child(nivel)
	move_child(nivel, 0)
	nivel.carregar(mundo.arquivo(codigo))
	_camada_brilho.add_child(nivel.brilho)
	jogadora.nivel = nivel
	promessas.nivel = nivel
	oferendas.nivel = nivel
	sala_atual = codigo
	var t := nivel.tamanho_px()
	jogadora.global_position = Vector2(clampf(local.x, 4.0, t.x - 4.0), clampf(local.y, 1.0, t.y - 1.0))
	# Subindo por uma passagem do teto (sem escada): um impulso para alcançar o chão da sala de cima.
	if local.y > t.y - 80.0 and jogadora.velocity.y < -50.0 and not jogadora.na_corda:
		jogadora.velocity.y = -760.0
	_ajustar_camera(true)
	_atualizar_escuridao()
	# As criaturas da dívida seguem a protagonista: reaparecem pela mesma passagem.
	for c in promessas.criaturas:
		c.origem = jogadora.global_position - Vector2(0, 40)
		c.voltar()
	_trava_transicao = 0.2
	_ao_entrar_sala()


## Tudo o que acontece ao entrar numa sala (inclusive a primeira).
func _ao_entrar_sala() -> void:
	_falas_ditas.clear()
	if not mundo.visitadas.has(sala_atual) and nivel.meta.has("tutorial"):
		hud.mostrar_mensagem(nivel.meta["tutorial"], 6.0)
	mundo.visitadas[sala_atual] = true
	promessas.registrar_sala(sala_atual)
	# Portões e pontes que já mudaram nesta sala.
	var g: Dictionary = mundo.grupos.get(sala_atual, {})
	for letra in g:
		nivel.ativar_grupo(letra, g[letra])
	# O corpo vale em qualquer sala.
	if not jogadora.tem_trancas:
		nivel.ativar_grupo("K", true)
		if nivel.altares_oferta.has("t"):
			nivel.registrar_oferenda("t")
	if not jogadora.tem_mao and nivel.altares_oferta.has("m"):
		nivel.registrar_oferenda("m")
	nivel.grupo_mudou.connect(_ao_mudar_grupo)

	var s: Dictionary = mundo.salas[sala_atual]
	if s["area"] != _area_atual:
		_area_atual = s["area"]
		hud.anunciar(mundo.nome_da_area(sala_atual))
	hud.definir_titulo("%s · %s   ·   M mapa · F8 recomeçar · F1–F4 protótipos · Tab debug" % [sala_atual, s["nome"]])
	hud.mapa.mundo = mundo
	hud.mapa.sala_atual = sala_atual
	hud.mapa.queue_redraw()


func _ao_mudar_grupo(letra: String, ativo: bool) -> void:
	if letra == "K":
		return  # a corda depende do corpo, não da sala
	if not mundo.grupos.has(sala_atual):
		mundo.grupos[sala_atual] = {}
	mundo.grupos[sala_atual][letra] = ativo


## Ela saiu dos limites da sala: para onde vai?
func _tentar_transicao(p_local: Vector2) -> void:
	var ponto := mundo.origem(sala_atual) + p_local
	var d := mundo.destino(sala_atual, ponto)
	if d.has("sala") and d["sala"] != "" and mundo.existe(d["sala"]):
		_trocar_sala(d["sala"], ponto)
		return
	if not d.is_empty():
		var area: Dictionary = mundo.areas.get(d["area"], {})
		var msg := "Este caminho leva a %s · %s, que ainda não foi construída." % [d["area"], area.get("nome", "?")]
		if String(d.get("requisito", "")) != "":
			msg += "  (Requisito: %s)" % d["requisito"]
		_avisar(msg)
	var t := nivel.tamanho_px()
	if p_local.y > t.y + 40.0:
		_renascer()  # caiu por um buraco sem destino
	else:
		jogadora.global_position = Vector2(clampf(p_local.x, 16.0, t.x - 16.0), clampf(p_local.y, 80.0, t.y - 2.0))
		jogadora.velocity = Vector2.ZERO


func _avisar(msg: String) -> void:
	if msg == _ultimo_aviso and Time.get_ticks_msec() / 1000.0 - _tempo_aviso < 3.0:
		return
	_ultimo_aviso = msg
	_tempo_aviso = Time.get_ticks_msec() / 1000.0
	hud.mostrar_mensagem(msg, 3.5)


## Descansar num altar: salva e vira o ponto de retorno.
func _descansar() -> void:
	respawn = nivel.pe_da_celula(Vector2i(nivel.coluna(jogadora.global_position), floori((jogadora.global_position.y - 10) / Nivel.TILE)))
	respawn_sala = sala_atual
	mundo.salvar({"sala": sala_atual, "x": respawn.x, "y": respawn.y,
		"trancas": jogadora.tem_trancas, "mao": jogadora.tem_mao})


# ------------------------------------------------------------ laço

func _physics_process(delta: float) -> void:
	if jogadora == null or _terminou:
		return
	_trava_transicao -= delta
	promessas.processar()
	oferendas.processar()
	if mundo:
		var t := nivel.tamanho_px()
		var p := jogadora.global_position
		if (p.x < 0.0 or p.x > t.x or p.y < 0.0 or p.y > t.y) and _trava_transicao <= 0.0:
			_tentar_transicao(p)
			return
	var cel := nivel.celula(jogadora.centro())
	var pes := nivel.celula(jogadora.global_position - Vector2(0, 10))
	if cel == "C" or pes == "C":
		var novo := nivel.pe_da_celula(Vector2i(nivel.coluna(jogadora.global_position), floori((jogadora.global_position.y - 10) / Nivel.TILE)))
		if novo != respawn:
			respawn = novo
			respawn_sala = sala_atual
			hud.mostrar_mensagem("Checkpoint.", 1.5)
	if cel == "~" or pes == "~" or (mundo == null and jogadora.global_position.y > nivel.tamanho_px().y + 200):
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
		hud.definir_dica("E — descansar e rezar no altar" if mundo else "E — rezar no altar")
	else:
		hud.definir_dica("")

	if hud.debug_visivel():
		hud.definir_debug("FPS %d   Luz: %s   Pulos fortes: %d   Tranças: %s   Mão: %s%s\n%s" % [
			Engine.get_frames_per_second(),
			"acesa" if jogadora.luz_acesa else "apagada",
			jogadora.pulos_fortes,
			"sim" if jogadora.tem_trancas else "ofertadas",
			"sim" if jogadora.tem_mao else "ofertada",
			("   Sala: %s   Visitadas: %d" % [sala_atual, mundo.visitadas.size()]) if mundo else "",
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
			KEY_F6:
				iniciar_mundo()
				return
			KEY_F8:
				if mundo:
					iniciar_mundo(true)
				return
			KEY_F12:
				_capturar_tela()
				return
	if _menu_altar != "":
		_input_menu(event)
		return
	if event.is_action_pressed("mapa") and mundo:
		hud.alternar_mapa()
	elif event.is_action_pressed("reiniciar"):
		if mundo:
			_renascer()
		else:
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


# ------------------------------------------------------------ interação

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


## F12: salva a tela sem os textos em C:\Dev\ex-voto\capturas.
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
	if mundo:
		_descansar()
	_menu_opcoes = promessas.opcoes_do_altar(altar)
	if _menu_opcoes.is_empty():
		hud.mostrar_mensagem("Você descansa. O caminho até aqui foi guardado." if mundo else "O altar está em silêncio.")
		return
	if promessas.fita_cheia():
		hud.mostrar_mensagem("A fita não tem mais nós. Pague uma promessa antes de fazer outra.")
		return
	_menu_altar = altar
	jogadora.controle_ativo = false
	var texto := "ALTAR%s\n\n" % ("  ·  caminho guardado" if mundo else "")
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
			if mundo:
				_descansar()  # a oferta fica guardada
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
	if mundo and respawn_sala != "" and respawn_sala != sala_atual:
		_trocar_sala(respawn_sala, mundo.origem(respawn_sala) + respawn)
	jogadora.reiniciar_em(respawn)
	camera.global_position = respawn
