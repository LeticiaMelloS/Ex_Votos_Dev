# Ex-Voto — protótipos

Protótipos em **greybox** (retângulos, sem arte) para responder às perguntas da seção 7.6 do documento de conceito. Documentos de design: `OneDrive/Documentos/Game Design/`.

## Como abrir

1. Instale o **Godot 4** (versão estável mais recente, edição padrão, não a .NET): https://godotengine.org/download
2. Abra o Godot → **Importar** → selecione `C:\Dev\ex-voto\project.godot`.
3. Aperte **F5** (ou o ▶ no canto superior direito).

Se o Godot avisar que o projeto é de uma versão anterior, aceite a conversão.

## Controles

| Ação | Teclado | Controle |
|---|---|---|
| Andar | A / D ou ← / → | Analógico esquerdo / direcional |
| Correr | Shift | RB |
| Pular / subir na borda | Espaço, W ou ↑ | A |
| Ajoelhar (segurar) / soltar a borda | S ou ↓ | ↓ |
| Rezar / ofertar no altar | E | X |
| Apagar/acender a vela | Q | Y |
| Escolher no altar | 1, 2, 3 | — |
| Corda: subir / descer / soltar | segurar Espaço ou W / segurar S / uma direção | A / ↓ / direção |
| Reiniciar fase | R | Back |
| Trocar de fase | F1 / F2 / F3 / F4 | — |
| Capturar a tela sem textos (para desenhar por cima) | F12 → salva em `capturas/` | — |
| Alternar greybox / arte | F9 | — |
| Debug (FPS, promessas, zonas) | Tab | — |

**Agarrar bordas:** no ar, perto de uma borda, segure a direção dela. Para subir, aperte pular.

## Fases

- **P1 — Movimento e escala.** Degraus, buracos (o maior exige correr), uma parede para agarrar, um túnel de joelhos e um salão alto com câmera aberta.
  - *Pergunta:* mover é gostoso? A câmera aberta faz ela parecer pequena?
- **P2 — Promessas.** Fase escura com 5 salas. Cada obstáculo tem três saídas: uma promessa, outra promessa ou um caminho difícil sem prometer. Promessa quebrada gera uma criatura de cera que persegue a protagonista. Os altares 3 e 4 permitem pagar a dívida atrasada.
  - *Perguntas:* prometer gera tensão? As pessoas aceitam promessas? Falhar dá culpa ou só irritação?
- **P3 — O corpo como moeda.** Três salas.
  - A parede alta só se vence ofertando as **tranças**, que viram corda.
  - Uma borda para agarrar: a última vez que ela consegue.
  - Um fosso de onde só se sai ofertando a **mão**: ela perde o agarrar (e não pode mais fazer a promessa de carregar), mas as mãozinhas de cera da parede se abrem como apoio quando ela chega perto.
  - *Pergunta:* perder uma capacidade parece significativo ou só frustrante?
- **Sala dos Milagres (F4): greybox da fatia vertical.** Os sete espaços do roteiro de 15 minutos (`Game Design/design/sala-dos-milagres-mapa.md`), juntando tudo:
  - os 10 bilhetes de graça e a fala da benzedeira;
  - a promessa-tutorial da vela e o altar de escolha (joelhos, sem luz ou túnel);
  - a escadaria, a oferta da mão, a parede de mãos e a revelação final.
  - Serve para testar o fluxo inteiro e como **base para desenhar por cima** (F12).

## Estrutura

```
main.tscn            cena inicial (só carrega src/main.gd)
src/main.gd          monta a fase, câmera, escuridão, altares, checkpoints
src/protagonista.gd  movimento (todos os números ajustáveis no topo do arquivo)
src/promessas.gd     catálogo e regras das promessas
src/criatura.gd      criatura da dívida
src/oferendas.gd     ofertas do corpo (tranças, mão)
src/nivel.gd         lê os mapas de texto e cria as colisões
src/hud.gd           textos provisórios
niveis/              mapas das fases (veja niveis/LEIA-ME.md)
src/arte_do_nivel.gd coloca os PNGs das linhas @arte, com parallax
arte/provisoria/     arte provisória (arquivos ia_*.png)
```

## Ajustar a sensação do movimento

Os valores ficam no topo de `src/protagonista.gd`: `vel_andar`, `vel_correr`, `vel_pulo`, `gravidade`, `alcance_agarrar` etc. Mude um por vez e jogue de novo. Anote no diário de playtest o que melhorou.
