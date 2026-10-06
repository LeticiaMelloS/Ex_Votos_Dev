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
const COR_CERA_VELHA := Color(0.74, 0.55, 0.28)  # âmbar: cera de séculos

## Avisa quando um portão, ponte ou corda muda (o modo Mundo guarda isso entre salas).
signal grupo_mudou(letra: String, ativo: bool)

var grade: Array[String] = []
var largura := 0
var altura := 0
var meta := {}
var altares := {}  # id do altar (String) -> Vector2i
var inicio := Vector2i.ZERO
var grupos_ativos := {"#": true, "D": true, "F": true, "B": false, "H": false, "K": false}
## Altares de oferta do corpo: "t" (tranças) e "m" (mão) -> Vector2i.
var altares_oferta := {}
## Bilhetes de graça ("?") e falas de NPC ("!"), em ordem da esquerda para a direita.
var bilhetes: Array[Dictionary] = []  # {"celula": Vector2i, "texto": String}
var falas: Array[Dictionary] = []
## Criaturas de cera do mapa ("&"), com o tipo vindo das linhas "@criatura", da esquerda para a direita.
var criaturas_mapa: Array[Dictionary] = []  # {"celula": Vector2i, "texto": tipo}
## Objetos para pegar ("%"), com o id e o texto da linha "@objeto id Texto".
var objetos: Array[Dictionary] = []  # {"celula": Vector2i, "texto": "id Texto"}
## Ids dos objetos que ela já tem (não aparecem mais).
var objetos_pegos: Array[String] = []
var oferendas: Array[String] = []  # altares de oferta já usados
var ex_votos: Array[Vector2] = []  # marcas de promessas cumpridas
var mostrar_debug := false:
	set(v):
		mostrar_debug = v
		queue_redraw()

## Elementos de cera e ouro. Ficam numa camada acima da escuridão (ver main.gd).
var brilho := Node2D.new()

var _corpos := {}  # letra -> StaticBody2D
var _maos := {}  # Vector2i -> CollisionShape2D (mãos da parede, uma por célula)
var _maos_ativas := {}  # Vector2i -> true
## Paredes de cera: "w" (fina, qualquer chama derrete) e "W" (velha, só a vela da irmandade).
var _ceras := {}  # Vector2i -> CollisionShape2D
var _derretidas := {}  # Vector2i -> true


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
			elif c == "t" or c == "m":
				altares_oferta[c] = Vector2i(x, y)

	for letra in GRUPOS_SOLIDOS:
		_criar_colisao(letra)
	_criar_maos()
	_criar_ceras()
	_ligar_textos("?", "bilhete", bilhetes)
	_ligar_textos("!", "fala", falas)
	_ligar_textos("&", "criatura", criaturas_mapa)
	_ligar_textos("%", "objeto", objetos)
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
		"bilhete", "fala", "criatura", "objeto":
			if not meta.has(partes[0]):
				meta[partes[0]] = []
			meta[partes[0]].append(resto)
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


## Liga cada "?"/"!" do mapa ao texto correspondente do cabeçalho, da esquerda para a direita.
func _ligar_textos(simbolo: String, chave: String, destino: Array[Dictionary]) -> void:
	var celulas: Array[Vector2i] = []
	for y in altura:
		for x in largura:
			if grade[y][x] == simbolo:
				celulas.append(Vector2i(x, y))
	celulas.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var textos: Array = meta.get(chave, [])
	for i in celulas.size():
		var texto: String = textos[i] if i < textos.size() else "(texto ainda não escrito)"
		destino.append({"celula": celulas[i], "texto": texto})


## Mãos da parede ("M"): plataformas de mão única, uma por célula.
## Só existem depois da oferta da mão, e só perto da protagonista.
func _criar_maos() -> void:
	var corpo := StaticBody2D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	for y in altura:
		for x in largura:
			if grade[y][x] != "M":
				continue
			var forma := CollisionShape2D.new()
			var ret := RectangleShape2D.new()
			ret.size = Vector2(TILE, 10)
			forma.shape = ret
			forma.position = Vector2((x + 0.5) * TILE, y * TILE + 5)
			forma.one_way_collision = true
			forma.disabled = true
			corpo.add_child(forma)
			_maos[Vector2i(x, y)] = forma


## Abre as mãos que estão a menos de `raio` px do ponto (se a mão foi ofertada).
func atualizar_maos(perto_de: Vector2, ofertada: bool, raio := 170.0) -> void:
	var mudou := false
	for celula_mao in _maos:
		var centro_mao := Vector2((celula_mao.x + 0.5) * TILE, (celula_mao.y + 0.5) * TILE)
		var ativa := ofertada and centro_mao.distance_to(perto_de) < raio
		if ativa != _maos_ativas.has(celula_mao):
			mudou = true
			_maos[celula_mao].set_deferred("disabled", not ativa)
			if ativa:
				_maos_ativas[celula_mao] = true
			else:
				_maos_ativas.erase(celula_mao)
	if mudou:
		brilho.queue_redraw()


## Cada célula de cera tem a própria colisão, para derreter uma a uma.
func _criar_ceras() -> void:
	var corpo := StaticBody2D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	add_child(corpo)
	for y in altura:
		for x in largura:
			if grade[y][x] != "w" and grade[y][x] != "W":
				continue
			var forma := CollisionShape2D.new()
			var ret := RectangleShape2D.new()
			ret.size = Vector2(TILE, TILE)
			forma.shape = ret
			forma.position = Vector2((x + 0.5) * TILE, (y + 0.5) * TILE)
			corpo.add_child(forma)
			_ceras[Vector2i(x, y)] = forma


## A chama encostou nesta área: derrete a cera que puder.
## Devolve {"derretidas": [Vector2i…], "resistiu": true se havia cera velha e a vela é fraca}.
func derreter(area: Rect2, forte: bool) -> Dictionary:
	var feitas: Array[Vector2i] = []
	var resistiu := false
	for y in range(maxi(floori(area.position.y / TILE), 0), mini(floori(area.end.y / TILE) + 1, altura)):
		for x in range(maxi(floori(area.position.x / TILE), 0), mini(floori(area.end.x / TILE) + 1, largura)):
			var cel := Vector2i(x, y)
			if not _ceras.has(cel) or _derretidas.has(cel):
				continue
			if grade[y][x] == "W" and not forte:
				resistiu = true
				continue
			feitas.append(cel)
	# A cera escorre: o que estiver em cima de uma célula derretida, na mesma coluna, derrete junto.
	var i := 0
	while i < feitas.size():
		var acima := feitas[i] + Vector2i(0, -1)
		if _ceras.has(acima) and not _derretidas.has(acima) and not feitas.has(acima) \
				and (grade[acima.y][acima.x] == "w" or forte):
			feitas.append(acima)
		i += 1
	marcar_derretidas(feitas)
	return {"derretidas": feitas, "resistiu": resistiu and feitas.is_empty()}


func marcar_derretidas(celulas: Array) -> void:
	for cel in celulas:
		if _ceras.has(cel):
			_derretidas[cel] = true
			_ceras[cel].set_deferred("disabled", true)
	if not celulas.is_empty():
		brilho.queue_redraw()


func registrar_oferenda(altar: String) -> void:
	oferendas.append(altar)
	queue_redraw()
	brilho.queue_redraw()


## Liga (ativo = true) ou desliga um grupo de tiles: portões, pontes, caminhos ocultos, corda.
func ativar_grupo(letra: String, ativo: bool) -> void:
	grupos_ativos[letra] = ativo
	grupo_mudou.emit(letra, ativo)
	if _corpos.has(letra):
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


## Altura (em px) do chão na coluna de `x`, procurando a partir de 3 tiles acima de `perto_de_y`.
func chao_em(x: float, perto_de_y: float) -> float:
	var col := clampi(floori(x / TILE), 0, largura - 1)
	for lin in range(maxi(floori(perto_de_y / TILE) - 3, 1), altura):
		if "#DFwW".contains(grade[lin][col]) and not "#DFwW".contains(grade[lin - 1][col]):
			return lin * TILE
	return perto_de_y


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
				"^":
					# Cravos: os pregos que seguram os ex-votos, de ponta para cima.
					for i in 4:
						var bx := r.position.x + i * 10
						draw_colored_polygon(PackedVector2Array([Vector2(bx, r.end.y), Vector2(bx + 5, r.position.y + 8), Vector2(bx + 10, r.end.y)]), COR_PEDRA)
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
				"?":
					# Bilhete de graça preso na parede.
					var b := Rect2(r.position + Vector2(10, 4), Vector2(20, 24))
					draw_rect(b, Color(0.97, 0.95, 0.88))
					for i in 3:
						draw_line(b.position + Vector2(3, 6 + i * 6), b.position + Vector2(17, 6 + i * 6), COR_PORTAO, 1)
				"!":
					# NPC sentada (benzedeira): corpo escuro, lenço claro.
					draw_rect(Rect2(r.position + Vector2(8, 14), Vector2(24, 26)), COR_PEDRA)
					draw_rect(Rect2(r.position + Vector2(11, 4), Vector2(18, 12)), Color(0.97, 0.95, 0.88))
				"L":
					# Escada de mão (sempre disponível).
					var e := r.position.x + 10
					draw_line(Vector2(e, r.position.y), Vector2(e, r.end.y), COR_PORTAO, 3)
					draw_line(Vector2(e + 20, r.position.y), Vector2(e + 20, r.end.y), COR_PORTAO, 3)
					for i in 3:
						var yy := r.position.y + 6 + i * 13
						draw_line(Vector2(e, yy), Vector2(e + 20, yy), COR_PORTAO, 3)
				"K":
					# A trança-corda: escura, trançada (cabelo, não cera).
					if grupos_ativos["K"]:
						var meio := r.position.x + TILE * 0.5
						draw_line(Vector2(meio, r.position.y), Vector2(meio, r.end.y), COR_PEDRA, 5)
						for i in 4:
							var yy := r.position.y + i * 10 + 5
							draw_line(Vector2(meio - 5, yy), Vector2(meio + 5, yy + 5), COR_PEDRA, 2)
				"t":
					# Depois da oferta, as tranças ficam penduradas no altar.
					if oferendas.has("t"):
						var topo := r.position + Vector2(TILE * 0.5, -TILE + 8)
						draw_line(topo + Vector2(-5, 0), topo + Vector2(-8, 40), COR_PEDRA, 4)
						draw_line(topo + Vector2(5, 0), topo + Vector2(8, 40), COR_PEDRA, 4)
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
			elif c == "M":
				_desenhar_mao(r, _maos_ativas.has(Vector2i(x, y)))
			elif c == "%":
				_desenhar_objeto(r, Vector2i(x, y))
			elif (c == "w" or c == "W") and not _derretidas.has(Vector2i(x, y)):
				# Cera fina: clara e lisa. Cera velha: âmbar escuro, em camadas escorridas.
				var cor_cera := COR_CERA if c == "w" else COR_CERA_VELHA
				brilho.draw_rect(r, cor_cera)
				var cor_linha := cor_cera.darkened(0.18)
				if c == "W":
					for i in 3:
						brilho.draw_line(r.position + Vector2(0, 8 + i * 12), r.position + Vector2(TILE, 6 + i * 12), cor_linha, 2)
				var gota := 8.0 + float((x * 7 + y * 13) % 17)
				brilho.draw_line(r.position + Vector2(gota, 0), r.position + Vector2(gota, TILE * 0.6), cor_linha, 3)
			elif c == "t" or c == "m":
				# Altar de oferta: moldura dourada com fundo de cera.
				var ao := Rect2(x * TILE + 2, (y - 1) * TILE, TILE - 4, TILE * 2)
				brilho.draw_rect(ao, Color(COR_CERA, 0.25))
				brilho.draw_rect(ao, COR_OURO, false, 4)
				if c == "m" and oferendas.has("m"):
					brilho.draw_line(ao.position + Vector2(ao.size.x * 0.5, 4), ao.position + Vector2(ao.size.x * 0.5, 18), COR_CERA, 1)
					brilho.draw_rect(Rect2(ao.position + Vector2(ao.size.x * 0.5 - 7, 18), Vector2(14, 18)), COR_CERA)
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


## Id do objeto ("%") nesta célula, ou "".
func objeto_em(cel: Vector2i) -> String:
	for o in objetos:
		if o["celula"] == cel:
			return String(o["texto"]).split(" ", false)[0] if String(o["texto"]) != "" else ""
	return ""


func _desenhar_objeto(r: Rect2, cel: Vector2i) -> void:
	if objetos_pegos.has(objeto_em(cel)):
		return
	# Por enquanto, todo objeto é desenhado como uma matraca: tábua com o martelo.
	var c := r.get_center() + Vector2(0, 6)
	brilho.draw_rect(Rect2(c.x - 9, c.y - 6, 18, 14), COR_PORTAO)
	brilho.draw_line(c + Vector2(0, 8), c + Vector2(0, 18), COR_PORTAO, 3)
	brilho.draw_rect(Rect2(c.x - 11, c.y - 9, 4, 8), COR_OURO)
	brilho.draw_arc(c, 18, 0, TAU, 20, Color(COR_OURO, 0.5), 2)


## Mãozinha de cera: fechada contra a parede, ou aberta como apoio.
func _desenhar_mao(r: Rect2, aberta: bool) -> void:
	if aberta:
		brilho.draw_rect(Rect2(r.position.x, r.position.y, TILE, 10), COR_CERA)
		for i in 4:
			brilho.draw_rect(Rect2(r.position.x + 3 + i * 9, r.position.y - 7, 5, 8), COR_CERA)
	else:
		var c := r.get_center()
		brilho.draw_rect(Rect2(c.x - 6, c.y - 8, 12, 14), Color(COR_CERA, 0.55))
		for i in 3:
			brilho.draw_rect(Rect2(c.x - 6 + i * 4.5, c.y - 14, 3, 7), Color(COR_CERA, 0.55))
