class_name ArteDoNivel
extends Node2D
## Coloca a arte (PNG) por cima do greybox, a partir das linhas "@arte" do mapa.
## Exemplo:
##   @arte arquivo=res://arte/provisoria/ia_fundo.png x=98 y=18 altura=22 parallax=0.3
## x, y: canto superior esquerdo, em tiles. altura: em tiles (a largura segue a proporção).
## parallax: 1 = acompanha o chão; menor = mais longe (mais lento); maior = primeiro plano.
## recorte=papel: deixa transparente o fundo claro da imagem.
## brilho=sim: fica acima da escuridão (para cera e ouro).
## z: ordem de desenho (padrão -10 = atrás do jogo; use valores maiores para frente).
## Se o arquivo ainda não existir, a linha é ignorada (dá para preparar antes).

const SHADER_RECORTE := preload("res://src/recorte_papel.gdshader")

var camera: Camera2D
var _camadas: Array[Dictionary] = []  # {"no": Node2D, "base": Vector2, "ref": Vector2, "parallax": float}


func montar(nivel: Nivel, camada_brilho: CanvasLayer) -> int:
	var total := 0
	for linha in nivel.meta.get("arte", []):
		var p := _ler_parametros(linha)
		var caminho: String = p.get("arquivo", "")
		if caminho == "" or not ResourceLoader.exists(caminho):
			print_verbose("Arte ainda não encontrada (ignorada): " + caminho)
			continue
		var tex: Texture2D = load(caminho)
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		var altura_px := float(p.get("altura", "10")) * Nivel.TILE
		var escala := altura_px / tex.get_height()
		sprite.scale = Vector2(escala, escala)
		sprite.z_index = int(p.get("z", "-10"))
		if p.get("recorte", "") == "papel":
			var mat := ShaderMaterial.new()
			mat.shader = SHADER_RECORTE
			sprite.material = mat
		var base := Vector2(float(p.get("x", "0")), float(p.get("y", "0"))) * Nivel.TILE
		sprite.position = base
		var parallax := float(p.get("parallax", "1"))
		if p.get("brilho", "") == "sim":
			camada_brilho.add_child(sprite)
		else:
			add_child(sprite)
			if parallax != 1.0:
				# Referência: quando a câmera está no centro da imagem, ela aparece onde foi posta.
				var centro := base + Vector2(tex.get_width(), tex.get_height()) * escala * 0.5
				_camadas.append({"no": sprite, "base": base, "ref": centro, "parallax": parallax})
		# Arte de plano de jogo ("..._plano.png"): o greybox fica translúcido só ali.
		if caminho.ends_with("_plano.png"):
			nivel.areas_com_arte.append(Rect2(base, Vector2(tex.get_width(), tex.get_height()) * escala))
		total += 1
	if not nivel.areas_com_arte.is_empty():
		nivel.queue_redraw()
	return total


func _ler_parametros(linha: String) -> Dictionary:
	var p := {}
	for parte in linha.split(" ", false):
		var kv := parte.split("=", true, 1)
		if kv.size() == 2:
			p[kv[0]] = kv[1]
	return p


func _process(_delta: float) -> void:
	if camera == null:
		return
	var c := camera.get_screen_center_position()
	for camada in _camadas:
		var no: Node2D = camada["no"]
		no.position = camada["base"] + (c - camada["ref"]) * (1.0 - camada["parallax"])
