class_name Promessas
extends Node
## Sistema de promessas (pagar a prazo).
## Uma promessa = graça (efeito agora) + voto (condição depois) + prazo (em salas).
## No máximo 3 abertas: os três nós da fita.
## Documentação de design: Game Design/biblia/04-sistemas.md (4.1)

signal mensagem(texto: String)

const MAX_ABERTAS := 3
const COR_NO := Color(0.72, 0.07, 0.07)
const COR_NO_VENCENDO := Color(0.2, 0.05, 0.04)
## Queda (em px) que faz a vela carregada cair. 3,5 tiles.
const QUEDA_MAXIMA_CARREGANDO := 140.0

## Catálogo usado nos protótipos. O grupo da graça pode ser trocado por fase
## no arquivo do nível (ex.: "@altar 1 joelhos:F").
const CATALOGO := {
	"joelhos": {
		"texto": "Se eu passar, subo a escadaria de joelhos.",
		"graca": {"tipo": "abrir", "grupo": "D"},
		"graca_txt": "o portão se abre",
		"voto": {"tipo": "joelhos"},
		"voto_txt": "subir a próxima escadaria inteira ajoelhada (segure S)",
		"prazo_salas": 3,
	},
	"sem_luz": {
		"texto": "Não acendo a vela por três salas.",
		"graca": {"tipo": "ativar", "grupo": "H"},
		"graca_txt": "um caminho de cera aparece",
		"voto": {"tipo": "sem_luz", "salas": 3},
		"voto_txt": "atravessar as próximas 3 salas com a vela apagada",
		"prazo_salas": 0,
	},
	"carregar": {
		"texto": "Levo esta vela até o altar de cima.",
		"graca": {"tipo": "ativar", "grupo": "B"},
		"graca_txt": "uma ponte de cera se forma",
		"voto": {"tipo": "carregar"},
		"voto_txt": "levar a vela até a moldura dourada sem cair de muito alto (sem correr, sem se agarrar)",
		"prazo_salas": 4,
	},
	"vela_dentro": {
		"texto": "Se eu passar, acendo uma vela no altar de dentro.",
		"graca": {"tipo": "abrir", "grupo": "F"},
		"graca_txt": "a grade se abre",
		"voto": {"tipo": "chegar"},
		"voto_txt": "chegar até a vela do altar de dentro (moldura dourada)",
		"prazo_salas": 2,
	},
	"vela_irmandade": {
		"texto": "Se eu passar, acendo uma vela no altar da irmandade.",
		"graca": {"tipo": "abrir", "grupo": "F"},
		"graca_txt": "a grade da capela se abre",
		"voto": {"tipo": "chegar_sala", "sala": "C5-05"},
		"voto_txt": "chegar ao altar da Igreja da Irmandade, no Alto da Cruz",
		"prazo_salas": 4,
	},
	"nao_correr": {
		"texto": "Não corro até o fim da ladeira.",
		"graca": {"tipo": "salto_forte", "usos": 1},
		"graca_txt": "o próximo pulo vai muito mais alto",
		"voto": {"tipo": "nao_correr", "salas": 2},
		"voto_txt": "não correr nas próximas 2 salas",
		"prazo_salas": 0,
	},
}

var nivel: Nivel
var jogadora: Protagonista
## Onde as criaturas são criadas (camada de brilho, acima da escuridão).
var camada_criaturas: Node
## Chamado quando uma criatura alcança a jogadora.
var ao_ser_pega: Callable

var abertas: Array[Dictionary] = []
var criaturas: Array[Criatura] = []
var _feitas_no_altar := {}  # "altar:id" -> true
var _salas := {}  # coluna do limiar -> true (cada sala conta uma vez)
var cumpridas := 0
## No modo Mundo: código da sala atual (as salas contam para os prazos e prefixam os altares).
var sala_atual := ""
var quebradas := 0


func _ready() -> void:
	jogadora.aterrissou.connect(_ao_aterrissar)


## Modo Mundo: cada sala nova em que ela entra conta uma sala para os prazos.
func registrar_sala(codigo: String) -> void:
	sala_atual = codigo
	if not _salas.has(codigo):
		_salas[codigo] = true


func _chave(altar: String, pid: String) -> String:
	return "%s/%s:%s" % [sala_atual, altar, pid]


func salas_visitadas() -> int:
	return _salas.size()


func fita_cheia() -> bool:
	return abertas.size() >= MAX_ABERTAS


## Opções que um altar oferece agora: promessas novas e dívidas a quitar.
func opcoes_do_altar(altar: String) -> Array[Dictionary]:
	var ops: Array[Dictionary] = []
	for item in nivel.meta.get("altar_" + altar, []):
		var partes: PackedStringArray = String(item).split(":")
		var pid := partes[0]
		if not CATALOGO.has(pid) or _feitas_no_altar.has(_chave(altar, pid)):
			continue
		# Sem a mão, não há como carregar nada.
		if CATALOGO[pid]["voto"]["tipo"] == "carregar" and not jogadora.tem_mao:
			continue
		var grupo := partes[1] if partes.size() > 1 else ""
		ops.append({"tipo": "promessa", "id": pid, "grupo": grupo})
	for c in criaturas:
		if not c.quitando:
			ops.append({"tipo": "quitar", "criatura": c, "id": c.promessa_id})
	return ops


func texto_da_opcao(op: Dictionary) -> String:
	var d: Dictionary = CATALOGO[op["id"]]
	if op["tipo"] == "quitar":
		return "Pagar atrasado: \"%s\"\n      Sem graça nova. Voto em dobro: %s." % [d["texto"], d["voto_txt"]]
	var prazo := ""
	if d["prazo_salas"] > 0:
		prazo = "   Prazo: %d salas." % d["prazo_salas"]
	return "\"%s\"\n      Graça: %s.   Voto: %s.%s" % [d["texto"], d["graca_txt"], d["voto_txt"], prazo]


func escolher(op: Dictionary, altar: String) -> void:
	if fita_cheia():
		mensagem.emit("A fita não tem mais nós.")
		return
	var d: Dictionary = CATALOGO[op["id"]]
	var p := {
		"id": op["id"],
		"def": d,
		"altar": altar,
		"inicio_salas": salas_visitadas(),
		"fator": 1,
		"divida": null,
		"sala": sala_atual,
	}
	if op["tipo"] == "quitar":
		var c: Criatura = op["criatura"]
		c.quitando = true
		p["fator"] = 2
		p["divida"] = c
		p["altar"] = c.altar
		mensagem.emit("Você promete pagar o que deve.")
	else:
		_feitas_no_altar[_chave(altar, op["id"])] = true
		var graca: Dictionary = d["graca"].duplicate()
		if op["grupo"] != "":
			graca["grupo"] = op["grupo"]
		_aplicar_graca(graca)
		mensagem.emit("Prometido. A graça foi concedida: %s." % d["graca_txt"])
	abertas.append(p)
	_iniciar_voto(p)


func _aplicar_graca(g: Dictionary) -> void:
	match g["tipo"]:
		"abrir":
			nivel.ativar_grupo(g["grupo"], false)
		"ativar":
			nivel.ativar_grupo(g["grupo"], true)
		"salto_forte":
			jogadora.pulos_fortes += g.get("usos", 1)


func _iniciar_voto(p: Dictionary) -> void:
	match p["def"]["voto"]["tipo"]:
		"sem_luz":
			jogadora.definir_luz(false)
		"carregar":
			jogadora.carregando = true


func _encerrar_voto(p: Dictionary) -> void:
	if p["def"]["voto"]["tipo"] == "carregar":
		jogadora.carregando = abertas.any(func(o): return o["def"]["voto"]["tipo"] == "carregar")


## Chamado todo quadro pelo main.
func processar() -> void:
	if nivel.celula(jogadora.centro()) == "r":
		var col := nivel.coluna(jogadora.global_position)
		if not _salas.has(col):
			_salas[col] = true
	for p in abertas.duplicate():
		_checar(p)
	_atualizar_fita()


func _passadas(p: Dictionary) -> int:
	return salas_visitadas() - p["inicio_salas"]


func _checar(p: Dictionary) -> void:
	var v: Dictionary = p["def"]["voto"]
	var fator: int = p["fator"]
	match v["tipo"]:
		"joelhos":
			var c := nivel.celula(jogadora.global_position - Vector2(0, 10))
			if c == "e" or c == "E":
				if not jogadora.ajoelhada:
					_falhar(p, "Você se levantou na escadaria.")
					return
				if c == "E":
					_cumprir(p)
					return
		"sem_luz":
			if jogadora.luz_acesa:
				_falhar(p, "Você acendeu a vela.")
				return
			if _passadas(p) >= v["salas"] * fator:
				_cumprir(p)
				return
		"nao_correr":
			if jogadora.esta_correndo():
				_falhar(p, "Você correu.")
				return
			if _passadas(p) >= v["salas"] * fator:
				_cumprir(p)
				return
		"carregar", "chegar":
			if nivel.celula(jogadora.centro()) == "T":
				_cumprir(p)
				return
		"chegar_sala":
			if sala_atual == v["sala"]:
				_cumprir(p)
				return
	var prazo: int = p["def"]["prazo_salas"] * fator
	if prazo > 0 and _passadas(p) >= prazo:
		_falhar(p, "O prazo acabou.")


func _ao_aterrissar(altura_queda: float) -> void:
	if altura_queda <= QUEDA_MAXIMA_CARREGANDO:
		return
	for p in abertas.duplicate():
		if p["def"]["voto"]["tipo"] == "carregar":
			_falhar(p, "A vela caiu e se partiu.")


func _cumprir(p: Dictionary) -> void:
	abertas.erase(p)
	_encerrar_voto(p)
	cumpridas += 1
	var c: Criatura = p["divida"]
	if c != null:
		criaturas.erase(c)
		c.dissolver()
		mensagem.emit("A dívida foi paga. A criatura se desfaz em cera.")
	else:
		mensagem.emit("Promessa cumprida. Um ex-voto de agradecimento aparece no altar.")
	if nivel.altares.has(p["altar"]) and p.get("sala", sala_atual) == sala_atual:
		nivel.adicionar_ex_voto(nivel.pe_da_celula(nivel.altares[p["altar"]]))


func _falhar(p: Dictionary, motivo: String) -> void:
	abertas.erase(p)
	_encerrar_voto(p)
	quebradas += 1
	var antiga: Criatura = p["divida"]
	if antiga != null:
		antiga.quitando = false
		mensagem.emit(motivo + " A dívida continua.")
		return
	var c := Criatura.new()
	c.alvo = jogadora
	c.altar = p["altar"]
	c.promessa_id = p["id"]
	if nivel.altares.has(p["altar"]) and p.get("sala", sala_atual) == sala_atual:
		c.origem = nivel.pe_da_celula(nivel.altares[p["altar"]]) - Vector2(0, 40)
	else:
		c.origem = jogadora.global_position - Vector2(jogadora.direcao * 300, 60)
	c.pegou.connect(ao_ser_pega)
	camada_criaturas.add_child(c)
	criaturas.append(c)
	mensagem.emit(motivo + " A promessa não foi paga. Algo nasce da cera.")


func _atualizar_fita() -> void:
	var cores: Array[Color] = []
	for p in abertas:
		var limite: int = p["def"]["prazo_salas"]
		if limite == 0:
			limite = p["def"]["voto"].get("salas", 0)
		limite *= p["fator"]
		var urgencia := 0.0
		if limite > 0:
			urgencia = clampf(float(_passadas(p)) / limite, 0.0, 1.0)
		cores.append(COR_NO.lerp(COR_NO_VENCENDO, urgencia))
	jogadora.nos = cores


func resumo_debug() -> String:
	var linhas := PackedStringArray()
	linhas.append("Salas visitadas: %d   Cumpridas: %d   Quebradas: %d   Criaturas: %d" % [salas_visitadas(), cumpridas, quebradas, criaturas.size()])
	for p in abertas:
		linhas.append("  • %s (%d salas desde a promessa)%s" % [p["id"], _passadas(p), "  [dívida]" if p["divida"] != null else ""])
	return "\n".join(linhas)
