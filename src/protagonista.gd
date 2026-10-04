class_name Protagonista
extends CharacterBody2D
## Movimento da protagonista: andar, correr, pular, agarrar bordas, ajoelhar.
## A origem do nó fica nos pés. Todos os números são para ajustar em playtest
## (aparecem no Inspetor se você transformar isto numa cena).

signal aterrissou(altura_queda: float)

const LARGURA := 26.0
const ALTURA := 70.0
const ALTURA_JOELHOS := 36.0

@export var vel_andar := 260.0
@export var vel_correr := 420.0
@export var vel_joelhos := 70.0
@export var vel_carregando := 200.0
@export var aceleracao := 2200.0
@export var desaceleracao := 2600.0
@export var gravidade := 2200.0
@export var vel_pulo := 650.0
@export var vel_pulo_forte := 980.0
@export var queda_max := 1400.0
@export var tempo_coyote := 0.1
@export var tempo_buffer := 0.12
## Quanto acima da cabeça ela alcança para se agarrar numa borda.
@export var alcance_agarrar := 34.0
@export var raio_luz := 300.0
@export var raio_sem_luz := 70.0
@export var vel_corda := 150.0

# Capacidades: as ofertas do corpo (P3) desligam algumas destas.
var pode_agarrar := true
var pode_correr := true
var pode_pular := true
# O corpo: o que ainda não foi ofertado.
var tem_trancas := true
var tem_mao := true

## Usado para achar a corda (tranças) no mapa.
var nivel: Nivel

var controle_ativo := true
var luz_acesa := true
var carregando := false
var ajoelhada := false
var pendurada := false
var na_corda := false
var correndo := false
var pulos_fortes := 0
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
	return raio_luz if luz_acesa else raio_sem_luz


func esta_correndo() -> bool:
	return correndo and absf(velocity.x) > vel_andar + 5.0


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
	_espera_corda -= delta
	if controle_ativo and Input.is_action_just_pressed("luz"):
		definir_luz(not luz_acesa)
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
		velocity.y = minf(velocity.y + gravidade * delta, queda_max)

	var eixo := 0.0
	if controle_ativo:
		eixo = Input.get_axis("mover_esquerda", "mover_direita")
	if eixo != 0.0:
		direcao = 1 if eixo > 0.0 else -1

	# Ajoelhar: segurar para baixo no chão. Só levanta se houver espaço.
	var quer_ajoelhar := controle_ativo and no_chao and Input.is_action_pressed("ajoelhar")
	if quer_ajoelhar and not ajoelhada:
		_definir_ajoelhada(true)
	elif not quer_ajoelhar and ajoelhada and _cabe(global_position, ALTURA):
		_definir_ajoelhada(false)

	correndo = controle_ativo and pode_correr and not carregando and not ajoelhada \
		and eixo != 0.0 and Input.is_action_pressed("correr")
	var vel := vel_andar
	if ajoelhada:
		vel = vel_joelhos
	elif carregando:
		vel = vel_carregando
	elif correndo:
		vel = vel_correr
	var acel := aceleracao if eixo != 0.0 else desaceleracao
	if not no_chao:
		acel *= 0.6
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
		_buffer = 0.0
		_coyote = 0.0
	# Pulo variável: soltar o botão cedo corta a subida.
	if velocity.y < 0.0 and not (controle_ativo and Input.is_action_pressed("pular")):
		velocity.y += gravidade * delta * 1.5

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
	var c := nivel.celula(centro())
	return c == "L" or (c == "K" and nivel.grupos_ativos["K"])


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
	if acima != "K" and acima != "L" and global_position.y - 1.0 >= 0.0:
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
		draw_circle(chama, 4, Color(1.0, 0.78, 0.3))
	if carregando:
		draw_rect(Rect2(-8, -h - 22, 16, 22), Nivel.COR_CERA)

	# Fita no pulso: o único vermelho do jogo.
	var pulso := Vector2(-direcao * (LARGURA * 0.5 + 1), -h * 0.5 + 4)
	draw_rect(Rect2(pulso.x - 4, pulso.y - 2, 8, 4), Color(0.72, 0.07, 0.07))
	for i in nos.size():
		draw_circle(pulso + Vector2(-direcao * 4, 7 + i * 8), 4.0, nos[i])
