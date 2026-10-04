"""Desenha o mapa geral do mundo a partir de mundo/areas.csv e mundo/ligacoes.csv.

Gera:
  mundo/mapa.png   imagem para consulta rápida
  mundo/mapa.html  versão interativa (passe o mouse nas áreas e ligações)

Também confere os dados: áreas sobrepostas, ligações com pontas fora das áreas
e áreas que não se ligam a nada. Rode com desenhar_mapa.bat (duplo clique).
"""
import csv
import html
import io
import os
from collections import defaultdict, deque

from PIL import Image, ImageDraw, ImageFont

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUNDO = os.path.join(RAIZ, "mundo")
CEL = 34  # px por célula (1 célula = 1 tela de jogo)
MARGEM = 40

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


def ler(nome):
    with io.open(os.path.join(MUNDO, nome), encoding="utf-8-sig") as f:
        return list(csv.DictReader(f, delimiter=";"))


def conferir(areas, ligacoes):
    avisos = []
    celulas = {}
    for a in areas:
        x, y, w, h = (int(a[k]) for k in ("x", "y", "largura", "altura"))
        for cx in range(x, x + w):
            for cy in range(y, y + h):
                if (cx, cy) in celulas:
                    avisos.append(f"Sobreposição na célula ({cx},{cy}): {celulas[(cx, cy)]} e {a['codigo']}")
                celulas[(cx, cy)] = a["codigo"]
    codigos = {a["codigo"] for a in areas}
    vizinhos = defaultdict(set)
    for l in ligacoes:
        for lado, ponta in (("de", ("x1", "y1")), ("para", ("x2", "y2"))):
            cod = l[lado]
            if cod not in codigos:
                avisos.append(f"Ligação {l['de']}→{l['para']}: área {cod} não existe")
                continue
            p = (int(l[ponta[0]]), int(l[ponta[1]]))
            if celulas.get(p) != cod:
                avisos.append(f"Ligação {l['de']}→{l['para']}: a ponta {p} não está dentro de {cod}")
        vizinhos[l["de"]].add(l["para"])
        if l["tipo"] != "atalho":
            vizinhos[l["para"]].add(l["de"])
    # Todas as áreas alcançáveis a partir do início (ignorando requisitos)?
    vistos, fila = {"C1"}, deque(["C1"])
    while fila:
        for v in vizinhos[fila.popleft()]:
            if v not in vistos:
                vistos.add(v)
                fila.append(v)
    for c in sorted(codigos - vistos):
        avisos.append(f"Área {c} não é alcançável a partir de C1")
    return avisos


def fonte(tam, negrito=False):
    for nome in (("segoeuib.ttf" if negrito else "segoeui.ttf"), "arial.ttf"):
        try:
            return ImageFont.truetype(os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts", nome), tam)
        except OSError:
            continue
    return ImageFont.load_default()


def centro(x, y):
    return (MARGEM + x * CEL + CEL / 2, MARGEM + y * CEL + CEL / 2)


def misturar(cor, fundo, t):
    """Cor opaca: t da cor sobre o fundo."""
    a = [int(cor.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    b = [int(fundo.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    return tuple(round(b[i] + (a[i] - b[i]) * t) for i in range(3))


def hex_rgba(cor, alfa):
    cor = cor.lstrip("#")
    return tuple(int(cor[i:i + 2], 16) for i in (0, 2, 4)) + (alfa,)


def linha_tracejada(d, p1, p2, cor, larg, tracejado):
    if not tracejado:
        d.line([p1, p2], fill=cor, width=larg)
        return
    (x1, y1), (x2, y2) = p1, p2
    comp = ((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5 or 1
    on, off = tracejado
    t = 0.0
    while t < comp:
        a = t / comp
        b = min(t + on, comp) / comp
        d.line([(x1 + (x2 - x1) * a, y1 + (y2 - y1) * a), (x1 + (x2 - x1) * b, y1 + (y2 - y1) * b)], fill=cor, width=larg)
        t += on + off


def desenhar_png(areas, ligacoes, larg_grade, alt_grade, totais):
    W = MARGEM * 2 + larg_grade * CEL + 330
    H = MARGEM * 2 + alt_grade * CEL
    img = Image.new("RGB", (W, H), "#15130F")
    d = ImageDraw.Draw(img)
    for gx in range(larg_grade + 1):
        d.line([(MARGEM + gx * CEL, MARGEM), (MARGEM + gx * CEL, MARGEM + alt_grade * CEL)], fill="#24211B")
    for gy in range(alt_grade + 1):
        d.line([(MARGEM, MARGEM + gy * CEL), (MARGEM + larg_grade * CEL, MARGEM + gy * CEL)], fill="#24211B")
    f_cod, f_nome, f_info = fonte(15, True), fonte(11), fonte(11)
    for a in areas:
        x, y, w, h = (int(a[k]) for k in ("x", "y", "largura", "altura"))
        cor = CORES.get(a["regiao"], "#888888")
        r = [MARGEM + x * CEL + 2, MARGEM + y * CEL + 2, MARGEM + (x + w) * CEL - 2, MARGEM + (y + h) * CEL - 2]
        d.rectangle(r, fill=misturar(cor, "#15130F", 0.32), outline=cor, width=2)
    for l in ligacoes:
        cor, larg, trac = LINHAS.get(l["tipo"], LINHAS["caminho"])
        p1 = centro(int(l["x1"]), int(l["y1"]))
        p2 = centro(int(l["x2"]), int(l["y2"]))
        linha_tracejada(d, p1, p2, cor, larg, trac)
        if l["tipo"] == "atalho":  # seta na ponta de chegada
            d.ellipse([p2[0] - 7, p2[1] - 7, p2[0] + 7, p2[1] + 7], fill=cor)
    for a in areas:
        x, y, w, h = (int(a[k]) for k in ("x", "y", "largura", "altura"))
        tx, ty = MARGEM + x * CEL + 6, MARGEM + y * CEL + 4
        d.text((tx, ty), a["codigo"] + ("  HUB" if "Hub" in a["papel"] else ""), font=f_cod, fill="#FFFFFF")
        linhas = [a["nome"], f"{a['salas']} salas · {a['altares']} altar(es)"]
        if a["oferta"]:
            linhas.append("Oferta: " + a["oferta"])
        if a["colosso"]:
            linhas.append("Colosso: " + a["colosso"])

        for i, t in enumerate(linhas):
            cor_t = "#F2C14E" if t.startswith(("Oferta", "Colosso", "HUB")) else "#EEE8D8"
            d.text((tx, ty + 18 + i * 13), t, font=f_nome if i == 0 else f_info, fill=cor_t)
    # Legenda
    lx = MARGEM + larg_grade * CEL + 30
    ly = MARGEM
    d.text((lx, ly), "O CAMINHO DA PROMESSA", font=fonte(18, True), fill="#F2E6C8")
    d.text((lx, ly + 26), "Mapa geral · 1 célula = 1 tela", font=fonte(12), fill="#BDB5A0")
    ly += 64
    for reg, cor in CORES.items():
        d.rectangle([lx, ly, lx + 18, ly + 18], fill=misturar(cor, "#15130F", 0.55), outline=cor)
        d.text((lx + 28, ly), f"{reg}: {totais[reg]} salas", font=fonte(13), fill="#EEE8D8")
        ly += 26
    ly += 10
    for tipo, (cor, larg, trac) in LINHAS.items():
        linha_tracejada(d, (lx, ly + 9), (lx + 40, ly + 9), cor, larg, trac)
        nome = {"caminho": "caminho", "atalho": "atalho (mão única; ● = chegada)",
                "oculto": "passagem oculta / com requisito", "final": "porta do final"}[tipo]
        d.text((lx + 50, ly), nome, font=fonte(13), fill="#EEE8D8")
        ly += 24
    ly += 10
    for t in ("Oferta: oferta do corpo", "Colosso: chefe da região", "HUB: centro de ligações"):
        d.text((lx, ly), t, font=fonte(13), fill="#F2C14E")
        ly += 22
    ly += 10
    d.text((lx, ly), f"TOTAL: {sum(totais.values())} salas", font=fonte(15, True), fill="#F2E6C8")
    return img


def desenhar_html(areas, ligacoes, larg_grade, alt_grade, totais, avisos):
    W = MARGEM * 2 + larg_grade * CEL
    H = MARGEM * 2 + alt_grade * CEL
    partes = []
    for gx in range(larg_grade + 1):
        partes.append(f'<line x1="{MARGEM + gx * CEL}" y1="{MARGEM}" x2="{MARGEM + gx * CEL}" y2="{MARGEM + alt_grade * CEL}" class="grade"/>')
    for gy in range(alt_grade + 1):
        partes.append(f'<line x1="{MARGEM}" y1="{MARGEM + gy * CEL}" x2="{MARGEM + larg_grade * CEL}" y2="{MARGEM + gy * CEL}" class="grade"/>')
    for a in areas:
        x, y, w, h = (int(a[k]) for k in ("x", "y", "largura", "altura"))
        cor = CORES.get(a["regiao"], "#888")
        dica = html.escape(f"{a['codigo']} · {a['nome']}\n{a['regiao']}\n{a['papel']}\n{a['salas']} salas · {a['altares']} altar(es)"
                           + (f"\nOferta: {a['oferta']}" if a["oferta"] else "") + (f"\nColosso: {a['colosso']}" if a["colosso"] else ""))
        partes.append(f'<g class="area"><title>{dica}</title><rect x="{MARGEM + x * CEL + 2}" y="{MARGEM + y * CEL + 2}" '
                      f'width="{w * CEL - 4}" height="{h * CEL - 4}" rx="4" fill="{cor}" fill-opacity="0.28" stroke="{cor}" stroke-width="2"/>'
                      f'<text x="{MARGEM + x * CEL + 6}" y="{MARGEM + y * CEL + 18}" class="cod">{a["codigo"]}</text>'
                      f'<text x="{MARGEM + x * CEL + 6}" y="{MARGEM + y * CEL + 32}" class="nome">{html.escape(a["nome"])}</text>'
                      f'<text x="{MARGEM + x * CEL + 6}" y="{MARGEM + y * CEL + 45}" class="info">{a["salas"]} salas'
                      f'{" · ◆ " + html.escape(a["oferta"]) if a["oferta"] else ""}{" · ✦" if a["colosso"] else ""}</text></g>')
    for l in ligacoes:
        cor, larg, trac = LINHAS.get(l["tipo"], LINHAS["caminho"])
        (x1, y1), (x2, y2) = centro(int(l["x1"]), int(l["y1"])), centro(int(l["x2"]), int(l["y2"]))
        dash = f' stroke-dasharray="{trac[0]} {trac[1]}"' if trac else ""
        dica = html.escape(f"{l['de']} → {l['para']} ({l['tipo']})" + (f"\nRequisito: {l['requisito']}" if l["requisito"] else "")
                           + (f"\n{l['nota']}" if l["nota"] else ""))
        fim = f'<circle cx="{x2}" cy="{y2}" r="6" fill="{cor}"/>' if l["tipo"] == "atalho" else ""
        partes.append(f'<g class="lig"><title>{dica}</title><line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{cor}" stroke-width="{larg}"{dash} stroke-linecap="round"/>'
                      f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="transparent" stroke-width="12"/>{fim}</g>')
    legenda = "".join(f'<li><span class="sw" style="background:{c}"></span>{html.escape(r)}: <b>{totais[r]}</b> salas</li>' for r, c in CORES.items())
    tipos = {"caminho": "caminho", "atalho": "atalho de mão única (● = chegada)", "oculto": "passagem oculta / com requisito", "final": "porta do final"}
    itens = []
    for k, (c, w, t) in LINHAS.items():
        dash = f' stroke-dasharray="{t[0]} {t[1]}"' if t else ""
        itens.append(f'<li><svg width="44" height="10"><line x1="2" y1="5" x2="42" y2="5" stroke="{c}" stroke-width="{w}"{dash}/></svg>{tipos[k]}</li>')
    leg_lin = "".join(itens)
    aviso_html = ("<h2>Avisos</h2><ul class='avisos'>" + "".join(f"<li>{html.escape(a)}</li>" for a in avisos) + "</ul>") if avisos \
        else "<p class='ok'>Dados conferidos: sem sobreposições, todas as ligações nas áreas certas, tudo alcançável.</p>"
    return f"""<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mapa Geral — Ex-Voto</title><style>
:root{{--bg:#15130F;--texto:#EEE8D8;--suave:#BDB5A0}}
body{{margin:0;background:var(--bg);color:var(--texto);font-family:"Segoe UI",system-ui,sans-serif}}
main{{display:flex;flex-wrap:wrap;gap:24px;padding:16px}}
.mapa{{overflow:auto;max-width:100%}}
.grade{{stroke:#fff;stroke-opacity:.07}}
.cod{{fill:#fff;font-weight:700;font-size:14px}}.nome{{fill:var(--texto);font-size:11px}}.info{{fill:var(--suave);font-size:10px}}
.area:hover rect{{fill-opacity:.5}}.lig:hover line:first-child{{stroke:#fff}}
aside{{min-width:260px;max-width:340px}}h1{{font-size:20px;margin:0 0 4px}}h2{{font-size:15px;margin:18px 0 6px}}
ul{{list-style:none;padding:0;margin:0}}li{{margin:5px 0;font-size:13px;display:flex;gap:8px;align-items:center}}
.sw{{width:14px;height:14px;border-radius:3px;display:inline-block}}.ok{{color:#9fd39a;font-size:13px}}.avisos li{{color:#f2a07b}}
p{{color:var(--suave);font-size:13px}}</style></head><body><main>
<div class="mapa"><svg width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-label="Mapa geral do mundo">{''.join(partes)}</svg></div>
<aside><h1>O Caminho da Promessa</h1><p>Mapa geral · 1 célula = 1 tela de jogo · passe o mouse nas áreas e ligações</p>
<h2>Regiões</h2><ul>{legenda}</ul><p><b>Total: {sum(totais.values())} salas</b></p>
<h2>Ligações</h2><ul>{leg_lin}</ul><p>◆ oferta do corpo · ✦ colosso</p>{aviso_html}
<p>Gerado a partir de <code>mundo/areas.csv</code> e <code>mundo/ligacoes.csv</code>.</p></aside></main></body></html>"""


def main():
    areas = ler("areas.csv")
    ligacoes = ler("ligacoes.csv")
    avisos = conferir(areas, ligacoes)
    larg_grade = max(int(a["x"]) + int(a["largura"]) for a in areas) + 1
    alt_grade = max(int(a["y"]) + int(a["altura"]) for a in areas) + 1
    totais = {r: 0 for r in CORES}
    for a in areas:
        totais[a["regiao"]] = totais.get(a["regiao"], 0) + int(a["salas"])
    desenhar_png(areas, ligacoes, larg_grade, alt_grade, totais).save(os.path.join(MUNDO, "mapa.png"))
    with io.open(os.path.join(MUNDO, "mapa.html"), "w", encoding="utf-8") as f:
        f.write(desenhar_html(areas, ligacoes, larg_grade, alt_grade, totais, avisos))
    print(f"{len(areas)} áreas, {len(ligacoes)} ligações, {sum(totais.values())} salas.")
    for r, n in totais.items():
        print(f"  {r}: {n} salas")
    print("Avisos:" if avisos else "Sem avisos.")
    for a in avisos:
        print("  - " + a)
    print("Gerados: mundo/mapa.png e mundo/mapa.html")


if __name__ == "__main__":
    main()
