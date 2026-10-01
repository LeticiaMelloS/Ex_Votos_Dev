class_name Hud
extends CanvasLayer
## Textos provisórios do protótipo: mensagens, menu do altar e painel de debug.
## Na versão final, quase nada disto fica na tela (ver seção 7.5 do documento).

const COR_TEXTO := Color(0.95, 0.92, 0.85)

var _mensagem := Label.new()
var _dica := Label.new()
var _debug := Label.new()
var _titulo := Label.new()
var _menu_fundo := ColorRect.new()
var _menu := Label.new()
var _tween: Tween


func _ready() -> void:
	layer = 10
	_configurar(_titulo, 24, Vector2(24, 16), Vector2(1200, 40))
	_configurar(_debug, 20, Vector2(24, 56), Vector2(1400, 400))
	_configurar(_mensagem, 30, Vector2(160, 930), Vector2(1600, 100))
	_mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_configurar(_dica, 26, Vector2(160, 870), Vector2(1600, 50))
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_menu_fundo.color = Color(0.05, 0.04, 0.03, 0.9)
	_menu_fundo.position = Vector2(260, 220)
	_menu_fundo.size = Vector2(1400, 560)
	add_child(_menu_fundo)
	_configurar(_menu, 28, Vector2(300, 250), Vector2(1320, 500))
	_menu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fechar_menu()
	_debug.visible = false


func _configurar(l: Label, tamanho: int, pos: Vector2, tam: Vector2) -> void:
	l.position = pos
	l.size = tam
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", COR_TEXTO)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)


func mostrar_mensagem(texto: String, duracao := 4.0) -> void:
	if _tween:
		_tween.kill()
	_mensagem.text = texto
	_mensagem.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(duracao)
	_tween.tween_property(_mensagem, "modulate:a", 0.0, 1.0)


func definir_titulo(texto: String) -> void:
	_titulo.text = texto


func definir_dica(texto: String) -> void:
	_dica.text = texto


func abrir_menu(texto: String) -> void:
	_menu.text = texto
	_menu.visible = true
	_menu_fundo.visible = true


func fechar_menu() -> void:
	_menu.visible = false
	_menu_fundo.visible = false


func alternar_debug() -> void:
	_debug.visible = not _debug.visible


func debug_visivel() -> bool:
	return _debug.visible


func definir_debug(texto: String) -> void:
	_debug.text = texto
