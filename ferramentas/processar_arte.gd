extends SceneTree
## Processa a arte exportada do Krita (pasta arte/entrada) e gera os arquivos
## que o jogo usa (pasta arte/provisoria). Rode com processar_arte.bat.
##
## Entradas reconhecidas:
##   ia_eN_gerada.png    → ia_eN_fundo.png (imagem inteira) + ia_eN_plano.png (só a parte sólida)
##   ia_eN_distante.png  → ia_eN_distante.png (com contraste reduzido, puxado para o papel)
##   ia_QUALQUER.png     → objeto: fundo claro vira transparente e a imagem é cortada no conteúdo
## Em todas: o vermelho vira cinza (o vermelho é só da fita).
## Só processa entradas mais novas que as saídas, para não apagar ajustes feitos à mão.

const NIVEL := "res://niveis/sala_dos_milagres.txt"
const MARGEM_PLANO := 6  # px que a pedra "sobra" além da borda sólida
const SOLIDOS_DO_PLANO := "#"  # portões e pontes mudam de estado: ficam fora do plano

var entrada := ProjectSettings.globalize_path("res://arte/entrada")
var saida := ProjectSettings.globalize_path("res://arte/provisoria")
var relatorio: PackedStringArray = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(entrada)
	DirAccess.make_dir_recursive_absolute(saida)
	var nivel := Nivel.new()
	nivel.carregar(NIVEL)
	var espacos := {}  # "e4" -> Rect2i em tiles
	for linha in nivel.meta.get("espaco", []):
		var p: PackedStringArray = String(linha).split(" ", false)
		var chave := p[0].split("_")[0]
		espacos[chave] = Rect2i(int(p[1]), int(p[2]), int(p[3]) - int(p[1]), int(p[4]) - int(p[2]))

	var arquivos := DirAccess.get_files_at(entrada)
	if arquivos.is_empty():
		relatorio.append("Nenhum arquivo em arte/entrada.")
	for arquivo in arquivos:
		if not arquivo.to_lower().ends_with(".png"):
			continue
		var nome := arquivo.get_basename()
		if nome.to_lower().ends_with(".png"):
			# "ia_e4_gerada.png.png": o Krita acrescentou .png a um nome que já tinha.
			relatorio.append("  aviso: %s tem .png duas vezes no nome; entendi como %s" % [arquivo, nome])
			nome = nome.get_basename()
		var partes := nome.split("_")
		if partes.size() == 3 and partes[0] == "ia" and espacos.has(partes[1]) and partes[2] == "gerada":
			_processar_espaco(arquivo, partes[1], espacos[partes[1]], nivel)
		elif partes.size() == 3 and partes[0] == "ia" and espacos.has(partes[1]) and partes[2] == "distante":
			_processar_distante(arquivo, nome + ".png")
		elif nome.begins_with("ia_"):
			_processar_objeto(arquivo, nome + ".png")
		else:
			relatorio.append("IGNORADO (o nome precisa começar com ia_): " + arquivo)
	print("\n".join(relatorio))
	nivel.free()
	quit()


func _precisa(entrada_arq: String, saidas: Array) -> bool:
	var t := FileAccess.get_modified_time(entrada + "/" + entrada_arq)
	for s in saidas:
		var caminho: String = saida + "/" + s
		if not FileAccess.file_exists(caminho) or FileAccess.get_modified_time(caminho) < t:
			return true
	return false


func _carregar(arquivo: String) -> Image:
	var img := Image.load_from_file(entrada + "/" + arquivo)
	img.convert(Image.FORMAT_RGBA8)
	return img


func _processar_espaco(arquivo: String, chave: String, r: Rect2i, nivel: Nivel) -> void:
	var fundo_nome := "ia_%s_fundo.png" % chave
	var plano_nome := "ia_%s_plano.png" % chave
	if not _precisa(arquivo, [fundo_nome, plano_nome]):
		relatorio.append("sem mudanças: " + arquivo)
		return
	var img := _carregar(arquivo)
	var w := r.size.x * Nivel.TILE
	var h := r.size.y * Nivel.TILE
	if img.get_width() != w or img.get_height() != h:
		relatorio.append("  aviso: %s tinha %dx%d; ajustei para o tamanho do molde (%dx%d)" % [arquivo, img.get_width(), img.get_height(), w, h])
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var vermelhos := _tirar_vermelho(img)

	# Máscara do plano: tiles sólidos, com uma pequena margem.
	var mascara := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if x < 0 or y < 0 or x >= nivel.largura or y >= nivel.altura:
				continue
			if not SOLIDOS_DO_PLANO.contains(nivel.grade[y][x]):
				continue
			var px := Rect2i((x - r.position.x) * Nivel.TILE - MARGEM_PLANO, (y - r.position.y) * Nivel.TILE - MARGEM_PLANO,
				Nivel.TILE + MARGEM_PLANO * 2, Nivel.TILE + MARGEM_PLANO * 2).intersection(Rect2i(0, 0, w, h))
			mascara.fill_rect(px, Color.WHITE)
	var plano := Image.create(w, h, false, Image.FORMAT_RGBA8)
	plano.blit_rect_mask(img, mascara, Rect2i(0, 0, w, h), Vector2i.ZERO)

	img.save_png(saida + "/" + fundo_nome)
	plano.save_png(saida + "/" + plano_nome)
	relatorio.append("OK %s → %s + %s%s" % [arquivo, fundo_nome, plano_nome, _txt_vermelho(vermelhos)])


func _processar_distante(arquivo: String, nome_saida: String) -> void:
	if not _precisa(arquivo, [nome_saida]):
		relatorio.append("sem mudanças: " + arquivo)
		return
	var img := _carregar(arquivo)
	var vermelhos := _tirar_vermelho(img)
	img.adjust_bcs(1.05, 0.55, 0.7)
	var veu := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	veu.fill(Color(Nivel.COR_PAPEL, 0.45))
	img.blend_rect(veu, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
	img.save_png(saida + "/" + nome_saida)
	relatorio.append("OK %s → apagado para o fundo distante%s" % [arquivo, _txt_vermelho(vermelhos)])


func _processar_objeto(arquivo: String, nome_saida: String) -> void:
	if not _precisa(arquivo, [nome_saida]):
		relatorio.append("sem mudanças: " + arquivo)
		return
	var img := _carregar(arquivo)
	var vermelhos := _tirar_vermelho(img)
	# O fundo liso (claro, ligado às bordas da imagem) vira transparente.
	# Só o que toca a borda: a cera clara *dentro* do objeto continua.
	_apagar_fundo_pelas_bordas(img)
	var uso := img.get_used_rect()
	if uso.size.x > 0 and uso.size.y > 0:
		img = img.get_region(uso.grow(4).intersection(Rect2i(0, 0, img.get_width(), img.get_height())))
	img.save_png(saida + "/" + nome_saida)
	relatorio.append("OK %s → objeto recortado (%dx%d)%s" % [arquivo, img.get_width(), img.get_height(), _txt_vermelho(vermelhos)])


## Vermelho forte vira cinza da mesma luminosidade. Devolve quantos pixels mudaram.
func _tirar_vermelho(img: Image) -> int:
	var dados := img.get_data()
	var n := 0
	for i in range(0, dados.size(), 4):
		var rr := dados[i]
		var gg := dados[i + 1]
		var bb := dados[i + 2]
		if rr > 90 and rr > gg * 2.6 and rr > bb * 2.6:
			var l := int(0.299 * rr + 0.587 * gg + 0.114 * bb)
			dados[i] = l
			dados[i + 1] = l
			dados[i + 2] = l
			n += 1
	if n > 0:
		img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, dados)
	return n


func _txt_vermelho(n: int) -> String:
	return "  (vermelho removido em %d pixels — confira)" % n if n > 500 else ""


func _parece_papel(dados: PackedByteArray, i: int) -> bool:
	var rr := dados[i] / 255.0
	var gg := dados[i + 1] / 255.0
	var bb := dados[i + 2] / 255.0
	var lum := 0.299 * rr + 0.587 * gg + 0.114 * bb
	var sat := maxf(rr, maxf(gg, bb)) - minf(rr, minf(gg, bb))
	return lum > 0.72 and sat < 0.25


## Preenchimento a partir das bordas: apaga os pixels claros conectados à borda.
func _apagar_fundo_pelas_bordas(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var dados := img.get_data()
	var visto := PackedByteArray()
	visto.resize(w * h)
	var pilha := PackedInt32Array()
	for x in w:
		pilha.append(x)
		pilha.append((h - 1) * w + x)
	for y in h:
		pilha.append(y * w)
		pilha.append(y * w + w - 1)
	while not pilha.is_empty():
		var idx := pilha[pilha.size() - 1]
		pilha.resize(pilha.size() - 1)
		if visto[idx] == 1:
			continue
		visto[idx] = 1
		if not _parece_papel(dados, idx * 4):
			continue
		dados[idx * 4 + 3] = 0
		var x := idx % w
		var y := idx / w
		if x > 0: pilha.append(idx - 1)
		if x < w - 1: pilha.append(idx + 1)
		if y > 0: pilha.append(idx - w)
		if y < h - 1: pilha.append(idx + w)
	img.set_data(w, h, false, Image.FORMAT_RGBA8, dados)
