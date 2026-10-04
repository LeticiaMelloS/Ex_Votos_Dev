class_name MapaHud
extends Control
## Mapa das salas visitadas (tecla M, no modo Mundo).
## Provisório: na versão final, o mapa de cada área vem do riscador de milagres
## e se atualiza nos altares (design/level-design/areas.md, 2.4).

const CORES := {
	"Cidade das Ladeiras": Color("#C9A227"),
	"Sala dos Milagres": Color("#4F7FBF"),
	"Sertão da Romaria": Color("#7FA34A"),
	"Minas": Color("#3E9C96"),
	"Santuário": Color("#B04A5A"),
}

var mundo: Mundo
var sala_atual := ""


func _ready() -> void:
	position = Vector2(160, 110)
	size = Vector2(1600, 860)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.045, 0.035, 0.94))
	if mundo == null or mundo.visitadas.is_empty():
		return
	# Enquadra as salas visitadas.
	var caixa := Rect2i()
	var primeira := true
	for cod in mundo.visitadas:
		if not mundo.salas.has(cod):
			continue
		var r: Rect2i = mundo.salas[cod]["rect"]
		caixa = r if primeira else caixa.merge(r)
		primeira = false
	caixa = caixa.grow(1)
	var escala := minf((size.x - 80) / caixa.size.x, (size.y - 120) / caixa.size.y)
	escala = minf(escala, 120.0)
	var desloc := Vector2(40, 70) + (Vector2(size.x - 80, size.y - 120) - Vector2(caixa.size) * escala) * 0.5
	var fonte := ThemeDB.fallback_font
	draw_string(fonte, Vector2(40, 44), "MAPA  ·  salas visitadas  ·  M fecha", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 0.9, 0.78))
	for cod in mundo.visitadas:
		if not mundo.salas.has(cod):
			continue
		var s: Dictionary = mundo.salas[cod]
		var r: Rect2i = s["rect"]
		var regiao: String = mundo.areas.get(s["area"], {}).get("regiao", "")
		var cor: Color = CORES.get(regiao, Color.GRAY)
		var ret := Rect2(desloc + Vector2(r.position - caixa.position) * escala, Vector2(r.size) * escala).grow(-3)
		draw_rect(ret, cor.darkened(0.55) if cod != sala_atual else cor)
		draw_rect(ret, cor, false, 2.0)
		if String(s["altar"]).strip_edges() != "":
			draw_circle(ret.get_center() + Vector2(0, ret.size.y * 0.25), 5.0, Color(0.95, 0.76, 0.3))
		if escala >= 70:
			draw_string(fonte, ret.position + Vector2(6, 20), cod, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
			draw_string(fonte, ret.position + Vector2(6, 40), String(s["nome"]), HORIZONTAL_ALIGNMENT_LEFT, ret.size.x - 10, 13, Color(0.93, 0.9, 0.82))
	if mundo.salas.has(sala_atual):
		var r: Rect2i = mundo.salas[sala_atual]["rect"]
		var c := desloc + (Vector2(r.position - caixa.position) + Vector2(r.size) * 0.5) * escala
		draw_circle(c, 9.0, Color(0.72, 0.07, 0.07))  # você está aqui (a fita)
