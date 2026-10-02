class_name Oferendas
extends Node
## O corpo como moeda (pagar à vista). Cada altar de oferta pede uma parte
## específica do corpo. A oferta é permanente: dá um poder e tira uma capacidade.
## Documentação de design: seção 7.2 do documento de conceito.

signal mensagem(texto: String)

const PARTES := {
	"t": {
		"titulo": "ALTAR DAS TRANÇAS",
		"pergunta": "Deixar as tranças no altar?",
		"ganha": "a trança vira corda e desce do alto da parede",
		"perde": "nada que se veja no caminho. Só você muda.",
	},
	"m": {
		"titulo": "ALTAR DA MÃO",
		"pergunta": "Deixar a mão no altar?",
		"ganha": "as mãozinhas de cera das paredes se abrem e viram apoio quando você chega perto",
		"perde": "agarrar bordas e carregar coisas. Para sempre.",
	},
}

var nivel: Nivel
var jogadora: Protagonista


func ja_ofertado(altar: String) -> bool:
	return nivel.oferendas.has(altar)


func texto_do_altar(altar: String) -> String:
	var d: Dictionary = PARTES[altar]
	return "%s\n\n%s\n\n      Ganha: %s.\n      Perde: %s\n\n1 — Ofertar\n\nEsc — ainda não" % [
		d["titulo"], d["pergunta"], d["ganha"], d["perde"]]


func ofertar(altar: String) -> void:
	if altar == "m" and jogadora.carregando:
		mensagem.emit("Suas mãos estão ocupadas.")
		return
	match altar:
		"t":
			jogadora.tem_trancas = false
			nivel.ativar_grupo("K", true)
		"m":
			jogadora.tem_mao = false
			jogadora.pode_agarrar = false
	nivel.registrar_oferenda(altar)
	mensagem.emit("♪ Uma incelência ecoa pela sala. ♪   O que foi seu agora pertence ao altar.")


## Chamado todo quadro pelo main: as mãos da parede respondem à protagonista.
func processar() -> void:
	nivel.atualizar_maos(jogadora.centro(), not jogadora.tem_mao)
