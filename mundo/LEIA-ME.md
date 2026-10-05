# Mundo — mapa geral

O mapa geral do jogo, em dados. **1 célula = 1 tela de jogo** (48 × 27 tiles).

| Arquivo | O que é |
|---|---|
| `areas.csv` | Uma linha por área: código, nome, região, posição (`x`, `y`) e tamanho (`largura`, `altura`) em células, número de salas e de altares, papel, oferta e colosso |
| `ligacoes.csv` | Uma linha por ligação entre áreas: de, para, tipo (`caminho`, `atalho` = mão única de→para, `oculto`, `final`), as duas pontas (`x1`,`y1` dentro de "de"; `x2`,`y2` dentro de "para"), requisito e nota |
| `salas.csv` | Uma linha por sala (preenchido região por região): código, área, nome, posição e tamanho em células, tipo, rota (`principal`, `opcional`, `segredo`), altar (`sim`), `liga` (salas vizinhas ligadas, separadas por vírgula; precisam encostar e listar a volta), `fora` (saída para outra área), requisito, conteúdo e propósito |
| `mapa.png`, `mapa.html`, `mapa_<região>.png/.html` | Gerados automaticamente. **Não edite**: mude os `.csv` e redesenhe |

## Como editar
1. Abra o `.csv` no Excel (ou no Bloco de Notas). O separador é `;`.
2. Mude o que quiser e salve **no mesmo formato** (CSV, separado por ponto e vírgula).
3. Dê duplo clique em `desenhar_mapa.bat` (na pasta do projeto).
4. Abra `mundo/mapa.html` no navegador. Passe o mouse nas áreas e nas ligações para ver os detalhes.

O desenhador **confere os dados** e avisa se há áreas sobrepostas, pontas de ligação fora da área certa ou áreas que não se ligam a nada.

## Salas
Já detalhada: **Cidade das Ladeiras** (60 salas; veja `mapa_cidade.html` e `Game Design/biblia/regioes/1-cidade-das-ladeiras.md`). As listas de salas das outras regiões já estão na bíblia (`biblia/regioes/`) e entram no mesmo `salas.csv` quando forem aprovadas.
