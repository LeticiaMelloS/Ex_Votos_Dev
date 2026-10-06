class_name Protagonista
extends CharacterBody2D
## Movimento da protagonista: andar, pular, agarrar bordas, ajoelhar; a vela (luz e chama) e a vida.
## A origem do nó fica nos pés. Todos os números são para ajustar em playtest
## (aparecem no Inspetor se você transformar isto numa cena).

signal aterrissou(altura_queda: float)
## A chama da vela atingiu esta área (em coordenadas do nível). forte = vela da irmandade.
signal golpeou(area: Rect2, forte: bool)
## A vida chegou a zero: a vela se apagou.
signal apagou
signal pulou(forte: bool)
## Tocou a matraca neste ponto (criaturas que ouvem reagem).
signal fez_barulho(ponto: Vector2)

const LARGURA := 26.0
const ALTURA := 70.0
const ALTURA_JOELHOS := 36.0

# Movimento inspirado em Hollow Knight: velocidade única, quase sem inércia,
# pulo alto e controlado (soltar o botão corta a subida), queda rápida.
@export var vel_andar := 330.0  # velocidade única: não há corrida
@export var vel_joelhos := 80.0
@export var vel_carregando := 230.0
@export var aceleracao := 5000.0
@export var desaceleracao := 6500.0
@export var controle_no_ar := 0.9  # fração da aceleração no ar
@export var gravidade := 2400.0  # subindo
@export var gravidade_queda := 3400.0  # caindo
@export var vel_pulo := 930.0  # ~4,5 tiles de altura com o botão segurado
@export var vel_corte_pulo := 200.0  # soltar o botão limita a subida a esta velocidade
@export var vel_pulo_forte := 1250.0
@export var queda_max := 1150.0
@export var tempo_coyote := 0.08
@export var tempo_buffer := 0.12
## Quanto acima da cabeça ela alcança para se agarrar numa borda.
@export var alcance_agarrar := 34.0
@export var raio_luz := 300.0
@export var raio_sem_luz := 70.0
@export var vel_corda := 210.0

# Combate de sobrevivência (biblia/04-sistemas.md, 4.4): a vela é a arma, e a vida aparece na chama.
@export var vida_max := 3
@export var alcance_chama := 60.0  # ~1,5 tile à frente
@export var recarga_chama := 0.4
@export var duracao_chama := 0.15
@export var tempo_invulneravel := 1.0

# Capacidades: as ofertas do corpo (P3) desligam algumas destas.
var pode_agarrar := true
var pode_pular := true
# O corpo: o que ainda não foi ofertado.
var tem_trancas := true
var tem_mao := true
## Vela da irmandade: a chama derrete a cera velha.
var vela_forte := false
## A matraca (C2-09): faz barulho, que atrai e assusta criaturas.
var tem_matraca := false
var vida := 3

## Usado para achar a corda (tranças) no mapa.
var nivel: Nivel

var controle_ativo := true
var luz_acesa := true
var carregando := false
var ajoelhada := false
var pendurada := false
var na_corda := false
var pulos_fortes := 0
## Enquanto > 0, a subida não é cortada ao soltar o botão (impulso ao passar por um buraco no teto).
var impulso := 0.0
var direcao := 1
## Cores dos nós da fita no pulso (uma por promessa aberta).
var nos: Array[Color] = []

var _coyote := 0.0
var _buffer := 0.0
var _no_ar := false
var _y_min := 0.0
var _espera_agarrar := 0.0
var _espera_corda := 0.0
var _subindo := false
var _tween: Tween
var _parede_x := 0.0
var _borda_y := 0.0
var _recarga := 0.0
var _golpe := 0.0
var _invulneravel := 0.0
var _empurrao := 0.0
var _barulho := 0.0
var _forma := CollisionShape2D.new()
var _ret := RectangleShape2D.new()


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 6.0
	_ret.size = Vector2(LARGURA, ALTURA)
	_forma.shape = _ret
	_forma.position = Vector2(0, -ALTURA * 0.5)
	add_child(_forma)


func altura_atual() -> float:
	return ALTURA_JOELHOS if ajoelhada else ALTURA


func centro() -> Vector2:
	return global_position - Vector2(0, altura_atual() * 0.5)


func raio_da_luz() -> float:
	if not luz_acesa:
		return raio_sem_luz
	# A chama encolhe com a vida.
	return raio_luz * (0.55 + 0.45 * float(vida) / vida_max)


## Área que a chama atinge agora, em coordenadas do nível.
func area_da_chama() -> Rect2:
	var c := centro()
	var x := global_position.x + direcao * (LARGURA * 0.5)
	return Rect2(minf(x, x + direcao * alcance_chama), c.y - 32.0, alcance_chama, 64.0)


func golpear() -> void:
	if _recarga > 0.0 or not luz_acesa or carregando or pendurada or _subindo:
		return
	_recarga = recarga_chama
	_golpe = duracao_chama
	golpeou.emit(area_da_chama(), vela_forte)


## Leva um golpe vindo de `origem`. Devolve false se estava protegida (logo depois de outro golpe).
func receber_dano(origem: Vector2) -> bool:
	if _invulneravel > 0.0 or vida <= 0:
		return false
	vida -= 1
	_invulneravel = tempo_invulneravel
	if pendurada:
		_soltar()
	if not (_subindo or na_corda):
		var lado := signf(global_position.x - origem.x)
		if lado == 0.0:
			lado = -direcao
		velocity = Vector2(lado * 380.0, -420.0)
		_empurrao = 0.18
	if vida <= 0:
		apagou.emit()
	return true


func curar() -> void:
	vida = vida_max
	_invulneravel = 0.0


func definir_luz(acesa: bool) -> void:
	luz_acesa = acesa


## Volta ao estado neutro (usado ao renascer no checkpoint).
func reiniciar_em(pos: Vector2) -> void:
	if _tween:
		_tween.kill()
	_subindo = false
	pendurada = false
	na_corda = false
	_no_ar = false
	velocity = Vector2.ZERO
	global_position = pos
	_definir_ajoelhada(false)


func _physics_process(delta: float) -> void:
	_espera_agarrar -= delta
	impulso -= delta
	_espera_corda -= delta
	_recarga -= delta
	_golpe -= delta
	_invulneravel -= delta
	_empurrao -= delta
	if controle_ativo and Input.is_action_just_pressed("luz"):
		definir_luz(not luz_acesa)
	if controle_ativo and Input.is_action_just_pressed("chama"):
		golpear()
	_barulho -= delta
	if controle_ativo and tem_matraca and _barulho <= 0.0 and Input.is_action_just_pressed("matraca"):
		_barulho = 0.8
		fez_barulho.emit(centro())
	if _subindo:
		return
	if pendurada:
		_processar_pendurada()
		queue_redraw()
		return
	if na_corda:
		_processar_corda()
		queue_redraw()
		return
	if controle_ativo and _espera_corda <= 0.0 and not ajoelhada and _corda_aqui() 			and Input.is_action_pressed("pular"):
		_agarrar_corda()
		queue_redraw()
		return

	var no_chao := is_on_floor()
	if no_chao:
		if _no_ar:
			_no_ar = false
			aterrissou.emit(global_position.y - _y_min)
		_coyote = tempo_coyote
	else:
		if not _no_ar:
			_no_ar = true
			_y_min = global_position.y
		_y_min = minf(_y_min, global_position.y)
		_coyote -= delta
		var g := gravidade if velocity.y < 0.0 else gravidade_queda
		velocity.y = minf(velocity.y + g * delta, queda_max)

	var eixo := 0.0
	if controle_ativo and _empurrao <= 0.0:
		eixo = Input.get_axis("mover_esquerda", "mover_direita")
	if eixo != 0.0:
		direcao = 1 if eixo > 0.0 else -1

	# Ajoelhar: segurar para baixo no chão. Só levanta se houver espaço.
	var quer_ajoelhar := controle_ativo and no_chao and Input.is_action_pressed("ajoelhar")
	if quer_ajoelhar and not ajoelhada:
		_definir_ajoelhada(true)
	elif not quer_ajoelhar and ajoelhada and _cabe(global_position, ALTURA):
		_definir_ajoelhada(false)

	var vel := vel_andar
	if ajoelhada:
		vel = vel_joelhos
	elif carregando:
		vel = vel_carregando
	var acel := aceleracao if eixo != 0.0 else desaceleracao
	if _empurrao > 0.0:
		acel = 0.0  # o empurrão do golpe não é freado na hora
	if not no_chao:
		acel *= controle_no_ar
	velocity.x = move_toward(velocity.x, eixo * vel, acel * delta)

	# Pulo com "coyote time" (pequena tolerância depois de sair da borda)
	# e "buffer" (aperto um pouco antes de tocar o chão também vale).
	if controle_ativo and Input.is_action_just_pressed("pular"):
		_buffer = tempo_buffer
	else:
		_buffer -= delta
	if _buffer > 0.0 and _coyote > 0.0 and pode_pular and not ajoelhada:
		var v := vel_pulo
		if pulos_fortes > 0:
			v = vel_pulo_forte
			pulos_fortes -= 1
		velocity.y = -v
		pulou.emit(v == vel_pulo_forte)
		_buffer = 0.0
		_coyote = 0.0
	# Pulo variável: soltar o botão cedo corta a subida.
	if velocity.y < 0.0 and impulso <= 0.0 and not (controle_ativo and Input.is_action_pressed("pular")):
		velocity.y = maxf(velocity.y, -vel_corte_pulo)

	move_and_slide()

	# Ajoelhada, ela sobe degraus de um tile devagar (pagadores de promessa na escadaria).
	if ajoelhada and is_on_floor() and is_on_wall() and eixo != 0.0:
		_subir_degrau()
	elif not is_on_floor() and controle_ativo and pode_agarrar and not carregando \
			and _espera_agarrar <= 0.0 and velocity.y > -150.0 and eixo != 0.0:
		_tentar_agarrar(direcao)
	queue_redraw()


func _definir_ajoelhada(v: bool) -> void:
	ajoelhada = v
	var h := altura_atual()
	_ret.size = Vector2(LARGURA, h)
	_forma.position = Vector2(0, -h * 0.5)


## Existe espaço livre para um corpo desta altura com os pés em `pes`?
func _cabe(pes: Vector2, h: float) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(LARGURA - 2.0, h - 2.0)
	q.shape = r
	q.transform = Transform2D(0.0, pes - Vector2(0, h * 0.5 + 1.0))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func _tentar_agarrar(dir: int) -> void:
	var espaco := get_world_2d().direct_space_state
	var topo := global_position.y - ALTURA
	# 1) Há parede à frente, na altura do peito?
	var de := Vector2(global_position.x, topo + 30.0)
	var ate := de + Vector2(dir * (LARGURA * 0.5 + 8.0), 0)
	var hit := espaco.intersect_ray(PhysicsRayQueryParameters2D.create(de, ate, 1, [get_rid()]))
	if hit.is_empty():
		return
	var parede_x: float = hit.position.x
	# 2) Onde fica o topo dessa parede? Raio de cima para baixo, logo depois dela.
	var x_borda := parede_x + dir * 6.0
	var cima := Vector2(x_borda, topo - alcance_agarrar)
	var pq := PhysicsPointQueryParameters2D.new()
	pq.position = cima
	pq.collision_mask = 1
	if not espaco.intersect_point(pq, 1).is_empty():
		return  # parede alta demais
	var hit2 := espaco.intersect_ray(PhysicsRayQueryParameters2D.create(cima, Vector2(x_borda, topo + 30.0), 1, [get_rid()]))
	if hit2.is_empty():
		return
	_parede_x = parede_x
	_borda_y = hit2.position.y
	pendurada = true
	velocity = Vector2.ZERO
	global_position = Vector2(parede_x - dir * (LARGURA * 0.5 + 0.5), _borda_y - 10.0 + ALTURA)


func _processar_pendurada() -> void:
	if not controle_ativo:
		return
	var eixo := Input.get_axis("mover_esquerda", "mover_direita")
	if Input.is_action_just_pressed("ajoelhar") or (eixo != 0.0 and signf(eixo) != direcao):
		_soltar()
	elif Input.is_action_just_pressed("pular"):
		_subir_borda()


func _subir_degrau() -> void:
	var destino := global_position + Vector2(direcao * 14.0, -Nivel.TILE - 0.5)
	if not _cabe(destino, ALTURA_JOELHOS):
		return
	_subindo = true
	_tween = create_tween()
	_tween.tween_property(self, "global_position", destino, 0.35)
	_tween.tween_callback(_fim_da_subida.bind(true))


func _corda_aqui() -> bool:
	if nivel == null:
		return false
	return _escada(nivel.celula(centro()), centro())


## Escada de mão, corda (depois das tranças) ou um portão aberto no meio de uma escada (a cripta).
func _escada(c: String, p: Vector2) -> bool:
	if c == "L" or (c == "K" and nivel.grupos_ativos["K"]):
		return true
	if c == "D" and not nivel.grupos_ativos["D"]:
		var cima := nivel.celula(p - Vector2(0, Nivel.TILE))
		var baixo := nivel.celula(p + Vector2(0, Nivel.TILE))
		return "LK".contains(cima) or "LK".contains(baixo)
	return false


func _agarrar_corda() -> void:
	na_corda = true
	pendurada = false
	velocity = Vector2.ZERO
	global_position.x = (nivel.coluna(global_position) + 0.5) * Nivel.TILE


## Na corda: pular sobe, ajoelhar desce, qualquer direção solta com um pulinho.
func _processar_corda() -> void:
	velocity = Vector2.ZERO
	if not controle_ativo:
		return
	var eixo := Input.get_axis("mover_esquerda", "mover_direita")
	if eixo != 0.0:
		direcao = 1 if eixo > 0.0 else -1
		na_corda = false
		_espera_corda = 0.35
		velocity = Vector2(eixo * vel_andar, -200.0)
		return
	var dy := 0.0
	if Input.is_action_pressed("pular"):
		dy -= 1.0
	if Input.is_action_pressed("ajoelhar"):
		dy += 1.0
	velocity = Vector2(0, dy * vel_corda)
	move_and_slide()
	if dy > 0.0 and is_on_floor():
		na_corda = false
		return
	# Os pés não passam do alto da última célula de corda ou escada.
	# (No modo Mundo, a escada continua na sala de cima: quem cuida da troca é o main.)
	var acima := nivel.celula(global_position - Vector2(0, 1))
	if not _escada(acima, global_position - Vector2(0, 1)) and global_position.y - 1.0 >= 0.0:
		var linha := floori((global_position.y - 1.0) / Nivel.TILE)
		global_position.y = (linha + 1) * Nivel.TILE


func _soltar() -> void:
	pendurada = false
	_espera_agarrar = 0.3


func _subir_borda() -> void:
	var destino := Vector2(_parede_x + direcao * (LARGURA * 0.5 + 4.0), _borda_y - 0.5)
	var agachada := false
	if not _cabe(destino, ALTURA):
		if not _cabe(destino, ALTURA_JOELHOS):
			return  # não tem espaço lá em cima
		agachada = true
	_subindo = true
	pendurada = false
	_tween = create_tween()
	_tween.tween_property(self, "global_position:y", destino.y, 0.16)
	_tween.tween_property(self, "global_position:x", destino.x, 0.1)
	_tween.tween_callback(_fim_da_subida.bind(agachada))


func _fim_da_subida(agachada: bool) -> void:
	_subindo = false
	_no_ar = false
	velocity = Vector2.ZERO
	if agachada:
		_definir_ajoelhada(true)


## Posição da chama da vela, relativa aos pés.
func posicao_vela() -> Vector2:
	var h := altura_atual()
	# Sem a mão da frente, a vela passa para a outra mão.
	var lado := direcao if tem_mao else -direcao
	if pendurada or na_corda:
		return Vector2(lado * (LARGURA * 0.5), -h - 10)
	return Vector2(lado * (LARGURA * 0.5 + 3), -h * 0.5 - 16)


func _draw() -> void:
	var h := altura_atual()
	var cor := Color(0.07, 0.06, 0.06)
	# Logo depois de um golpe, ela pisca.
	modulate.a = 0.35 if _invulneravel > 0.0 and fmod(_invulneravel, 0.16) < 0.08 else 1.0
	draw_rect(Rect2(-LARGURA * 0.5, -h, LARGURA, h), cor)
	# Olho: mostra para onde ela olha.
	draw_rect(Rect2(direcao * 5 - 3, -h + 9, 6, 5), Color(0.86, 0.82, 0.74))
	if tem_trancas:
		draw_line(Vector2(-direcao * 9, -h + 12), Vector2(-direcao * 15, -h + 34), cor, 4)
	else:
		# Cabelo curto, cortado rente.
		draw_line(Vector2(-direcao * 10, -h + 4), Vector2(-direcao * 14, -h + 14), cor, 4)
	if not tem_mao:
		# Cera, não sangue: o braço da frente termina numa superfície lisa de cera.
		draw_circle(Vector2(direcao * (LARGURA * 0.5 + 1), -h * 0.5), 4.0, Nivel.COR_CERA)

	# Vela (cera) e chama.
	var chama := posicao_vela()
	draw_line(chama + Vector2(0, 16), chama + Vector2(0, 4), Nivel.COR_CERA, 5)
	if luz_acesa:
		# A vida aparece no tamanho da chama; com 1 de vida, ela treme.
		var r := 2.0 + 2.5 * float(vida) / vida_max
		if vida == 1:
			r += sin(Time.get_ticks_msec() * 0.03) * 0.8
		draw_circle(chama, r + 1.5, Color(1.0, 0.55, 0.15, 0.5))
		draw_circle(chama, r, Color(1.0, 0.78, 0.3))
	if _golpe > 0.0:
		# O golpe de chama: uma língua de fogo à frente.
		var a := area_da_chama()
		var base := a.get_center() - global_position
		var cor_fogo := Color(1.0, 0.9, 0.5) if vela_forte else Color(1.0, 0.7, 0.25)
		for i in 3:
			var p := base + Vector2(direcao * (i - 1) * 16.0, sin(i * 2.0 + Time.get_ticks_msec() * 0.05) * 6.0)
			draw_circle(p, 16.0 - absf(i - 1) * 4.0, Color(cor_fogo, 0.75))
	if carregando:
		draw_rect(Rect2(-8, -h - 22, 16, 22), Nivel.COR_CERA)

	if _barulho > 0.2:
		# O som da matraca: anéis que se abrem.
		var raio := (0.8 - _barulho) * 400.0
		draw_arc(Vector2(0, -h * 0.5), raio, 0, TAU, 32, Color(0.2, 0.15, 0.1, _barulho), 3)
		draw_arc(Vector2(0, -h * 0.5), raio * 0.6, 0, TAU, 32, Color(0.2, 0.15, 0.1, _barulho), 2)
	# Fita no pulso: o único vermelho do jogo.
	var pulso := Vector2(-direcao * (LARGURA * 0.5 + 1), -h * 0.5 + 4)
	draw_rect(Rect2(pulso.x - 4, pulso.y - 2, 8, 4), Color(0.72, 0.07, 0.07))
	for i in nos.size():
		draw_circle(pulso + Vector2(-direcao * 4, 7 + i * 8), 4.0, nos[i])
