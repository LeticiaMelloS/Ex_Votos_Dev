class_name CriaturaCera
extends CharacterBody2D
## Criaturas de cera do mundo (biblia/05-criaturas.md).
## A chama derrete; a poça se reforma depois de um tempo (derreter compra tempo, só pagar resolve).
## A origem do nó fica nos pés (ou, no teto, no ponto mais baixo da criatura).
##   mãozinha  — anda pelo teto e cai quando a protagonista passa embaixo; no chão, rasteja atrás dela.
##   ajoelhado — rasteja devagar e sem parar; cabe nos túneis de 1 tile; vira nas beiradas.

## Derreteu e soltou cera (uma vez por descanso).
signal soltou_cera(quantidade: int)

const TIPOS := {
	"maozinha": {"vida": 1, "vel": 75.0, "tam": Vector2(26, 20), "cera": 2},
	"ajoelhado": {"vida": 2, "vel": 55.0, "tam": Vector2(30, 32), "cera": 3},
}
const GRAVIDADE := 2200.0
const VISTA := 8 * Nivel.TILE  # distância em que ela percebe a protagonista

var tipo := "maozinha"
var alvo: Protagonista
var nivel: Nivel
var vida := 1
var poca := false

var _dir := 1
var _no_teto := false
var _reforma := 0.0
var _piscar := 0.0
var _ja_soltou := false
var _t := 0.0
var _chao_sombra := 0.0
var _forma := CollisionShape2D.new()


## Coloca a criatura na célula do mapa. Mãozinha sob um teto começa pendurada nele.
func preparar(cel: Vector2i) -> void:
	if not TIPOS.has(tipo):
		tipo = "maozinha"
	vida = TIPOS[tipo]["vida"]
	_dir = 1 if (cel.x + cel.y) % 2 == 0 else -1
	var tam: Vector2 = TIPOS[tipo]["tam"]
	if tipo == "maozinha" and _solido_cel(cel + Vector2i(0, -1)):
		_no_teto = true
		position = Vector2((cel.x + 0.5) * Nivel.TILE, cel.y * Nivel.TILE + tam.y)
	else:
		position = nivel.pe_da_celula(cel)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 6.0
	var ret := RectangleShape2D.new()
	ret.size = TIPOS[tipo]["tam"]
	_forma.shape = ret
	_forma.position = Vector2(0, -ret.size.y * 0.5)
	add_child(_forma)
	_forma.disabled = _no_teto


func ativa() -> bool:
	return not poca


## Retângulo do corpo, em coordenadas do nível.
func retangulo() -> Rect2:
	var tam: Vector2 = TIPOS[tipo]["tam"]
	return Rect2(global_position - Vector2(tam.x * 0.5, tam.y), tam)


## A chama acertou. `dir` é para onde a chama empurra.
func ferir(dir: int) -> void:
	if poca:
		return
	vida -= 1
	_piscar = 0.15
	if _no_teto:
		_cair()
	velocity.x = dir * 260.0
	if vida <= 0:
		_derreter()


func _derreter() -> void:
	poca = true
	_reforma = randf_range(20.0, 40.0)
	if _no_teto:
		_cair()
	if not _ja_soltou:
		_ja_soltou = true
		soltou_cera.emit(TIPOS[tipo]["cera"])


## Descanso no altar: tudo se reforma, e volta a soltar cera.
func reformar() -> void:
	_ja_soltou = false
	if poca:
		_reforma = 0.0


func _cair() -> void:
	_no_teto = false
	_forma.set_deferred("disabled", false)


func _physics_process(delta: float) -> void:
	_t += delta
	_piscar -= delta
	queue_redraw()
	if poca:
		_reforma -= delta
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		velocity.y = minf(velocity.y + GRAVIDADE * delta, 900.0)
		move_and_slide()
		if _reforma <= 0.0:
			poca = false
			vida = TIPOS[tipo]["vida"]
		return
	if _no_teto:
		_andar_no_teto(delta)
		return
	velocity.y = minf(velocity.y + GRAVIDADE * delta, 900.0)
	var vel: float = TIPOS[tipo]["vel"]
	var dif := alvo.global_position - global_position if alvo else Vector2(9999, 0)
	if absf(dif.x) < VISTA and absf(dif.y) < 3 * Nivel.TILE and absf(dif.x) > 4.0:
		_dir = 1 if dif.x > 0.0 else -1
	if is_on_floor():
		# Vira na parede e na beirada (é previsível: quem observa, desvia).
		var meio: float = TIPOS[tipo]["tam"].x * 0.5 + 4.0
		var frente := global_position + Vector2(_dir * meio, -10.0)
		var abaixo := global_position + Vector2(_dir * meio, 8.0)
		if _solido(frente) or not _solido(abaixo):
			_dir = -_dir
		velocity.x = move_toward(velocity.x, _dir * vel, 1200.0 * delta)
	move_and_slide()


func _andar_no_teto(delta: float) -> void:
	var vel: float = TIPOS[tipo]["vel"]
	var tam: Vector2 = TIPOS[tipo]["tam"]
	var meio := tam.x * 0.5 + 2.0
	var topo := global_position.y - tam.y
	var adiante := global_position.x + _dir * (meio + 2.0)
	if _solido(Vector2(adiante, topo + 4.0)) or not _solido(Vector2(adiante, topo - 4.0)):
		_dir = -_dir
	global_position.x += _dir * vel * delta
	# Cai quando ela passa embaixo, com o caminho livre até ela.
	if alvo and absf(alvo.global_position.x - global_position.x) < 26.0 \
			and alvo.global_position.y > global_position.y and _coluna_livre(alvo.global_position.y - 40.0):
		_cair()
	# A sombra no chão avisa que há algo no teto.
	_chao_sombra = _chao_abaixo()


func _coluna_livre(ate_y: float) -> bool:
	var y := global_position.y + 4.0
	while y < ate_y:
		if _solido(Vector2(global_position.x, y)):
			return false
		y += Nivel.TILE * 0.5
	return true


func _chao_abaixo() -> float:
	var y := global_position.y + 4.0
	var limite := nivel.tamanho_px().y
	while y < limite:
		if _solido(Vector2(global_position.x, y)):
			return floorf(y / Nivel.TILE) * Nivel.TILE - global_position.y
		y += Nivel.TILE
	return 0.0


## Pelo mapa (usado antes de a criatura entrar na cena).
func _solido_cel(c: Vector2i) -> bool:
	return "#DFwW".contains(nivel.celula(Vector2((c.x + 0.5) * Nivel.TILE, (c.y + 0.5) * Nivel.TILE)))


func _solido(p: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


func _draw() -> void:
	var cor := Nivel.COR_CERA
	if _piscar > 0.0:
		cor = Color(1, 1, 1)
	var escuro := Color(0.12, 0.09, 0.06)
	if poca:
		# Poça de cera; cresce de volta quando falta pouco para se reformar.
		var volta := clampf(1.0 - _reforma / 6.0, 0.0, 1.0)
		draw_rect(Rect2(-18, -5 - volta * 10.0, 36, 5 + volta * 10.0), Color(cor, 0.85))
		return
	match tipo:
		"maozinha":
			if _no_teto and _chao_sombra > 0.0:
				draw_rect(Rect2(-12, _chao_sombra - 4, 24, 4), Color(0, 0, 0, 0.35))
			# No teto, os dedos apontam para baixo; no chão, para cima.
			var palma := Rect2(-11, -20, 22, 12) if _no_teto else Rect2(-11, -12, 22, 12)
			draw_rect(palma, cor)
			for i in 4:
				var dx := -10.0 + i * 6.5
				var comp := 8.0 + sin(_t * 8.0 + i) * 2.0
				if _no_teto:
					draw_rect(Rect2(dx, palma.end.y, 4, comp), cor)
				else:
					draw_rect(Rect2(dx, palma.position.y - comp, 4, comp), cor)
		"ajoelhado":
			# Romeiro de cera de joelhos: tronco curvado, cabeça baixa, joelhos no chão.
			var passo := sin(_t * 5.0) * 2.0
			draw_rect(Rect2(-12, -6, 24, 6), cor)  # joelhos e canelas
			draw_rect(Rect2(-8 * _dir - 4, -24, 12, 18), cor)  # tronco
			draw_circle(Vector2(_dir * 6, -26 + passo * 0.5), 6.5, cor)  # cabeça
			draw_circle(Vector2(_dir * 8, -27 + passo * 0.5), 1.6, escuro)
			for i in 3:
				draw_rect(Rect2(-10 + i * 8, -2, 3, 6 + i % 2 * 3), cor)  # cera escorrendo
