"""Checagem aproximada de alcance dentro das salas (niveis/salas/*.txt).

Simula, numa grade de tiles, o que a protagonista consegue fazer
(valores "com folga" do guia de level design):
  - andar; ajoelhada, passar em vão de 1 tile;
  - pular (movimento à Hollow Knight): até 4 tiles para cima; distância 6 sem subir,
    5 subindo até 3, 4 subindo 4;
  - cair de qualquer altura; cravos (^) não são chão;
  - escadas (L) e, com --corda, cordas (K);
  - agarrar bordas de 5 a 6 tiles acima (--sem-agarrar desliga);
  - cera fina (w) sempre derrete; cera velha (W) só com --irmandade (a vela da irmandade).
Para cada sala, diz quais passagens (bordas abertas) NÃO são alcançáveis a partir de cada entrada.
É uma aproximação: serve para achar bloqueios, não substitui jogar.

Uso: python ferramentas/checar_salas.py [CÓDIGO ...] [--sem-agarrar] [--corda] [--irmandade]
"""
import io
import os
import sys
from collections import deque

PASTA = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "niveis", "salas")
SOLIDO = set("#DFW")


def ler(cod):
    linhas = io.open(os.path.join(PASTA, cod + ".txt"), encoding="utf-8").read().split("\n")
    g = [l for l in linhas if l and not l.startswith((";;", "@"))]
    w = max(len(l) for l in g)
    return [l.ljust(w, ".") for l in g]


class Sala:
    def __init__(self, cod, agarrar=True, corda=False, irmandade=False):
        self.cod, self.g = cod, ler(cod)
        self.solidos = SOLIDO - {"W"} if irmandade else SOLIDO
        self.H, self.W = len(self.g), len(self.g[0])
        self.agarrar, self.corda = agarrar, corda

    def c(self, x, y):
        if x < 0 or x >= self.W or y < 0 or y >= self.H:
            return "."
        return self.g[y][x]

    def solido(self, x, y):
        return self.c(x, y) in self.solidos

    def livre(self, x, y):
        return not self.solido(x, y)

    def escada(self, x, y):
        ch = self.c(x, y)
        return ch == "L" or (ch == "K" and self.corda)

    def apoio(self, x, y):
        return self.solido(x, y + 1)

    def em_pe(self, x, y):
        return self.livre(x, y) and self.livre(x, y - 1)

    def parada(self, x, y):
        return 0 <= x < self.W and self.livre(x, y) and self.c(x, y) != "^"             and (self.apoio(x, y) or self.escada(x, y))

    def cair(self, x, y):
        """Cai de (x, y) até achar apoio ou escada; sai por baixo se não houver chão."""
        if x < 0 or x >= self.W:
            return ("saida", "esquerda" if x < 0 else "direita", y)
        while True:
            if y >= self.H:
                return ("saida", "baixo", x)
            if self.solido(x, y) or self.c(x, y) == "^":
                return None
            if self.apoio(x, y) or self.escada(x, y):
                return (x, y)
            y += 1

    def vizinhos(self, x, y):
        res = []
        na_escada = self.escada(x, y)
        no_chao = self.apoio(x, y)
        # andar (ajoelhada passa em vão de 1 tile)
        for d in (-1, 1):
            nx = x + d
            if nx < 0 or nx >= self.W:
                res.append(("saida", "esquerda" if nx < 0 else "direita", y))
            elif self.livre(nx, y) and self.c(nx, y) != "^" and (no_chao or na_escada):
                res.append(self.cair(nx, y))
        # escada: subir, descer, sair pelo topo
        if na_escada:
            if y - 1 < 0:
                res.append(("saida", "cima", x))
            elif self.escada(x, y - 1):
                res.append((x, y - 1))
            elif self.livre(x, y - 1):
                for d in (-1, 1):
                    if self.livre(x + d, y - 1):
                        res.append(self.cair(x + d, y - 1))
            if self.livre(x, y + 1):
                res.append(self.cair(x, y + 1) if not self.escada(x, y + 1) else (x, y + 1))
        elif no_chao and self.escada(x, y - 1):
            res.append((x, y - 1))
        # pulo
        if no_chao and self.em_pe(x, y):
            for dy in range(0, 5):
                alcance = {0: 6, 1: 5, 2: 5, 3: 5, 4: 4}[dy]
                for d in (-1, 1):
                    for dx in range(1, alcance + 1):
                        tx, ty = x + d * dx, y - dy
                        topo = min(y, ty)
                        livre = self.livre(x, y - 2) and all(self.livre(x + d * k, r) for k in range(1, dx + 1)
                                                                 for r in range(topo - 2, topo + 1))
                        if not livre:
                            break
                        if tx < 0 or tx >= self.W:
                            res.append(("saida", "esquerda" if tx < 0 else "direita", ty))
                            break
                        if self.parada(tx, ty) and self.livre(tx, ty - 1):
                            res.append((tx, ty))
                        elif dy == 0:
                            res.append(self.cair(tx, ty))
            for k in (1, 2, 3, 4):
                if self.escada(x, y - k) and all(self.livre(x, y - j) for j in range(0, k + 1)):
                    res.append((x, y - k))
        # agarrar bordas (5 a 6 tiles acima)
        if self.agarrar and no_chao and self.em_pe(x, y):
            for d in (-1, 1):
                for dy in (5, 6):
                    wx = x + d
                    if all(self.solido(wx, y - j) for j in range(0, dy)) and self.em_pe(wx, y - dy) \
                            and all(self.livre(x, y - j) for j in range(0, dy + 1)):
                        res.append((wx, y - dy))
        return [r for r in res if r]

    def passagens(self):
        """{célula da borda: nome da passagem} (trechos contínuos de células livres)."""
        mapa = {}
        bordas = [("esquerda", [(0, y) for y in range(self.H)]), ("direita", [(self.W - 1, y) for y in range(self.H)]),
                  ("cima", [(x, 0) for x in range(self.W)]), ("baixo", [(x, self.H - 1) for x in range(self.W)])]
        for lado, cels in bordas:
            atual = None
            for (x, y) in cels:
                if self.livre(x, y):
                    if atual is None:
                        atual = f"{lado}@{y if lado in ('esquerda', 'direita') else x}"
                    mapa[(x, y)] = atual
                else:
                    atual = None
        return mapa

    def explorar(self, inicio, mapa):
        vistos, fila, saidas = {inicio}, deque([inicio]), set()
        while fila:
            x, y = fila.popleft()
            for cel in ((x, y), (x, y - 1)):
                if cel in mapa:
                    saidas.add(mapa[cel])
            for v in self.vizinhos(x, y):
                if v[0] == "saida":
                    lado, k = v[1], v[2]
                    cel = {"esquerda": (0, k), "direita": (self.W - 1, k), "cima": (k, 0), "baixo": (k, self.H - 1)}[lado]
                    for dk in (0, -1, 1):
                        c2 = (cel[0], cel[1] + dk) if lado in ("esquerda", "direita") else (cel[0] + dk, cel[1])
                        if c2 in mapa:
                            saidas.add(mapa[c2])
                            break
                    continue
                if v not in vistos:
                    vistos.add(v)
                    fila.append(v)
        return saidas


def checar(cod, agarrar, corda, irmandade=False):
    s = Sala(cod, agarrar, corda, irmandade)
    mapa = s.passagens()
    grupos = {}
    for cel, nome in mapa.items():
        grupos.setdefault(nome, []).append(cel)
    problemas = []
    for nome, cels in grupos.items():
        lado = nome.split("@")[0]
        if lado in ("esquerda", "direita"):
            x = 1 if lado == "esquerda" else s.W - 2
            y = max(c[1] for c in cels)
        else:
            x = sorted(c[0] for c in cels)[len(cels) // 2]
            y = 1 if lado == "cima" else s.H - 3
        pos = (x, y) if s.escada(x, y) else s.cair(x, y)
        if not pos or pos[0] == "saida":
            continue
        faltam = [o for o in grupos if o != nome and o not in s.explorar(pos, mapa)]
        if faltam:
            problemas.append(f"   de {nome}: não alcança {', '.join(faltam)}")
    return len(grupos), problemas


def main():
    cods = [a for a in sys.argv[1:] if not a.startswith("--")]
    agarrar = "--sem-agarrar" not in sys.argv
    corda = "--corda" in sys.argv
    irmandade = "--irmandade" in sys.argv
    cods = cods or sorted(f[:-4] for f in os.listdir(PASTA) if f.endswith(".txt"))
    com_problema = 0
    for cod in cods:
        n, probs = checar(cod, agarrar, corda, irmandade)
        print(f"{cod}: {'ok' if not probs else 'atenção'} ({n} passagens)")
        for p in probs:
            print(p)
        com_problema += 1 if probs else 0
    print(f"\n{len(cods)} sala(s), {com_problema} com atenção. (agarrar={'sim' if agarrar else 'não'}, corda={'sim' if corda else 'não'}, vela da irmandade={'sim' if irmandade else 'não'})")


if __name__ == "__main__":
    main()
