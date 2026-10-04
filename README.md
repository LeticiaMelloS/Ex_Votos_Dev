# Ex-Voto — protótipos

Protótipos em **greybox** (retângulos, sem arte) para responder às perguntas da seção 7.6 do documento de conceito. Documentos de design: `OneDrive/Documentos/Game Design/`.

## Como abrir

1. Instale o **Godot 4** (versão estável mais recente, edição padrão, não a .NET): https://godotengine.org/download
2. Abra o Godot → **Importar** → selecione `C:\Dev\ex-voto\project.godot`.
3. Aperte **F5** (ou o ▶ no canto superior direito).

Se o Godot avisar que o projeto é de uma versão anterior, aceite a conversão.

## Modo Mundo (P6)

O jogo **começa no Mundo**: as 60 salas da Cidade das Ladeiras, ligadas pelo mapa em `mundo/`. Atravessar a borda de uma sala leva à vizinha (para os lados pelas passagens, para cima pelas escadas, para baixo pelos buracos).

| Tecla | O que faz |
|---|---|
| M | Mapa das salas visitadas |
| E num altar | Descansa e **salva** (o jogo volta para o último altar) |
| R | Volta ao último altar |
| F6 | Volta ao Mundo (a partir de um protótipo) |
| F8 | Recomeça o Mundo do zero (apaga o salvamento) |

**Salas:** cada uma é um arquivo em `niveis/salas/` (ex.: `C1-01.txt`), no mesmo formato dos mapas de texto. Para criar as salas novas da planilha `mundo/salas.csv`, dê duplo clique em **`gerar_salas.bat`**: ele faz um greybox inicial com as aberturas certas e **nunca sobrescreve** uma sala que já existe.

**Conferir uma sala depois de editar:** `checar_salas.bat` simula o movimento (pulo de 2 tiles, distância 3/5, escadas, joelhos, agarrar) e avisa se alguma passagem ficou inalcançável. Ex.: `checar_salas.bat C1-05 --sem-agarrar`. É aproximado: serve para achar bloqueios, não substitui jogar.

**Já blocadas (percurso principal):** C1-01 a C1-08, C2-06 a C2-11, C4-01, C4-02, C4-07, C4-08. As outras salas ainda são o greybox gerado.

**Saídas para regiões não construídas** (Sala dos Milagres, Sertão, Minas, Santuário) mostram um aviso. Portões (`D`) marcam as saídas com requisito: a porteira, a cripta e a porta do final.

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
| Protótipos | F1 / F2 / F3 / F4 | — |
| Mundo | F6 | — |
| Capturar a tela sem textos (para desenhar por cima) | F12 → salva em `capturas/` | — |
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
src/mundo.gd         o mundo: salas, passagens, salvamento
src/mapa_hud.gd      mapa das salas visitadas (M)
niveis/salas/        uma sala por arquivo (gerado por gerar_salas.bat)
ferramentas/         gerar_salas.py e desenhar_mapa.py
src/hud.gd           textos provisórios
niveis/              mapas das fases (veja niveis/LEIA-ME.md)
```

## Ajustar a sensação do movimento

Os valores ficam no topo de `src/protagonista.gd`: `vel_andar`, `vel_correr`, `vel_pulo`, `gravidade`, `alcance_agarrar` etc. Mude um por vez e jogue de novo. Anote no diário de playtest o que melhorou.
