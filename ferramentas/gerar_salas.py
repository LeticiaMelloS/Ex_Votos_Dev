"""Gera um greybox inicial para cada sala de mundo/salas.csv que ainda não tem arquivo.

Cada sala vira niveis/salas/<CÓDIGO>.txt, com 48 × 27 tiles por célula:
paredes, chão, aberturas alinhadas com as salas vizinhas (as mesmas nos dois lados),
escadas nas passagens verticais, altares, oferta e portões nas saídas com requisito.

NUNCA sobrescreve um arquivo que já existe: as salas editadas à mão ficam a salvo.
Para gerar de novo uma sala, apague (ou renomeie) o arquivo dela.
Rode com gerar_salas.bat (duplo clique).
"""
import csv
import io
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUNDO = os.path.join(RAIZ, "mundo")
SALAS = os.path.join(RAIZ, "niveis", "salas")
CW, CH = 48, 27  # tiles por célula
ABERTURA = 5     # altura das passagens laterais, em tiles
LARG_BURACO = 1  # passagens verticais: só a coluna da escada (ao sair dela, o chão está dos dois lados)

# Conteúdo especial por sala (o resto vem da planilha).
PROMESSAS = {"C4-02": "vela_irmandade"}
FALAS = {
    "C1-04": "Tem promessa pendurada em você, menina. Promessa que não é sua.",
    "C5-05": "Sua mãe acendia vela aqui toda sexta. Faz tempo que não vem.",
}
OFERTAS = {"C4-08": "t", "M5": "m"}


def ler(nome):
    with io.open(os.path.join(MUNDO, nome), encoding="utf-8-sig") as f:
        return [r for r in csv.DictReader(f, delimiter=";") if (r.get("codigo") or r.get("de") or "").strip()]


def ret(d):
    return int(d["x"]), int(d["y"]), int(d["largura"]), int(d["altura"])


def borda_comum(a, b):
    ax, ay, aw, ah = ret(a)
    bx, by, bw, bh = ret(b)
    if bx == ax + aw or bx + bw == ax:
        ini, fim = max(ay, by), min(ay + ah, by + bh)
        if ini < fim:
            return ("direita" if bx == ax + aw else "esquerda", ini, fim)
    if by == ay + ah or by + bh == ay:
        ini, fim = max(ax, bx), min(ax + aw, bx + bw)
        if ini < fim:
            return ("baixo" if by == ay + ah else "cima", ini, fim)
    return None


class Sala:
    def __init__(self, s):
        self.s = s
        self.x, self.y, self.w, self.h = ret(s)
        self.W, self.H = self.w * CW, self.h * CH
        self.g = [["." for _ in range(self.W)] for _ in range(self.H)]
        for col in range(self.W):
            self.g[0][col] = "#"
            self.g[self.H - 2][col] = "#"
            self.g[self.H - 1][col] = "#"
        for lin in range(self.H):
            self.g[lin][0] = "#"
            self.g[lin][self.W - 1] = "#"

    def por(self, lin, col, c):
        if 0 <= lin < self.H and 0 <= col < self.W:
            self.g[lin][col] = c

    def abertura_lateral(self, lado, cel_ini, cel_fim, portao=False):
        """Passagem na parede esquerda/direita, no chão da célula mais baixa em comum."""
        cy = cel_fim - 1
        chao = (cy - self.y + 1) * CH - 2
        col = 0 if lado == "esquerda" else self.W - 1
        for lin in range(chao - ABERTURA, chao):
            self.por(lin, col, portao if isinstance(portao, str) else ("D" if portao else "."))
        if chao != self.H - 2:
            # Passagem no meio da altura: uma beirada e uma escada até ela.
            passo = 1 if lado == "esquerda" else -1
            for i in range(0, 9):
                self.por(chao, col + passo * i, "#")
            esc = col + passo * 9
            for lin in range(chao - 1, self.H - 2):
                self.por(lin, esc, "L")

    def abertura_vertical(self, lado, cel_ini, cel_fim, tipo="."):
        """Buraco no chão ('baixo') ou no teto ('cima'), com escada para subir."""
        meio = int((cel_ini + cel_fim) / 2 * CW) - self.x * CW
        cols = range(meio - LARG_BURACO // 2, meio - LARG_BURACO // 2 + LARG_BURACO)
        if lado == "baixo":
            for col in cols:
                for lin in (self.H - 2, self.H - 1):
                    self.por(lin, col, tipo if tipo != "." else ".")
            if tipo == ".":
                for lin in range(self.H - 3, self.H):
                    self.por(lin, meio, "L")
        else:
            for col in cols:
                self.por(0, col, ".")
            for lin in range(0, self.H - 2):
                self.por(lin, meio, "L")

    def chao_meio(self, c, desloc=0):
        self.por(self.H - 3, self.W // 2 + desloc, c)

    def texto(self, cab):
        return "\n".join(cab) + "\n" + "\n".join("".join(l) for l in self.g) + "\n"


def main():
    os.makedirs(SALAS, exist_ok=True)
    salas = ler("salas.csv")
    ligacoes = ler("ligacoes.csv")
    por_cod = {s["codigo"]: s for s in salas}
    criadas = 0
    for s in salas:
        caminho = os.path.join(SALAS, s["codigo"] + ".txt")
        if os.path.exists(caminho):
            continue
        sala = Sala(s)
        # Vizinhas ligadas
        for outra in [c.strip() for c in s["liga"].split(",") if c.strip()]:
            o = por_cod.get(outra)
            bc = borda_comum(s, o) if o else None
            if not bc:
                continue
            lado, ini, fim = bc
            if lado in ("esquerda", "direita"):
                grade = s["codigo"] == "C4-02" and outra == "C4-08"  # a grade da Capela das Tranças (abre com a promessa)
                sala.abertura_lateral(lado, ini, fim, "F" if grade else False)
            else:
                sala.abertura_vertical(lado, ini, fim)
        # Passagens para outras áreas (ligacoes.csv)
        for l in ligacoes:
            for (kx, ky, ox, oy, lado_area) in (("x1", "y1", "x2", "y2", "de"), ("x2", "y2", "x1", "y1", "para")):
                if l[lado_area] != s["area"]:
                    continue
                px, py = int(l[kx]), int(l[ky])
                if not (sala.x <= px < sala.x + sala.w and sala.y <= py < sala.y + sala.h):
                    continue
                if lado_area == "para" and l["tipo"] == "atalho":
                    continue  # chegada de atalho: a porta só abre do outro lado
                dx, dy = int(l[ox]) - px, int(l[oy]) - py
                dentro = (px, py)
                # ligação dentro da mesma sala/vizinha já tratada pelo "liga"
                alvo = next((c for c, o in por_cod.items() if c != s["codigo"]
                             and int(o["x"]) <= int(l[ox]) < int(o["x"]) + int(o["largura"])
                             and int(o["y"]) <= int(l[oy]) < int(o["y"]) + int(o["altura"])), None)
                if alvo and alvo in s["liga"]:
                    continue
                travada = l["tipo"] == "final" or "Andor" in l["requisito"]
                if abs(dx) > abs(dy):
                    sala.abertura_lateral("direita" if dx > 0 else "esquerda", py, py + 1, portao=travada)
                elif dy > 0:
                    sala.abertura_vertical("baixo", px, px + 1, tipo="D" if travada else ".")
                else:
                    sala.abertura_vertical("cima", px, px + 1)
        cab = [f";; Sala {s['codigo']} · {s['nome']} (área {s['area']}). Greybox gerado por ferramentas/gerar_salas.py: edite à vontade.",
               f";; Conteúdo: {s['conteudo']}",
               f";; Propósito: {s['proposito']}",
               f"@nome {s['codigo']} · {s['nome']}",
               f"@dica {s['proposito']}",
               f"@sala {s['codigo']}"]
        if s["codigo"] == "C1-01":
            sala.por(sala.H - 3, 4, "P")
        if s["codigo"] in OFERTAS:
            sala.chao_meio(OFERTAS[s["codigo"]])
        elif s["altar"].strip():
            sala.chao_meio("1")
            prom = PROMESSAS.get(s["codigo"], "")
            cab.append(f"@altar 1 {prom}".rstrip())
        if s["tipo"] in ("história", "segredo"):
            sala.chao_meio("?", -6)
            cab.append(f"@bilhete {s['conteudo']}")
        if s["codigo"] in FALAS:
            sala.chao_meio("!", 6)
            cab.append(f"@fala {FALAS[s['codigo']]}")
        if s["tipo"] == "escala":
            for lin in range(1, sala.H - 2):
                for col in range(1, sala.W - 1):
                    if sala.g[lin][col] == ".":
                        sala.g[lin][col] = "z"
        with io.open(caminho, "w", encoding="utf-8", newline="\n") as f:
            f.write(sala.texto(cab))
        criadas += 1
    print(f"{criadas} sala(s) criada(s) em niveis/salas/ ({len(salas) - criadas} já existiam e não foram tocadas).")


if __name__ == "__main__":
    main()
