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
| `@sala CÓDIGO` | Identifica a sala do Mundo (gerado automaticamente) |
| `@sem_trancas` | A protagonista começa sem as tranças |
| `@fim Texto` | Mensagem ao chegar no `G` |
| `@bilhete Texto` / `@fala Texto` | Textos dos `?` e `!` (uma linha cada) |
| `;; texto` | Comentário (ignorado) |

Promessas disponíveis: `joelhos`, `sem_luz`, `carregar`, `nao_correr`, `vela_dentro`. A definição de cada uma fica em `src/promessas.gd`.

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
| `t` | Altar das tranças (oferta do corpo) |
| `m` | Altar da mão (oferta do corpo) |
| `L` | Escada de mão: sobe e desce como a corda, mas sempre disponível. No Mundo, liga uma sala à de cima pelo buraco do teto |
| `K` | Corda: só existe depois da oferta das tranças. Faça uma coluna vertical; a célula mais alta deve ficar logo acima do chão onde ela vai sair |
| `M` | Mãozinha de cera na parede: vira apoio (de mão única: atravessa por baixo) depois da oferta da mão, só quando ela está perto. Espaçamento vertical ideal: 2 tiles |
| `Z` | Zona de revelação: câmera bem aberta (o momento do colosso) |
| `?` | Bilhete de graça. Os textos vêm das linhas `@bilhete`, na ordem da esquerda para a direita |
| `!` | NPC que fala sozinha ao se aproximar. Textos nas linhas `@fala`, na mesma ordem |

Com **Tab** ligado, as zonas `r` e `z` aparecem coloridas.

## Salas do Mundo (`niveis/salas/`)

- **Tamanho:** 48 × 27 tiles por célula da planilha (uma sala 2×1 tem 96 × 27).
- **Aberturas:** a passagem entre duas salas precisa estar **no mesmo lugar nas duas**. O `gerar_salas.bat` já cria assim: laterais com 5 tiles de altura no chão da célula mais baixa em comum; verticais com 4 tiles de largura no meio do trecho em comum, com escada (`L`).
- **Ao editar uma sala, mantenha as aberturas onde estão** (ou mude dos dois lados).
