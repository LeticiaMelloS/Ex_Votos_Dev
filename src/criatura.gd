class_name Criatura
extends Node2D
## Criatura de cera que nasce de uma promessa não paga.
## Atravessa paredes, é mais lenta que a protagonista andando e mais rápida
## que ela ajoelhada. Quando a alcança, ela volta ao último checkpoint.

signal pegou

var alvo: Protagonista
var origem := Vector2.ZERO
var altar := ""
var promessa_id := ""
## true enquanto a jogadora tenta pagar a dívida atrasada.
var quitando := false
var velocidade := 115.0

var _espera := 1.8  # tempo "nascendo" antes de começar a perseguir
var _t := 0.0
var _dissolvendo := false


func _ready() -> void:
	global_position = origem


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _dissolvendo:
		modulate.a -= delta * 0.6
		position.y += delta * 30.0
		if modulate.a <= 0.0:
			queue_free()
		return
	if _espera > 0.0:
		_espera -= delta
		return
	if alvo == null:
		return
	var destino := alvo.centro()
	var dif := destino - global_position
	if dif.length() < 30.0:
		pegou.emit()
		voltar()
		return
	var vel := velocidade * (0.55 if quitando else 1.0)
	global_position += dif.normalized() * vel * delta


func voltar() -> void:
	global_position = origem
	_espera = 2.5


func dissolver() -> void:
	_dissolvendo = true


func _draw() -> void:
	var cor := Nivel.COR_CERA
	if quitando:
		cor = cor.lerp(Color(1, 1, 1), 0.4)
	var nascendo := clampf(1.0 - _espera / 1.8, 0.2, 1.0) if not _dissolvendo else 1.0
	var r := 22.0 * nascendo * (1.0 + sin(_t * 6.0) * 0.05)
	draw_circle(Vector2.ZERO, r, cor)
	# Pingos de cera escorrendo.
	for i in 3:
		var x := -12.0 + i * 12.0
		var comp := (18.0 + sin(_t * 2.0 + i) * 6.0) * nascendo
		draw_rect(Rect2(x - 3, 0, 6, r * 0.6 + comp), cor)
	# Olhos vazados.
	var escuro := Color(0.12, 0.09, 0.06)
	draw_circle(Vector2(-7, -4) * nascendo, 4.0 * nascendo, escuro)
	draw_circle(Vector2(7, -4) * nascendo, 4.0 * nascendo, escuro)
