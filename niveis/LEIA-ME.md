# Mapas das fases

Cada fase é um arquivo de texto. **Cada caractere é um tile de 40×40 px.** Dá para editar no Bloco de Notas: salve e aperte **R** no jogo para recarregar.

A protagonista tem ~1,75 tile de altura. Ela pula ~2,4 tiles e, agarrando a borda, alcança ~5 tiles. Ajoelhada, ocupa menos de 1 tile.

## Cabeçalho

| Linha | O que faz |
|---|---|
| `@nome Texto` | Nome que aparece no topo da tela |
| `@dica Texto` | Mensagem mostrada ao entrar na fase |
| `@escuro 0.8` | Fase escura; o número (0 a 1) é a intensidade |
| `@altar 1 joelhos:D sem_luz:H` | Promessas que o altar 1 oferece. `:D` troca o grupo afetado pela graça |
| `;; texto` | Comentário (ignorado) |

Promessas disponíveis: `joelhos`, `sem_luz`, `carregar`, `nao_correr`. A definição de cada uma fica em `src/promessas.gd`.

## Legenda

| Caractere | Significado |
|---|---|
| `.` ou espaço | Vazio |
| `#` | Pedra (sólido) |
| `P` | Início da protagonista |
| `C` | Checkpoint (onde ela renasce) |
| `G` | Fim da fase |
| `~` | Abismo (volta ao checkpoint) |
| `1`…`9` | Altar de promessas (o número liga à linha `@altar`) |
| `D`, `F` | Portões: sólidos até uma graça do tipo "abrir" |
| `B`, `H` | Ponte / caminho de cera: só existem depois de uma graça do tipo "ativar" |
| `e` | Escadaria (zona do voto "de joelhos"). Marque a célula vazia logo acima de cada degrau |
| `E` | Topo da escadaria: chegar aqui ajoelhada cumpre o voto |
| `T` | Destino do voto "carregar" (moldura dourada) |
| `r` | Limiar de sala: conta uma sala para os prazos. Faça uma linha vertical |
| `z` | Zona de câmera aberta (o zoom se afasta para mostrar a escala) |

Com **Tab** ligado, as zonas `r` e `z` aparecem coloridas.
