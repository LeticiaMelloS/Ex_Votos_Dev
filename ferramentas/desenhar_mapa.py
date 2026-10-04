"""Desenha o mapa do mundo a partir das planilhas em mundo/.

Entradas:
  mundo/areas.csv     as áreas (posição e tamanho em células; 1 célula = 1 tela)
  mundo/ligacoes.csv  as ligações entre áreas
  mundo/salas.csv     as salas (opcional; preenchido região por região)

Saídas:
  mundo/mapa.png, mundo/mapa.html                    o mundo inteiro
  mundo/mapa_<regiao>.png, mundo/mapa_<regiao>.html  vista ampliada de cada região que já tem salas

Também confere os dados e lista avisos (sobreposições, ligações erradas, contagens).
Rode com desenhar_mapa.bat (duplo clique).
"""
import csv
import html
import io
import os
import unicodedata
from collections import defaultdict, deque

from PIL import Image, ImageDraw, ImageFont

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUNDO = os.path.join(RAIZ, "mundo")
FUNDO = "#15130F"

CORES = {
    "Cidade das Ladeiras": "#C9A227",
    "Sala dos Milagres": "#4F7FBF",
    "Sertão da Romaria": "#7FA34A",
    "Minas": "#3E9C96",
    "Santuário": "#B04A5A",
}
LINHAS = {  # tipo: (cor, espessura, tracejado)
    "caminho": ("#E8E2D0", 3, None),
    "atalho": ("#F2C14E", 3, (8, 6)),
    "oculto": ("#9A9384", 2, (3, 5)),
    "final": ("#E8B930", 5, (14, 8)),
}
NOME_TIPO = {"caminho": "caminho", "atalho": "atalho de mão única (● = chegada)",
             "oculto": "passagem oculta / com requisito", "final": "porta do final"}
ROTA = {"principal": 0.55, "opcional": 0.32, "segredo": 0.16}  # intensidade do preenchimento


# ---------------------------------------------------------------- dados

def ler(nome, obrigatorio=True):
    caminho = os.path.join(MUNDO, nome)
    if not os.path.exists(caminho) and not obrigatorio:
        return []
    with io.open(caminho, encoding="utf-8-sig") as f:
        return [r for r in csv.DictReader(f, delimiter=";") if r.get("codigo", r.get("de", "")).strip()]


def ret(d):
    return int(d["x"]), int(d["y"]), int(d["largura"]), int(d["altura"])


def celulas(d):
    x, y, w, h = ret(d)
    return {(cx, cy) for cx in range(x, x + w) for cy in range(y, y + h)}


def borda_comum(a, b):
    """Segmento de borda (em células) compartilhado por dois retângulos, ou None."""
    ax, ay, aw, ah = ret(a)
    bx, by, bw, bh = ret(b)
    if bx == ax + aw or bx + bw == ax:
        x = ax + aw if bx == ax + aw else ax
        ini, fim = max(ay, by), min(ay + ah, by + bh)
        if ini < fim:
            return ("v", x, ini, fim)
    if by == ay + ah or by + bh == ay:
        y = ay + ah if by == ay + ah else ay
        ini, fim = max(ax, bx), min(ax + aw, bx + bw)
        if ini < fim:
            return ("h", y, ini, fim)
    return None


def conferir(areas, ligacoes, salas):
    avisos = []
    ocup = {}
    for a in areas:
        for c in celulas(a):
            if c in ocup:
                avisos.append(f"Áreas sobrepostas na célula {c}: {ocup[c]} e {a['codigo']}")
            ocup[c] = a["codigo"]
    codigos = {a["codigo"] for a in areas}
    viz = defaultdict(set)
    for l in ligacoes:
        for lado, (kx, ky) in (("de", ("x1", "y1")), ("para", ("x2", "y2"))):
            cod = l[lado]
            if cod not in codigos:
                avisos.append(f"Ligação {l['de']}→{l['para']}: área {cod} não existe")
            elif ocup.get((int(l[kx]), int(l[ky]))) != cod:
                avisos.append(f"Ligação {l['de']}→{l['para']}: a ponta ({l[kx]},{l[ky]}) não está dentro de {cod}")
        viz[l["de"]].add(l["para"])
        if l["tipo"] != "atalho":
            viz[l["para"]].add(l["de"])
    vistos, fila = {"C1"}, deque(["C1"])
    while fila:
        for v in viz[fila.popleft()]:
            if v not in vistos:
                vistos.add(v)
                fila.append(v)
    for c in sorted(codigos - vistos):
        avisos.append(f"Área {c} não é alcançável a partir de C1")

    # Salas
    por_cod = {s["codigo"]: s for s in salas}
    area_por_cod = {a["codigo"]: a for a in areas}
    ocup_s = {}
    for s in salas:
        a = area_por_cod.get(s["area"])
        if not a:
            avisos.append(f"Sala {s['codigo']}: área {s['area']} não existe")
            continue
        fora = celulas(s) - celulas(a)
        if fora:
            avisos.append(f"Sala {s['codigo']} sai da área {s['area']} (células {sorted(fora)[:3]}…)")
        for c in celulas(s):
            if c in ocup_s:
                avisos.append(f"Salas sobrepostas na célula {c}: {ocup_s[c]} e {s['codigo']}")
            ocup_s[c] = s["codigo"]
        for outra in [x.strip() for x in s["liga"].split(",") if x.strip()]:
            o = por_cod.get(outra)
            if not o:
                avisos.append(f"Sala {s['codigo']} liga com {outra}, que não existe")
            elif s["codigo"] not in [x.strip() for x in o["liga"].split(",")]:
                avisos.append(f"Ligação de mão única entre salas: {s['codigo']} → {outra} (falta a volta)")
            elif not borda_comum(s, o):
                avisos.append(f"Salas {s['codigo']} e {outra} estão ligadas mas não encostam")
    contagem = defaultdict(int)
    altares = defaultdict(int)
    for s in salas:
        contagem[s["area"]] += 1
        altares[s["area"]] += 1 if s["altar"].strip() else 0
    info = []
    for a in areas:
        n = contagem.get(a["codigo"], 0)
        if n:
            alvo = int(a["salas"])
            if n != alvo:
                info.append(f"{a['codigo']}: {n} salas detalhadas (meta {alvo})")
            if altares[a["codigo"]] != int(a["altares"]):
                info.append(f"{a['codigo']}: {altares[a['codigo']]} altares nas salas (meta {a['altares']})")
    return avisos, info


# ---------------------------------------------------------------- desenho (comum)

def misturar(cor, fundo, t):
    a = [int(cor.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    b = [int(fundo.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    return "#%02X%02X%02X" % tuple(round(b[i] + (a[i] - b[i]) * t) for i in range(3))


def fonte(tam, negrito=False):
    for nome in (("segoeuib.ttf" if negrito else "segoeui.ttf"), "arial.ttf"):
        try:
            return ImageFont.truetype(os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts", nome), tam)
        except OSError:
            continue
    return ImageFont.load_default()


def quebrar(texto, fnt, largura):
    linhas, atual = [], ""
    for palavra in texto.split():
        teste = (atual + " " + palavra).strip()
        if fnt.getlength(teste) <= largura or not atual:
            atual = teste
        else:
            linhas.append(atual)
            atual = palavra
    if atual:
        linhas.append(atual)
    return linhas


class Vista:
    """Converte células em pixels para um recorte do mundo."""

    def __init__(self, cel, x0, y0, largura, altura, margem=40, lateral=330):
        self.cel, self.x0, self.y0, self.w, self.h = cel, x0, y0, largura, altura
        self.m, self.lateral = margem, lateral

    def px(self, x, y):
        return self.m + (x - self.x0) * self.cel, self.m + (y - self.y0) * self.cel

    def centro(self, x, y):
        a, b = self.px(x, y)
        return a + self.cel / 2, b + self.cel / 2

    def tamanho(self):
        return self.m * 2 + self.w * self.cel + self.lateral, self.m * 2 + self.h * self.cel

    def dentro(self, d):
        x, y, w, h = ret(d)
        return x + w > self.x0 and y + h > self.y0 and x < self.x0 + self.w and y < self.y0 + self.h


def porta(vista, a, b):
    """Pontos de uma 'porta' (traço curto atravessando a borda comum)."""
    bc = borda_comum(a, b)
    if not bc:
        return None
    eixo, pos, ini, fim = bc
    meio = (ini + fim) / 2
    t = vista.cel * 0.18
    if eixo == "v":
        x, y = vista.px(pos, meio)
        return (x - t, y), (x + t, y)
    x, y = vista.px(meio, pos)
    return (x, y - t), (x, y + t)


# ---------------------------------------------------------------- PNG

def tracejar(d, p1, p2, cor, larg, trac):
    if not trac:
        d.line([p1, p2], fill=cor, width=larg)
        return
    (x1, y1), (x2, y2) = p1, p2
    comp = ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5 or 1
    t = 0.0
    while t < comp:
        a, b = t / comp, min(t + trac[0], comp) / comp
        d.line([(x1 + (x2 - x1) * a, y1 + (y2 - y1) * a), (x1 + (x2 - x1) * b, y1 + (y2 - y1) * b)], fill=cor, width=larg)
        t += trac[0] + trac[1]


def png(vista, areas, ligacoes, salas, titulo, subtitulo, totais, detalhe):
    img = Image.new("RGB", vista.tamanho(), FUNDO)
    d = ImageDraw.Draw(img)
    for gx in range(vista.w + 1):
        x, _ = vista.px(vista.x0 + gx, 0)
        d.line([(x, vista.m), (x, vista.m + vista.h * vista.cel)], fill="#24211B")
    for gy in range(vista.h + 1):
        _, y = vista.px(0, vista.y0 + gy)
        d.line([(vista.m, y), (vista.m + vista.w * vista.cel, y)], fill="#24211B")
    area_cor = {a["codigo"]: CORES.get(a["regiao"], "#888888") for a in areas}
    com_salas = {s["area"] for s in salas}
    for a in areas:
        if not vista.dentro(a):
            continue
        x, y, w, h = ret(a)
        (x1, y1), (x2, y2) = vista.px(x, y), vista.px(x + w, y + h)
        cor = area_cor[a["codigo"]]
        d.rectangle([x1 + 2, y1 + 2, x2 - 2, y2 - 2], fill=misturar(cor, FUNDO, 0.12 if a["codigo"] in com_salas else 0.32), outline=cor, width=2)
    f_cod, f_nome = fonte(max(10, vista.cel // 7), True), fonte(max(9, vista.cel // 9))
    por_cod = {s["codigo"]: s for s in salas}
    for s in salas:
        if not vista.dentro(s):
            continue
        x, y, w, h = ret(s)
        (x1, y1), (x2, y2) = vista.px(x, y), vista.px(x + w, y + h)
        cor = area_cor.get(s["area"], "#888888")
        d.rectangle([x1 + 4, y1 + 4, x2 - 4, y2 - 4], fill=misturar(cor, FUNDO, ROTA.get(s["rota"], 0.3)),
                    outline=misturar(cor, "#FFFFFF", 0.3), width=1)
        if s["rota"] == "segredo":
            tracejar(d, (x1 + 4, y1 + 4), (x2 - 4, y1 + 4), "#EEE8D8", 1, (3, 3))
        if detalhe:
            d.text((x1 + 8, y1 + 6), s["codigo"], font=f_cod, fill="#FFFFFF")
            for i, t in enumerate(quebrar(s["nome"], f_nome, (x2 - x1) - 16)[:3]):
                d.text((x1 + 8, y1 + 8 + f_cod.size + i * (f_nome.size + 2)), t, font=f_nome, fill="#EEE8D8")
            marcas = (["ALTAR"] if s["altar"].strip() else []) + (["OFERTA"] if s["tipo"] == "oferta" else []) \
                + (["→ " + s["fora"]] if s["fora"].strip() else [])
            yb = y2 - 8
            for t in reversed(marcas):
                for ln in reversed(quebrar(t, f_nome, (x2 - x1) - 16)[:2]):
                    yb -= f_nome.size + 2
                    d.text((x1 + 8, yb), ln, font=f_nome, fill="#F2C14E")
        elif s["altar"].strip():
            cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
            d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill="#F2C14E")
    for s in salas:
        for outra in [x.strip() for x in s["liga"].split(",") if x.strip()]:
            o = por_cod.get(outra)
            if o and s["codigo"] < outra and vista.dentro(s):
                p = porta(vista, s, o)
                if p:
                    d.line(list(p), fill="#EEE8D8", width=max(2, vista.cel // 22))
    for l in ligacoes:
        cor, larg, trac = LINHAS.get(l["tipo"], LINHAS["caminho"])
        p1, p2 = vista.centro(int(l["x1"]), int(l["y1"])), vista.centro(int(l["x2"]), int(l["y2"]))
        tracejar(d, p1, p2, cor, larg, trac)
        if l["tipo"] == "atalho":
            d.ellipse([p2[0] - 7, p2[1] - 7, p2[0] + 7, p2[1] + 7], fill=cor)
    for a in areas:
        if not vista.dentro(a):
            continue
        x, y, w, h = ret(a)
        tx, ty = vista.px(x, y)
        if detalhe and a["codigo"] in com_salas:
            d.text((tx + 4, ty - 18 if y > vista.y0 else ty + 2), f"{a['codigo']} · {a['nome']}", font=fonte(13, True), fill=area_cor[a["codigo"]])
            continue
        tx, ty = tx + 6, ty + 4
        d.text((tx, ty), a["codigo"] + ("  HUB" if "Hub" in a["papel"] else ""), font=fonte(15, True), fill="#FFFFFF")
        linhas = [a["nome"], f"{a['salas']} salas · {a['altares']} altar(es)"]
        if a["oferta"]:
            linhas.append("Oferta: " + a["oferta"])
        if a["colosso"]:
            linhas.append("Colosso: " + a["colosso"])
        for i, t in enumerate(linhas):
            cor_t = "#F2C14E" if t.startswith(("Oferta", "Colosso")) else "#EEE8D8"
            d.text((tx, ty + 18 + i * 13), t, font=fonte(11), fill=cor_t)
    lx, ly = vista.m + vista.w * vista.cel + 30, vista.m
    d.text((lx, ly), titulo, font=fonte(18, True), fill="#F2E6C8")
    d.text((lx, ly + 26), subtitulo, font=fonte(12), fill="#BDB5A0")
    ly += 64
    for reg, cor in CORES.items():
        if reg in totais:
            d.rectangle([lx, ly, lx + 18, ly + 18], fill=misturar(cor, FUNDO, 0.55), outline=cor)
            d.text((lx + 28, ly), f"{reg}: {totais[reg]} salas", font=fonte(13), fill="#EEE8D8")
            ly += 26
    ly += 10
    for tipo, (cor, larg, trac) in LINHAS.items():
        tracejar(d, (lx, ly + 9), (lx + 40, ly + 9), cor, larg, trac)
        d.text((lx + 50, ly), NOME_TIPO[tipo], font=fonte(13), fill="#EEE8D8")
        ly += 24
    if salas:
        ly += 10
        for rota, t in (("principal", "sala do caminho principal"), ("opcional", "sala opcional"), ("segredo", "sala secreta")):
            d.rectangle([lx, ly, lx + 18, ly + 18], fill=misturar("#C9A227", FUNDO, ROTA[rota]), outline="#B5B0A0")
            d.text((lx + 28, ly), t, font=fonte(13), fill="#EEE8D8")
            ly += 24
        d.line([(lx + 9, ly + 2), (lx + 9, ly + 16)], fill="#EEE8D8", width=3)
        d.text((lx + 28, ly), "passagem entre salas", font=fonte(13), fill="#EEE8D8")
        ly += 24
        d.ellipse([lx + 5, ly + 5, lx + 13, ly + 13], fill="#F2C14E")
        d.text((lx + 28, ly), "altar (descanso)", font=fonte(13), fill="#EEE8D8")
        ly += 24
    ly += 10
    d.text((lx, ly), f"TOTAL: {sum(totais.values())} salas", font=fonte(15, True), fill="#F2E6C8")
    return img


# ---------------------------------------------------------------- HTML

def svg(vista, areas, ligacoes, salas, detalhe):
    W, H = vista.m * 2 + vista.w * vista.cel, vista.m * 2 + vista.h * vista.cel
    p = []
    for gx in range(vista.w + 1):
        x, _ = vista.px(vista.x0 + gx, 0)
        p.append(f'<line x1="{x}" y1="{vista.m}" x2="{x}" y2="{vista.m + vista.h * vista.cel}" class="grade"/>')
    for gy in range(vista.h + 1):
        _, y = vista.px(0, vista.y0 + gy)
        p.append(f'<line x1="{vista.m}" y1="{y}" x2="{vista.m + vista.w * vista.cel}" y2="{y}" class="grade"/>')
    area_cor = {a["codigo"]: CORES.get(a["regiao"], "#888") for a in areas}
    com_salas = {s["area"] for s in salas}
    for a in areas:
        if not vista.dentro(a):
            continue
        x, y, w, h = ret(a)
        x1, y1 = vista.px(x, y)
        cor = area_cor[a["codigo"]]
        dica = html.escape(f"{a['codigo']} · {a['nome']}\n{a['regiao']}\n{a['papel']}\n{a['salas']} salas · {a['altares']} altar(es)"
                           + (f"\nOferta: {a['oferta']}" if a["oferta"] else "") + (f"\nColosso: {a['colosso']}" if a["colosso"] else ""))
        op = 0.10 if a["codigo"] in com_salas else 0.28
        if detalhe and a["codigo"] in com_salas:
            rotulo = f'<text x="{x1 + 4}" y="{y1 - 6 if y > vista.y0 else y1 + 14}" class="area-rot" fill="{cor}">{a["codigo"]} · {html.escape(a["nome"])}</text>'
        else:
            rotulo = (f'<text x="{x1 + 6}" y="{y1 + 18}" class="cod">{a["codigo"]}</text>'
                      f'<text x="{x1 + 6}" y="{y1 + 32}" class="nome">{html.escape(a["nome"])}</text>'
                      f'<text x="{x1 + 6}" y="{y1 + 45}" class="info">{a["salas"]} salas{" · ◆ " + html.escape(a["oferta"]) if a["oferta"] else ""}{" · ✦" if a["colosso"] else ""}</text>')
        p.append(f'<g class="area"><title>{dica}</title><rect x="{x1 + 2}" y="{y1 + 2}" width="{w * vista.cel - 4}" height="{h * vista.cel - 4}" rx="4" '
                 f'fill="{cor}" fill-opacity="{op}" stroke="{cor}" stroke-width="2"/>{rotulo}</g>')
    por_cod = {s["codigo"]: s for s in salas}
    for s in salas:
        if not vista.dentro(s):
            continue
        x, y, w, h = ret(s)
        x1, y1 = vista.px(x, y)
        cor = area_cor.get(s["area"], "#888")
        dica = html.escape(f"{s['codigo']} · {s['nome']}\nTipo: {s['tipo']} · Rota: {s['rota']}" + (" · ALTAR" if s["altar"].strip() else "")
                           + f"\nLiga com: {s['liga']}" + (f"\nSaída: {s['fora']}" if s["fora"] else "")
                           + (f"\nRequisito: {s['requisito']}" if s["requisito"] else "")
                           + f"\n\n{s['conteudo']}\n→ {s['proposito']}")
        dash = ' stroke-dasharray="4 3"' if s["rota"] == "segredo" else ""
        texto = ""
        if detalhe:
            linhas = [f'<text x="{x1 + 8}" y="{y1 + 18}" class="s-cod">{s["codigo"]}</text>']
            fnt = fonte(12)
            for i, t in enumerate(quebrar(s["nome"], fnt, w * vista.cel - 18)[:3]):
                linhas.append(f'<text x="{x1 + 8}" y="{y1 + 34 + i * 14}" class="s-nome">{html.escape(t)}</text>')
            marcas = (["ALTAR"] if s["altar"].strip() else []) + (["OFERTA"] if s["tipo"] == "oferta" else []) \
                + ([f"→ {s['fora']}"] if s["fora"] else [])
            for i, t in enumerate(reversed(marcas)):
                linhas.append(f'<text x="{x1 + 8}" y="{y1 + h * vista.cel - 10 - i * 14}" class="s-marca">{html.escape(t)}</text>')
            texto = "".join(linhas)
        elif s["altar"].strip():
            texto = f'<circle cx="{x1 + w * vista.cel / 2}" cy="{y1 + h * vista.cel / 2}" r="3" fill="#F2C14E"/>'
        p.append(f'<g class="sala"><title>{dica}</title><rect x="{x1 + 4}" y="{y1 + 4}" width="{w * vista.cel - 8}" height="{h * vista.cel - 8}" rx="3" '
                 f'fill="{cor}" fill-opacity="{ROTA.get(s["rota"], .3)}" stroke="#fff" stroke-opacity=".35"{dash}/>{texto}</g>')
    for s in salas:
        for outra in [x.strip() for x in s["liga"].split(",") if x.strip()]:
            o = por_cod.get(outra)
            if o and s["codigo"] < outra and vista.dentro(s):
                pt = porta(vista, s, o)
                if pt:
                    (a1, b1), (a2, b2) = pt
                    p.append(f'<line x1="{a1}" y1="{b1}" x2="{a2}" y2="{b2}" class="porta"/>')
    for l in ligacoes:
        cor, larg, trac = LINHAS.get(l["tipo"], LINHAS["caminho"])
        (x1, y1), (x2, y2) = vista.centro(int(l["x1"]), int(l["y1"])), vista.centro(int(l["x2"]), int(l["y2"]))
        dash = f' stroke-dasharray="{trac[0]} {trac[1]}"' if trac else ""
        dica = html.escape(f"{l['de']} → {l['para']} ({l['tipo']})" + (f"\nRequisito: {l['requisito']}" if l["requisito"] else "")
                           + (f"\n{l['nota']}" if l["nota"] else ""))
        fim = f'<circle cx="{x2}" cy="{y2}" r="6" fill="{cor}"/>' if l["tipo"] == "atalho" else ""
        p.append(f'<g class="lig"><title>{dica}</title><line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{cor}" stroke-width="{larg}"{dash} stroke-linecap="round"/>'
                 f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="transparent" stroke-width="12"/>{fim}</g>')
    return f'<svg width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-label="Mapa">{"".join(p)}</svg>'


def pagina(titulo, subtitulo, corpo_svg, totais, avisos, info, salas, links):
    legenda = "".join(f'<li><span class="sw" style="background:{c}"></span>{html.escape(r)}: <b>{totais[r]}</b> salas</li>'
                      for r, c in CORES.items() if r in totais)
    itens = []
    for k, (c, w, t) in LINHAS.items():
        dash = f' stroke-dasharray="{t[0]} {t[1]}"' if t else ""
        itens.append(f'<li><svg width="44" height="10"><line x1="2" y1="5" x2="42" y2="5" stroke="{c}" stroke-width="{w}"{dash}/></svg>{NOME_TIPO[k]}</li>')
    salas_leg = ""
    if salas:
        salas_leg = ("<h2>Salas</h2><ul><li><span class='sw' style='background:#C9A227;opacity:.55'></span>caminho principal</li>"
                     "<li><span class='sw' style='background:#C9A227;opacity:.32'></span>opcional</li>"
                     "<li><span class='sw' style='background:#C9A227;opacity:.16;outline:1px dashed #ccc'></span>secreta</li>"
                     "<li><svg width='14' height='14'><line x1='7' y1='1' x2='7' y2='13' stroke='#EEE8D8' stroke-width='3'/></svg>passagem entre salas</li></ul>")
    aviso_html = ("<h2>Avisos</h2><ul class='avisos'>" + "".join(f"<li>{html.escape(a)}</li>" for a in avisos) + "</ul>") if avisos \
        else "<p class='ok'>Dados conferidos: sem sobreposições, ligações coerentes, tudo alcançável.</p>"
    info_html = ("<h2>Contagens</h2><ul>" + "".join(f"<li>{html.escape(i)}</li>" for i in info) + "</ul>") if info else ""
    nav = " · ".join(f'<a href="{h}">{html.escape(t)}</a>' for t, h in links)
    return f"""<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(titulo)}</title><style>
:root{{--bg:{FUNDO};--texto:#EEE8D8;--suave:#BDB5A0}}
body{{margin:0;background:var(--bg);color:var(--texto);font-family:"Segoe UI",system-ui,sans-serif}}
main{{display:flex;flex-wrap:wrap;gap:24px;padding:16px}}.mapa{{overflow:auto;max-width:100%}}
.grade{{stroke:#fff;stroke-opacity:.06}}
.cod{{fill:#fff;font-weight:700;font-size:14px}}.nome{{fill:var(--texto);font-size:11px}}.info{{fill:var(--suave);font-size:10px}}
.area-rot{{font-weight:700;font-size:13px}}
.s-cod{{fill:#fff;font-weight:700;font-size:12px}}.s-nome{{fill:var(--texto);font-size:12px}}.s-marca{{fill:#F2C14E;font-size:11px}}
.porta{{stroke:#EEE8D8;stroke-width:4;stroke-linecap:round}}
.area:hover rect,.sala:hover rect{{stroke:#fff;stroke-opacity:1}}.lig:hover line:first-child{{stroke:#fff}}
aside{{min-width:260px;max-width:360px}}h1{{font-size:20px;margin:0 0 4px}}h2{{font-size:15px;margin:18px 0 6px}}
ul{{list-style:none;padding:0;margin:0}}li{{margin:5px 0;font-size:13px;display:flex;gap:8px;align-items:center}}
.sw{{width:14px;height:14px;border-radius:3px;display:inline-block}}.ok{{color:#9fd39a;font-size:13px}}.avisos li{{color:#f2a07b}}
p{{color:var(--suave);font-size:13px}}a{{color:#F2C14E}}</style></head><body><main>
<div class="mapa">{corpo_svg}</div>
<aside><h1>{html.escape(titulo)}</h1><p>{html.escape(subtitulo)} · passe o mouse nas áreas, salas e ligações</p><p>{nav}</p>
<h2>Regiões</h2><ul>{legenda}</ul><p><b>Total: {sum(totais.values())} salas</b></p>
<h2>Ligações entre áreas</h2><ul>{''.join(itens)}</ul>{salas_leg}{aviso_html}{info_html}
<p>Gerado a partir das planilhas em <code>mundo/</code>. Não edite este arquivo: mude os <code>.csv</code> e rode <code>desenhar_mapa.bat</code>.</p></aside></main></body></html>"""


# ---------------------------------------------------------------- principal

def slug(texto):
    t = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode().lower()
    return t.split()[0] if t else "regiao"


def main():
    areas = ler("areas.csv")
    ligacoes = ler("ligacoes.csv")
    salas = ler("salas.csv", obrigatorio=False)
    avisos, info = conferir(areas, ligacoes, salas)
    totais = defaultdict(int)
    for a in areas:
        totais[a["regiao"]] += int(a["salas"])
    gw = max(int(a["x"]) + int(a["largura"]) for a in areas) + 1
    gh = max(int(a["y"]) + int(a["altura"]) for a in areas) + 1

    area_por_cod = {a["codigo"]: a for a in areas}
    regioes_com_salas = []
    for s in salas:
        r = area_por_cod.get(s["area"], {}).get("regiao")
        if r and r not in regioes_com_salas:
            regioes_com_salas.append(r)
    links = [("Mundo", "mapa.html")] + [(r, f"mapa_{slug(r)}.html") for r in regioes_com_salas]

    geral = Vista(34, 0, 0, gw, gh)
    png(geral, areas, ligacoes, salas, "O CAMINHO DA PROMESSA", "Mapa geral · 1 célula = 1 tela", dict(totais), False).save(os.path.join(MUNDO, "mapa.png"))
    with io.open(os.path.join(MUNDO, "mapa.html"), "w", encoding="utf-8") as f:
        f.write(pagina("O Caminho da Promessa", "Mapa geral · 1 célula = 1 tela", svg(geral, areas, ligacoes, salas, False),
                       dict(totais), avisos, info, salas, links))

    for reg in regioes_com_salas:
        ars = [a for a in areas if a["regiao"] == reg]
        x0 = max(0, min(int(a["x"]) for a in ars) - 1)
        y0 = max(0, min(int(a["y"]) for a in ars) - 1)
        x1 = max(int(a["x"]) + int(a["largura"]) for a in ars) + 1
        y1 = max(int(a["y"]) + int(a["altura"]) for a in ars) + 1
        vista = Vista(110, x0, y0, x1 - x0, y1 - y0, margem=50, lateral=360)
        n = sum(1 for s in salas if area_por_cod[s["area"]]["regiao"] == reg)
        sub = f"{n} salas detalhadas · 1 célula = 1 tela"
        nome = slug(reg)
        png(vista, areas, ligacoes, salas, reg.upper(), sub, {reg: totais[reg]}, True).save(os.path.join(MUNDO, f"mapa_{nome}.png"))
        with io.open(os.path.join(MUNDO, f"mapa_{nome}.html"), "w", encoding="utf-8") as f:
            f.write(pagina(reg, sub, svg(vista, areas, ligacoes, salas, True), {reg: totais[reg]}, avisos, info, salas, links))

    print(f"{len(areas)} áreas, {len(ligacoes)} ligações, {len(salas)} salas detalhadas, meta de {sum(totais.values())} salas.")
    print("Avisos:" if avisos else "Sem avisos.")
    for a in avisos:
        print("  - " + a)
    for i in info:
        print("  · " + i)
    print("Gerados em mundo/: mapa.png, mapa.html" + "".join(f", mapa_{slug(r)}.png/.html" for r in regioes_com_salas))


if __name__ == "__main__":
    main()
