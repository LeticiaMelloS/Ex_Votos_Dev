class_name Nivel
extends Node2D
## Monta uma fase a partir de um mapa em texto (pasta niveis/).
## A legenda dos caracteres está em niveis/LEIA-ME.md.

const TILE := 40
## Grupos que têm colisão. "#" é sempre sólido; os outros ligam e desligam.
const GRUPOS_SOLIDOS := "#DFBH"

const COR_PAPEL := Color(0.86, 0.82, 0.74)
const COR_PEDRA := Color(0.16, 0.15, 0.14)
const COR_PORTAO := Color(0.36, 0.31, 0.26)
const COR_VAZIO := Color(0.04, 0.035, 0.03)
const COR_CERA := Color(0.93, 0.87, 0.72)
const COR_OURO := Color(0.85, 0.66, 0.18)

var grade: Array[String] = []
var largura := 0
var altura := 0
var meta := {}
var altares := {}  # id do altar (String) -> Vector2i
var inicio := Vector2i.ZERO
var grupos_ativos := {"#": true, "D": true, "F": true, "B": false, "H": false}
var ex_votos: Array[Vector2] = []  # marcas de promessas cumpridas
var mostrar_debug := false:
	set(v):
		mostrar_debug = v
		queue_redraw()

## Elementos de cera e ouro. Ficam numa camada acima da escuridão (ver main.gd).
var brilho := Node2D.new()

var _corpos := {}  # letra -> StaticBody2D


func carregar(caminho: String) -> bool:
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		push_error("Não consegui abrir o nível: " + caminho)
		return false
	var linhas: Array[String] = []
	while not f.eof_reached():
		var l := f.get_line()
		if l.begins_with(";;"):
			continue
		if l.begins_with("@"):
			_ler_meta(l)
			continue
		linhas.append(l)
	while not linhas.is_empty() and linhas[-1].strip_edges() == "":
		linhas.pop_back()

	altura = linhas.size()
	for l in linhas:
		largura = maxi(largura, l.length())
	for l in linhas:
		grade.append(l.rpad(largura, ".").replace(" ", "."))

	for y in altura:
		for x in largura:
			var c := grade[y][x]
			if c == "P":
				inicio = Vector2i(x, y)
			elif "123456789".contains(c):
				altares[c] = Vector2i(x, y)

	for letra in GRUPOS_SOLIDOS:
		_criar_colisao(letra)
	brilho.draw.connect(_desenhar_brilho)
	return true


func _ler_meta(l: String) -> void:
	var partes := l.substr(1).strip_edges().split(" ", false)
	if partes.is_empty():
		return
	var resto := " ".join(partes.slice(1))
	match partes[0]:
		"nome":
			meta["nome"] = resto
		"escuro":
			meta["escuro"] = float(partes[1]) if partes.size() > 1 else 0.85
		"altar":
			meta["altar_" + partes[1]] = Array(partes.slice(2))
		_:
			meta[partes[0]] = resto


func _criar_colisao(letra: String) -> void:
	var corpo := StaticBody2D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	_corpos[letra] = corpo
	# Junta tiles vizinhos na horizontal num único retângulo.
	for y in altura:
		var x := 0
		while x < largura:
			if grade[y][x] != letra:
				x += 1
				continue
			var x0 := x
			while x < largura and grade[y][x] == letra:
				x += 1
			var forma := CollisionShape2D.new()
			var ret := RectangleShape2D.new()
			ret.size = Vector2((x - x0) * TILE, TILE)
			forma.shape = ret
			forma.position = Vector2((x0 + x) * TILE * 0.5, (y + 0.5) * TILE)
			forma.disabled = not grupos_ativos[letra]
			corpo.add_child(forma)


## Liga (ativo = true) ou desliga um grupo de tiles: portões, pontes, caminhos ocultos.
func ativar_grupo(letra: String, ativo: bool) -> void:
	grupos_ativos[letra] = ativo
	for forma in _corpos[letra].get_children():
		forma.set_deferred("disabled", not ativo)
	queue_redraw()
	brilho.queue_redraw()


func celula(pos: Vector2) -> String:
	var x := floori(pos.x / TILE)
	var y := floori(pos.y / TILE)
	if x < 0 or y < 0 or x >= largura or y >= altura:
		return "."
	return grade[y][x]


func coluna(pos: Vector2) -> int:
	return floori(pos.x / TILE)


## Posição dos pés de quem está em pé na célula.
func pe_da_celula(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * TILE, (c.y + 1) * TILE)


func tamanho_px() -> Vector2:
	return Vector2(largura * TILE, altura * TILE)


func adicionar_ex_voto(pos: Vector2) -> void:
	ex_votos.append(pos)
	brilho.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, tamanho_px()), COR_PAPEL)
	for y in altura:
		for x in largura:
			var c := grade[y][x]
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			match c:
				"#":
					draw_rect(r, COR_PEDRA)
				"D", "F":
					if grupos_ativos[c]:
						draw_rect(r, COR_PORTAO)
						for i in 3:
							draw_line(r.position + Vector2(8 + i * 12, 0), r.position + Vector2(8 + i * 12, TILE), COR_PEDRA, 3)
				"~":
					draw_rect(r, COR_VAZIO)
				"e", "E":
					# Degraus da escadaria (só marca visual; o chão real são os "#").
					draw_line(r.position + Vector2(0, TILE - 2), r.end - Vector2(0, 2), COR_PORTAO, 2)
				"C":
					var p := r.position + Vector2(TILE * 0.5, TILE)
					draw_line(p, p - Vector2(0, 34), COR_PEDRA, 3)
					draw_line(p - Vector2(9, 26), p - Vector2(-9, 26), COR_PEDRA, 3)
				"G":
					draw_rect(r.grow(-4), Color(1, 1, 1, 0.6))
			if mostrar_debug and "zr".contains(c):
				var cor := Color(0.2, 0.4, 1, 0.12) if c == "z" else Color(1, 0, 1, 0.35)
				draw_rect(r, cor)


func _desenhar_brilho() -> void:
	for y in altura:
		for x in largura:
			var c := grade[y][x]
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			if c == "B" and grupos_ativos["B"]:
				brilho.draw_rect(r, COR_CERA)
			elif c == "H" and grupos_ativos["H"]:
				brilho.draw_rect(r, COR_CERA.darkened(0.12))
			elif c == "T":
				brilho.draw_rect(r.grow(-6), COR_OURO, false, 3)
			elif "123456789".contains(c):
				# Altar: moldura dourada (vazada para não esconder a protagonista).
				var a := Rect2(x * TILE + 4, (y - 1) * TILE + 2, TILE - 8, TILE * 2 - 2)
				brilho.draw_rect(a, COR_OURO, false, 4)
				brilho.draw_line(a.position + Vector2(a.size.x * 0.5, -10), a.position + Vector2(a.size.x * 0.5, 8), COR_OURO, 3)
				brilho.draw_line(a.position + Vector2(a.size.x * 0.5 - 7, -3), a.position + Vector2(a.size.x * 0.5 + 7, -3), COR_OURO, 3)
	for p in ex_votos:
		# Ex-voto de agradecimento: uma mãozinha de cera pendurada.
		brilho.draw_line(p + Vector2(0, -95), p + Vector2(0, -80), COR_CERA, 1)
		brilho.draw_rect(Rect2(p + Vector2(-6, -80), Vector2(12, 16)), COR_CERA)
