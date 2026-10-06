class_name Andor
extends Node2D
## O Andor Vazio (biblia/05-criaturas.md, 5.5): um andor de procissão que caminha sozinho,
## com os lugares de ombro vazios. Ninguém o mata: ele se resolve quando a procissão termina.
## Vive fora das salas: a posição fica em coordenadas do mundo, para poder seguir a
## protagonista de sala em sala quando ela o guia com a corda (encontro 4).
## A origem é o meio da base, no chão.

enum Modo { NENHUM, FUNDO, CORTEJO, BLOQUEIO, GUIADO, PARADO }

const LARGURA := 320.0  # 8 tiles
const ALTURA := 280.0  # 7 tiles
## Altura dos varais (ombros). Embaixo deles não há ninguém: ajoelhada, ela passa por baixo.
const VARAIS := 64.0
const VEL_CORTEJO := 150.0
const VEL_GUIADO := 420.0
## Quanto da trilha dela o andor fica para trás (em pontos de 8 px).
const ATRASO := 45

var modo := Modo.NENHUM:
	set(v):
		modo = v
		visible = v != Modo.NENHUM
		if _forma:
			_forma.set_deferred("disabled", v != Modo.BLOQUEIO)
var pos_mundo := Vector2.ZERO
var direcao := -1  # para onde o cortejo anda
## Usado no cortejo, para acompanhar o chão (degraus, lombadas).
var nivel: Nivel

var _origem_sala := Vector2.ZERO
var _trilha: Array[Vector2] = []
var _t := 0.0
var _forma: CollisionShape2D


func _ready() -> void:
	var corpo := StaticBody2D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	_forma = CollisionShape2D.new()
	var ret := RectangleShape2D.new()
	ret.size = Vector2(LARGURA * 0.8, ALTURA)
	_forma.shape = ret
	_forma.position = Vector2(0, -ALTURA * 0.5)
	_forma.disabled = true
	corpo.add_child(_forma)
	visible = false


## A protagonista entrou numa sala: o andor passa a ser desenhado em relação a ela.
func entrar_sala(origem: Vector2) -> void:
	_origem_sala = origem
	position = pos_mundo - _origem_sala


func colocar(local: Vector2, novo_modo: Modo) -> void:
	pos_mundo = _origem_sala + local
	position = local
	_trilha.clear()
	modo = novo_modo


## Guiado pela corda: começa a seguir a trilha dela.
func amarrar() -> void:
	_trilha.clear()
	_trilha.append(pos_mundo)
	modo = Modo.GUIADO


func registrar_passo(p_mundo: Vector2) -> void:
	if _trilha.is_empty() or _trilha[-1].distance_to(p_mundo) > 8.0:
		_trilha.append(p_mundo)
		if _trilha.size() > 600:
			_trilha.remove_at(0)


## Retângulo do que machuca (dos varais para cima), em coordenadas da sala.
func area_perigosa() -> Rect2:
	return Rect2(position + Vector2(-LARGURA * 0.5, -ALTURA), Vector2(LARGURA, ALTURA - VARAIS + 8.0))


func _process(delta: float) -> void:
	_t += delta
	match modo:
		Modo.FUNDO:
			pos_mundo.x += direcao * VEL_CORTEJO * 0.5 * delta
		Modo.CORTEJO:
			pos_mundo.x += direcao * VEL_CORTEJO * delta
			if nivel:
				var chao := nivel.chao_em(pos_mundo.x - _origem_sala.x, pos_mundo.y - _origem_sala.y)
				pos_mundo.y = lerpf(pos_mundo.y, _origem_sala.y + chao, 1.0 - exp(-delta * 6.0))
		Modo.GUIADO:
			var alvo := _trilha[maxi(0, _trilha.size() - 1 - ATRASO)]
			pos_mundo = pos_mundo.move_toward(alvo, VEL_GUIADO * delta)
	position = pos_mundo - _origem_sala
	queue_redraw()


func _draw() -> void:
	var fundo := modo == Modo.FUNDO
	var a := 0.35 if fundo else 1.0
	var escala := 0.45 if fundo else 1.0
	draw_set_transform(Vector2(0, sin(_t * 2.2) * 3.0), sin(_t * 1.1) * 0.025, Vector2(escala, escala))
	var madeira := Color(Nivel.COR_PORTAO, a)
	var ouro := Color(Nivel.COR_OURO, a)
	var cera := Color(Nivel.COR_CERA, a)
	var w := LARGURA * 0.5
	# Os varais, com os lugares de ombro vazios (marcas onde deveria haver gente).
	for dy in [-VARAIS, -VARAIS + 10.0]:
		draw_line(Vector2(-w - 70, dy), Vector2(w + 70, dy), madeira, 6)
	for i in 6:
		var x := -w - 50 + i * (LARGURA + 100) / 5.0
		draw_line(Vector2(x, -VARAIS + 14), Vector2(x, -VARAIS + 24), Color(madeira, a * 0.5), 2)
	# A base e o andor.
	draw_rect(Rect2(-w + 30, -VARAIS - 40, LARGURA - 60, 34), madeira)
	draw_rect(Rect2(-w + 30, -VARAIS - 40, LARGURA - 60, 34), ouro, false, 3)
	for x in [-w + 50, w - 50]:
		draw_line(Vector2(x, -VARAIS - 40), Vector2(x, -ALTURA + 30), ouro, 4)
	draw_arc(Vector2(0, -ALTURA + 30), w - 50, PI, TAU, 24, ouro, 4)
	# A imagem de cera no andor, e o resplendor dourado.
	draw_rect(Rect2(-20, -VARAIS - 136, 40, 96), cera)
	draw_circle(Vector2(0, -VARAIS - 150), 16, cera)
	draw_arc(Vector2(0, -VARAIS - 150), 26, 0, TAU, 24, ouro, 3)
	# Cera escorrendo pela base.
	for i in 5:
		var x := -w + 50 + i * 50.0
		draw_line(Vector2(x, -VARAIS - 6), Vector2(x, -VARAIS - 6 + 10 + (i % 3) * 8), cera, 4)
	draw_set_transform(Vector2.ZERO)
