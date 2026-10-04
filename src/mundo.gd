class_name Mundo
extends RefCounted
## O mundo como conjunto de salas (P6).
## Lê as planilhas de mundo/ (as mesmas do desenhador do mapa) e sabe:
## onde fica cada sala, qual sala está num ponto do mundo, para onde levam as
## passagens entre áreas, e o que já foi visitado e salvo.

const CEL_W := 48  # tiles por célula (1 célula = 1 tela)
const CEL_H := 27
const PASTA_SALAS := "res://niveis/salas/"
const ARQUIVO_SAVE := "user://mundo.json"

var salas := {}  # codigo -> Dictionary (campos da planilha + "rect": Rect2i em células)
var areas := {}  # codigo -> Dictionary
var ligacoes: Array[Dictionary] = []
var visitadas := {}  # codigo -> true
var grupos := {}  # sala -> {letra: ativo}: portões e pontes que ficaram abertos


func carregar_dados() -> void:
	for a in _ler_csv("res://mundo/areas.csv"):
		areas[a["codigo"]] = a
	for l in _ler_csv("res://mundo/ligacoes.csv"):
		ligacoes.append(l)
	for s in _ler_csv("res://mundo/salas.csv"):
		s["rect"] = Rect2i(int(s["x"]), int(s["y"]), int(s["largura"]), int(s["altura"]))
		var liga := PackedStringArray()
		for c in String(s["liga"]).split(",", false):
			liga.append(c.strip_edges())
		s["ligadas"] = liga
		salas[s["codigo"]] = s


func _ler_csv(caminho: String) -> Array[Dictionary]:
	var linhas: Array[Dictionary] = []
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		push_error("Não consegui abrir " + caminho)
		return linhas
	var cab := f.get_csv_line(";")
	if cab.size() > 0:
		cab[0] = cab[0].trim_prefix("﻿")
	while not f.eof_reached():
		var campos := f.get_csv_line(";")
		if campos.size() < cab.size() or String(campos[0]).strip_edges() == "":
			continue
		var d := {}
		for i in cab.size():
			d[cab[i]] = campos[i]
		linhas.append(d)
	return linhas


## Tamanho de uma célula em px.
func cel_px() -> Vector2:
	return Vector2(CEL_W * Nivel.TILE, CEL_H * Nivel.TILE)


## Canto superior esquerdo da sala no mundo, em px.
func origem(codigo: String) -> Vector2:
	var r: Rect2i = salas[codigo]["rect"]
	return Vector2(r.position) * cel_px()


func arquivo(codigo: String) -> String:
	return PASTA_SALAS + codigo + ".txt"


func existe(codigo: String) -> bool:
	return salas.has(codigo) and FileAccess.file_exists(arquivo(codigo))


## Célula do mundo (em células) de um ponto em px.
func celula(ponto_mundo: Vector2) -> Vector2i:
	return Vector2i(floori(ponto_mundo.x / cel_px().x), floori(ponto_mundo.y / cel_px().y))


func sala_na_celula(c: Vector2i) -> String:
	for cod in salas:
		var r: Rect2i = salas[cod]["rect"]
		if r.has_point(c):
			return cod
	return ""


## Para onde leva sair da sala `de` pelo ponto `ponto_mundo`.
## Devolve {"sala": código ou "", "area": código da área de destino, "nota": texto}.
## Vizinhas listadas em "liga" têm prioridade; depois, as passagens entre áreas (ligacoes.csv).
func destino(de: String, ponto_mundo: Vector2) -> Dictionary:
	var c := celula(ponto_mundo)
	var vizinha := sala_na_celula(c)
	if vizinha != "" and salas[de]["ligadas"].has(vizinha):
		return {"sala": vizinha, "area": salas[vizinha]["area"], "nota": ""}
	var r: Rect2i = salas[de]["rect"]
	var centro := Vector2(r.position) + Vector2(r.size) * 0.5
	var dir := Vector2(c) + Vector2(0.5, 0.5) - centro
	for l in ligacoes:
		for sentido in [["x1", "y1", "x2", "y2", "para"], ["x2", "y2", "x1", "y1", "de"]]:
			if sentido[4] == "de" and l["tipo"] == "atalho":
				continue  # atalho é de mão única
			var p1 := Vector2i(int(l[sentido[0]]), int(l[sentido[1]]))
			var p2 := Vector2i(int(l[sentido[2]]), int(l[sentido[3]]))
			if not r.has_point(p1):
				continue
			var d := Vector2(p2 - p1)
			# A passagem tem que sair para o mesmo lado da tentativa.
			if absf(d.x) > absf(d.y):
				if signf(d.x) != signf(dir.x) or absf(dir.x) < absf(dir.y):
					continue
			elif signf(d.y) != signf(dir.y) or absf(dir.y) < absf(dir.x):
				continue
			var alvo := sala_na_celula(p2)
			return {"sala": alvo, "area": l[sentido[4]], "nota": l["nota"], "requisito": l["requisito"], "tipo": l["tipo"]}
	return {}


func nome_da_area(codigo_sala: String) -> String:
	var a: Dictionary = areas.get(salas.get(codigo_sala, {}).get("area", ""), {})
	return a.get("nome", "")


func salvar(estado: Dictionary) -> void:
	estado["visitadas"] = visitadas.keys()
	estado["grupos"] = grupos
	var f := FileAccess.open(ARQUIVO_SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(estado))


func carregar_save() -> Dictionary:
	if not FileAccess.file_exists(ARQUIVO_SAVE):
		return {}
	var dados = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO_SAVE))
	if typeof(dados) != TYPE_DICTIONARY:
		return {}
	for c in dados.get("visitadas", []):
		visitadas[c] = true
	grupos = dados.get("grupos", {})
	return dados


func apagar_save() -> void:
	if FileAccess.file_exists(ARQUIVO_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO_SAVE))
	visitadas.clear()
	grupos.clear()
