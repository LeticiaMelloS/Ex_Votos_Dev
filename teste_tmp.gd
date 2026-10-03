extends SceneTree
func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://arte/entrada")
	var a := Image.create(1280, 1040, false, Image.FORMAT_RGBA8)
	for y in 1040:
		for x in range(0, 1280, 8):
			a.fill_rect(Rect2i(x, y, 8, 1), Color(float(x) / 1280.0, float(y) / 1040.0, 0.5))
	a.fill_rect(Rect2i(100, 100, 200, 200), Color(0.8, 0.05, 0.05))
	a.save_png(dir + "/ia_e4_gerada.png")
	var d := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	d.fill(Color(0.1, 0.1, 0.1))
	d.save_png(dir + "/ia_e4_distante.png")
	var o := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	o.fill(Color(0.93, 0.9, 0.82))
	o.fill_rect(Rect2i(400, 300, 200, 500), Color(0.1, 0.08, 0.07))
	o.save_png(dir + "/ia_teste_objeto.png")
	quit()
