#!/usr/bin/env python3
"""
Birth Chart PDF Generator
Usage: python3 generate_chart_pdf.py chart_data.json [output.pdf]
Input:  chart_data.json  (see SKILL.md for schema)
Output: <name>_natal_chart.pdf  (5 pages: poster + 4 text pages)
Dependencies: matplotlib, pillow, img2pdf  (auto-installed if missing)
"""

import sys, os, json, textwrap, io, math, subprocess

def ensure_deps():
    for pkg in ["matplotlib", "PIL", "img2pdf"]:
        try:
            __import__(pkg if pkg != "PIL" else "PIL.Image")
        except ImportError:
            subprocess.check_call([sys.executable, "-m", "pip", "install",
                                   {"matplotlib":"matplotlib","PIL":"pillow","img2pdf":"img2pdf"}[pkg],
                                   "--break-system-packages", "-q"])
ensure_deps()

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patheffects as pe
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import img2pdf

# ─── PALETTE ────────────────────────────────────────────────────────────────
BG     = "#FAF7F2"
DARK   = "#1C1C2E"
MID    = "#3D3A4E"
DIV    = "#D9CFC2"
WINE   = "#7B2D3E"
GOLD   = "#B8892A"
LAV    = "#7E6E96"
CARD   = "#F0EAE0"
FIRE   = "#C4632A"
EARTH  = "#7A6A4A"
AIR    = "#5A80A0"
WATER  = "#2A5F8A"

COLOR_MAP = {
    "GOLD": GOLD, "WINE": WINE, "LAV": LAV, "LAVENDER": LAV,
    "FIRE": FIRE, "EARTH": EARTH, "AIR": AIR, "WATER": WATER,
    "MID": MID, "DARK": DARK, "GREY": "#888888", "GRAY": "#888888",
}

def c(name): return COLOR_MAP.get(name, name)

def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2],16) for i in (0,2,4))

# ─── FONTS ──────────────────────────────────────────────────────────────────
FONT_DIR = "/usr/share/fonts/truetype/dejavu/"
_font_cache = {}
def F(n, s):
    key = (n, s)
    if key not in _font_cache:
        m = {'s':FONT_DIR+'DejaVuSans.ttf','sb':FONT_DIR+'DejaVuSans-Bold.ttf',
             'r':FONT_DIR+'DejaVuSerif.ttf','rb':FONT_DIR+'DejaVuSerif-Bold.ttf'}
        _font_cache[key] = ImageFont.truetype(m[n], s)
    return _font_cache[key]

# ─── HELPERS ────────────────────────────────────────────────────────────────
def cx(d, text, y, font, color, W, ox=0):
    bb = d.textbbox((0,0), text, font=font)
    tw = bb[2]-bb[0]
    d.text((ox+(W-tw)//2, y), text, font=font, fill=rgb(color))

def wrap_draw(d, text, x, y, font, color, max_w, lh=22):
    chars = max(20, int(max_w / (font.size * 0.56)))
    for ln in textwrap.wrap(text, width=chars):
        d.text((x, y), ln, font=font, fill=rgb(color))
        y += lh
    return y

def hline(d, y, W, pad=55, color=DIV, w=1):
    d.line([(pad,y),(W-pad,y)], fill=rgb(color), width=w)

def glyph_img(symbol, size_pt=60, color=DARK, bg=BG):
    """Render a unicode symbol via matplotlib, return PIL RGB image."""
    fig, ax = plt.subplots(figsize=(size_pt/72*3, size_pt/72*3))
    fig.patch.set_facecolor(bg)
    ax.set_facecolor(bg)
    ax.text(0.5, 0.5, symbol, ha='center', va='center',
            fontsize=size_pt, color=color, transform=ax.transAxes)
    ax.axis('off')
    plt.subplots_adjust(0,0,1,1)
    buf = io.BytesIO()
    plt.savefig(buf, format='png', dpi=150, bbox_inches='tight', facecolor=bg)
    plt.close(fig)
    buf.seek(0)
    return Image.open(buf).convert("RGB")

# ─── PAGE 1: VISUAL POSTER ─────────────────────────────────────────────────
def make_wheel(cd, size=490):
    fig, ax = plt.subplots(figsize=(size/150, size/150), subplot_kw=dict(polar=True))
    fig.patch.set_facecolor(BG); ax.set_facecolor(BG)
    ax.set_theta_zero_location('E'); ax.set_theta_direction(1)
    ax.set_ylim(0,1.05); ax.axis('off')

    el_cols = [FIRE,EARTH,AIR,WATER]*3
    glyphs  = ['♈','♉','♊','♋','♌','♍','♎','♏','♐','♑','♒','♓']
    for i in range(12):
        s,e = math.radians(i*30), math.radians((i+1)*30)
        ax.fill_between(np.linspace(s,e,60), 0.80, 0.98, color=el_cols[i], alpha=0.13)
        ax.plot([s,s],[0.80,0.98], color=DIV, lw=0.8, alpha=0.55)
        ax.text(math.radians(i*30+15), 0.89, glyphs[i],
                ha='center', va='center', fontsize=9.5, color=MID, alpha=0.9)

    for i, p in enumerate(cd["planets"]):
        a = math.radians(p["ecliptic"])
        r = p.get("r_pos", 0.42)
        col = c(p.get("color", "MID"))
        ax.text(a, r, p["symbol"], ha='center', va='center', fontsize=11.5,
                color=col, fontweight='bold', zorder=5,
                path_effects=[pe.withStroke(linewidth=2.8, foreground=BG)])

    for ap in cd.get("aspect_lines", []):
        a1,a2 = math.radians(ap[0]), math.radians(ap[1])
        ax.annotate("",xy=(a2,0.23),xytext=(a1,0.23),
                    arrowprops=dict(arrowstyle="-",color=DIV,alpha=0.4,lw=0.9,
                                   connectionstyle="arc3,rad=0"),zorder=1)

    hc = cd.get("house_cusps_ecliptic", [])
    for i, deg in enumerate(hc):
        a = math.radians(deg)
        lw = 1.4 if i in [0,3,6,9] else 0.55
        ax.plot([a,a],[0.10,0.80], color=MID, lw=lw, alpha=0.85 if lw>1 else 0.35, zorder=3)
        nxt = hc[(i+1)%12]
        if nxt<deg: nxt+=360
        ax.text(math.radians((deg+nxt)/2), 0.67, str(i+1),
                ha='center', va='center', fontsize=6, color=MID, alpha=0.55)

    ax.plot(np.linspace(0,2*math.pi,300),[0.10]*300,color=DIV,lw=1.3,alpha=0.7)
    plt.subplots_adjust(0,0,1,1)
    buf=io.BytesIO()
    plt.savefig(buf,format='png',dpi=150,bbox_inches='tight',facecolor=BG)
    plt.close(); buf.seek(0)
    return Image.open(buf).convert("RGB").resize((size,size),Image.LANCZOS)

def build_poster(cd):
    W, H = 1200, 2260
    MAR  = 55
    img  = Image.new("RGB",(W,H),rgb(BG))
    d    = ImageDraw.Draw(img)

    # Header
    d.rectangle([(0,0),(W,125)], fill=rgb(DARK))
    d.rectangle([(0,0),(W,6)], fill=rgb(GOLD))
    d.rectangle([(0,119),(W,125)], fill=rgb(GOLD))
    cx(d, cd["name"].upper(), 14, F('rb',50), GOLD, W)
    cx(d, "N A T A L   B I R T H   C H A R T", 72, F('s',17), DIV, W)
    info = f"{cd['birth_date']}   ·   {cd['birth_time']}   ·   {cd['birth_place']}"
    cx(d, info, 96, F('s',13), "#7070A0", W)

    y = 143
    # Big Three
    cx(d, "—  THE BIG THREE  —", y, F('sb',12), LAV, W)
    y += 26
    three = [
        (cd["big_three"]["sun"],    "SUN",    GOLD, "♑"),
        (cd["big_three"]["moon"],   "MOON",   WINE, "♏"),
        (cd["big_three"]["rising"], "RISING", LAV,  "♎"),
    ]
    # Override glyphs from data if provided
    glyph_map = {
        "Aries":"♈","Taurus":"♉","Gemini":"♊","Cancer":"♋","Leo":"♌","Virgo":"♍",
        "Libra":"♎","Scorpio":"♏","Sagittarius":"♐","Capricorn":"♑","Aquarius":"♒","Pisces":"♓",
    }
    cw = W//3; ch=155; pad=18
    for i,(info_d, lbl, col, _) in enumerate(three):
        sign = info_d["sign"]; house = info_d.get("house","")
        zsym = glyph_map.get(sign, sign[:3])
        cx0  = i*cw
        d.rounded_rectangle([cx0+pad,y,cx0+cw-pad,y+ch], radius=14, fill=rgb(CARD))
        d.rounded_rectangle([cx0+pad,y,cx0+cw-pad,y+7], radius=5, fill=rgb(col))
        d.rounded_rectangle([cx0+pad,y+ch-7,cx0+cw-pad,y+ch], radius=5, fill=rgb(col))
        g = glyph_img(zsym, size_pt=58, color=col, bg=CARD)
        img.paste(g,(cx0+cw//2-g.width//2, y+8))
        cx(d, lbl,  y+75, F('sb',11), "#999999", cw, cx0)
        cx(d, sign, y+93, F('rb',22), DARK,      cw, cx0)
        if house:
            cx(d, f"{house} House", y+120, F('s',14), "#888888", cw, cx0)

    y += ch+22; hline(d,y,W); y+=20

    # Wheel + planet table
    cx(d, "—  PLANETARY POSITIONS  —", y, F('sb',12), LAV, W)
    y += 22
    wimg = make_wheel(cd, 490)
    wx, wy = 35, y
    img.paste(wimg,(wx,wy))

    tx = wx+490+22; ty = y+5; tw = W-tx-40
    hcols = [tx, tx+40, tx+155, tx+295, tx+370]
    for hc, ht in zip(hcols,["","PLANET","SIGN","POS","HSE"]):
        d.text((hc,ty), ht, font=F('sb',12), fill=rgb(LAV))
    ty += 20; hline(d,ty,W,pad=tx,color=LAV,w=1); ty+=8

    rh=31
    for idx,pl in enumerate(cd["planets"]):
        ry = ty+idx*rh
        col = c(pl.get("color","MID"))
        bg_c = CARD if idx%2==0 else BG
        if idx%2==0:
            d.rounded_rectangle([tx-4,ry-3,tx+tw,ry+rh-5],radius=4,fill=rgb(CARD))
        pg = glyph_img(pl["symbol"],22,col,bg_c)
        pg = pg.resize((28,28),Image.LANCZOS)
        img.paste(pg,(hcols[0]-2,ry))
        d.text((hcols[1],ry), pl["name"],   font=F('s',15), fill=rgb(DARK))
        d.text((hcols[2],ry), pl["sign"],   font=F('s',15), fill=rgb(MID))
        d.text((hcols[3],ry), pl["degree"], font=F('s',15), fill=rgb("#888888"))
        bx=hcols[4]; bw2=42
        d.rounded_rectangle([bx,ry+1,bx+bw2,ry+rh-6],radius=4,fill=rgb(col))
        hl=f"H{pl['house']}"
        hbb=d.textbbox((0,0),hl,font=F('sb',12))
        d.text((bx+(bw2-(hbb[2]-hbb[0]))//2,ry+4),hl,font=F('sb',12),fill=rgb(BG))

    y = wy+490+22; hline(d,y,W); y+=22

    # Elements + modality
    half=W//2
    cx(d,"—  ELEMENTAL BALANCE  —",y,F('sb',12),LAV,half,0)
    cx(d,"—  MODALITY  —",         y,F('sb',12),LAV,half,half)
    y+=30

    def bar(x,by,lbl,pct,col,bw=290,bh=13):
        filled=int(bw*pct)
        d.rounded_rectangle([x,by,x+bw,by+bh],radius=5,fill=rgb(DIV))
        if filled>2:
            d.rounded_rectangle([x,by,x+filled,by+bh],radius=5,fill=rgb(col))
        elif pct==0:
            d.rounded_rectangle([x,by,x+bw,by+bh],radius=5,outline=rgb(col),width=1)
            d.text((x+bw//2-15,by-1),"none",font=F('s',11),fill=rgb(col))
        d.text((x-8,by-1),lbl,font=F('sb',16),fill=rgb(DARK),anchor="rm")
        d.text((x+bw+8,by-1),f"{int(pct*100)}%",font=F('s',14),fill=rgb(col))

    el=cd["elements"]; mo=cd["modalities"]
    lx=190; rx=half+200; ey=y; my=y+18
    for lbl,pct,col in [("FIRE",el["fire"],FIRE),("EARTH",el["earth"],EARTH),
                          ("AIR",el["air"],AIR),("WATER",el["water"],WATER)]:
        bar(lx,ey,lbl,pct,col); ey+=36
    for lbl,pct,col in [("CARDINAL",mo["cardinal"],"#A06030"),
                          ("FIXED",mo["fixed"],"#607060"),
                          ("MUTABLE",mo["mutable"],LAV)]:
        bar(rx,my,lbl,pct,col,bw=270); my+=36
    y=max(ey,my)+22; hline(d,y,W); y+=22

    # Key aspects (top 8)
    cx(d,"—  KEY ASPECTS  —",y,F('sb',12),LAV,W); y+=26
    top_aspects = [a for a in cd["aspects"] if a.get("featured",False)]
    if not top_aspects: top_aspects = cd["aspects"][:8]
    acw=(W-80)//2; ach=76
    for i,ap in enumerate(top_aspects[:8]):
        col=c(ap.get("color","MID"))
        ax0=40+(i%2)*acw; ay=y+(i//2)*(ach+10)
        d.rounded_rectangle([ax0,ay,ax0+acw-15,ay+ach],radius=9,fill=rgb(CARD))
        d.rounded_rectangle([ax0,ay,ax0+6,ay+ach],radius=4,fill=rgb(col))
        at=ap["type"][:4].upper()
        bb=d.textbbox((0,0),at,font=F('sb',11))
        bw2=bb[2]-bb[0]; bx=ax0+14
        d.rounded_rectangle([bx-4,ay+9,bx+bw2+4,ay+24],radius=3,fill=rgb(col))
        d.text((bx,ay+10),at,font=F('sb',11),fill=rgb(BG))
        d.text((bx+bw2+12,ay+8),f"{ap['p1']} + {ap['p2']}",font=F('sb',14),fill=rgb(DARK))
        d.text((bx+bw2+12,ay+26),f"Orb {ap['orb']}",font=F('s',12),fill=rgb(col))
        words=ap["description"].split(); ln=""; lines=[]
        for w in words:
            t=ln+w+" "
            if d.textbbox((0,0),t,font=F('s',13))[2]>acw-65: lines.append(ln); ln=w+" "
            else: ln=t
        if ln: lines.append(ln)
        for li,l in enumerate(lines[:2]):
            d.text((ax0+14,ay+40+li*14),l.rstrip(),font=F('s',13),fill=rgb(MID))
    y+=(len(top_aspects[:8])//2)*(ach+10)+15; hline(d,y,W); y+=22

    # Nodal + Chiron
    cx(d,"—  SOUL'S EVOLUTIONARY AXIS  —",y,F('sb',12),LAV,W); y+=26
    npad=50; nw=(W-npad*2-20)//2
    nn=cd["nodal_axis"]["north_node"]; sn=cd["nodal_axis"]["south_node"]
    for xi, node, col, label in [(npad,nn,GOLD,"NORTH NODE ☊"),(npad+nw+20,sn,LAV,"SOUTH NODE ☋")]:
        d.rounded_rectangle([xi,y,xi+nw,y+75],radius=10,fill=rgb(CARD))
        d.rounded_rectangle([xi,y,xi+6,y+75],radius=4,fill=rgb(col))
        d.text((xi+14,y+8),f"{label}  —  {node['sign']}  —  {node['house']} House",
               font=F('sb',14),fill=rgb(col))
        wrap_draw(d,node["summary"],xi+14,y+30,F('s',14),MID,nw-30,20)
    y+=87
    chi=cd["chiron"]
    d.rounded_rectangle([npad,y,W-npad,y+60],radius=10,fill=rgb(CARD))
    d.rounded_rectangle([npad,y,npad+6,y+60],radius=4,fill=rgb("#999999"))
    d.text((npad+14,y+8),f"CHIRON ⚷  —  {chi['sign']}  —  {chi['house']} House"+(
        "  (Retrograde)" if chi.get("retrograde") else ""),font=F('sb',14),fill=rgb("#666666"))
    wrap_draw(d,chi["summary"],npad+14,y+30,F('s',13),MID,W-npad*2-30,18)
    y+=72; hline(d,y,W); y+=22

    # Synthesis
    cx(d,"—  CHART SYNTHESIS  —",y,F('sb',12),LAV,W); y+=24
    syn=cd["synthesis"]
    portrait_lines = syn.get("portrait_lines",[])
    port_h=len(portrait_lines)*20+28
    d.rounded_rectangle([MAR,y,W-MAR,y+port_h],radius=10,fill=rgb(CARD))
    d.rounded_rectangle([MAR,y,MAR+6,y+port_h],radius=4,fill=rgb(WATER))
    for li,ln in enumerate(portrait_lines):
        d.text((MAR+14,y+12+li*20),ln,font=F('s',14),fill=rgb(MID))
    y+=port_h+14
    for thread in syn.get("threads",[]):
        col=c(thread.get("color","MID"))
        d.rounded_rectangle([MAR,y,W-MAR,y+82],radius=10,fill=rgb(CARD))
        d.rounded_rectangle([MAR,y,MAR+6,y+82],radius=4,fill=rgb(col))
        d.text((MAR+14,y+8),thread["title"],font=F('sb',14),fill=rgb(col))
        wrap_draw(d,thread["body1"],MAR+14,y+30,F('s',13),MID,W-MAR*2-30,16)
        wrap_draw(d,thread["body2"],MAR+14,y+46,F('s',13),MID,W-MAR*2-30,16)
        y+=92
    q=syn.get("pull_quote","")
    d.rounded_rectangle([MAR,y,W-MAR,y+82],radius=12,fill=rgb(DARK),outline=rgb(GOLD),width=2)
    lines_q=textwrap.wrap(q,width=70)
    for li,ln in enumerate(lines_q[:2]):
        cx(d,ln,y+12+li*28,F('rb',19),GOLD,W)
    cx(d,f"—  Natal Chart Synthesis  ·  {cd['name']}",y+68,F('s',11),"#5A5A7A",W)
    y+=94

    # Footer
    d.rectangle([(0,H-50),(W,H)],fill=rgb(DARK))
    d.rectangle([(0,H-5),(W,H)],fill=rgb(GOLD))
    footer=f"Placidus Houses  ·  Tropical Zodiac  ·  Swiss Ephemeris  ·  {cd['birth_place']}  ·  {cd['birth_date']}"
    cx(d,footer,H-42,F('s',12),"#5A5A7A",W)
    asc_info = f"{cd.get('ascendant','')}  ·  MC: {cd.get('midheaven','')}"
    cx(d,asc_info,H-24,F('s',11),"#44446A",W)

    return img

# ─── PAGE BUILDER (text pages) ─────────────────────────────────────────────
class PB:
    W=1200; H=1700; MAR=70
    def __init__(self,pg,total):
        self.img=Image.new("RGB",(self.W,self.H),rgb(BG))
        self.d=ImageDraw.Draw(self.img); self.y=0; self._header(pg,total)
    def _header(self,pg,total):
        d=self.d; W=self.W
        d.rectangle([(0,0),(W,65)],fill=rgb(DARK))
        d.rectangle([(0,0),(W,5)],fill=rgb(GOLD))
        cx(d,f"NATAL BIRTH CHART",10,F('rb',30),GOLD,W)
        cx(d,f"Page {pg} of {total}   ·   {self._name}   ·   Placidus / Tropical",42,F('s',13),"#6A6A8A",W)
        self.y=82
    _name=""
    def _footer(self):
        d=self.d; W=self.W; H=self.H
        d.rectangle([(0,H-35),(W,H)],fill=rgb(DARK))
        d.rectangle([(0,H-5),(W,H)],fill=rgb(GOLD))
        cx(d,f"Placidus Houses  ·  Tropical Zodiac  ·  Swiss Ephemeris  ·  {self._name}",
           H-28,F('s',11),"#5A5A7A",W)
    def section(self,title,col=LAV):
        d=self.d; M=self.MAR; W=self.W; self.y+=8
        d.rectangle([(M,self.y),(W-M,self.y+32)],fill=rgb(DARK))
        d.rectangle([(M,self.y),(M+5,self.y+32)],fill=rgb(col))
        d.text((M+14,self.y+7),title.upper(),font=F('sb',14),fill=rgb(col))
        self.y+=42
    def sub(self,text,col=GOLD):
        self.d.text((self.MAR,self.y),text,font=F('rb',17),fill=rgb(col)); self.y+=26
    def body(self,text,col=MID):
        self.y=wrap_draw(self.d,text,self.MAR,self.y,F('r',15),col,
                         self.W-self.MAR*2-10,24); self.y+=6
    def note(self,text):
        self.y=wrap_draw(self.d,text,self.MAR+10,self.y,F('s',13),"#888888",
                         self.W-self.MAR*2-20,20); self.y+=4
    def hline(self,col=DIV,pad=None):
        p=pad or self.MAR+20
        self.d.line([(p,self.y),(self.W-p,self.y)],fill=rgb(col),width=1); self.y+=14
    def space(self,n=10): self.y+=n
    def save(self,path):
        self._footer()
        self.img.save(path,"JPEG",quality=94)
        return path
    def fits(self,margin=200): return self.y < self.H-margin

# ─── BUILD TEXT PAGES ──────────────────────────────────────────────────────
def build_text_pages(cd):
    PB._name = cd["name"]
    pages=[]
    total=5  # poster + 4 text pages (approximate)

    # Page 2: Big Three
    p=PB(2,total)
    p.section("THE BIG THREE — FULL INTERPRETATIONS",GOLD)
    for key,lbl,col in [("sun","Sun in","SUN_COLOR"),
                         ("moon","Moon in","MOON_COLOR"),
                         ("rising","Rising","RISE_COLOR")]:
        cols={"sun":GOLD,"moon":WINE,"rising":LAV}
        bt=cd["big_three"][key]
        p.sub(f"{lbl} {bt['sign']}  —  {bt.get('house','Ascendant')} House",cols[key])
        for para in bt.get("interpretation",[]):
            p.body(para)
        if bt.get("note"): p.note(bt["note"])
        p.space(4); p.hline()
    pages.append(p)

    # Page 3: Planetary placements
    p=PB(3,total)
    p.section("PLANETARY PLACEMENTS — FULL INTERPRETATIONS",LAV)
    for pl in cd["planets"]:
        if not p.fits(180):
            pages.append(p); p=PB(len(pages)+2,total)
            p.section("PLANETARY PLACEMENTS (continued)",LAV)
        col=c(pl.get("color","MID"))
        interp=pl.get("interpretation","")
        if not interp: continue
        p.sub(f"{pl['name']} in {pl['sign']}  —  {pl['house']} House",col)
        p.body(interp); p.space(2); p.hline(col="#E8E0D5",pad=PB.MAR+20)
    pages.append(p)

    # Page 4: Houses + Aspects
    p=PB(len(pages)+2,total)
    p.section("HOUSE OVERVIEW",LAV)
    for h in cd["houses"]:
        if not p.fits(160):
            pages.append(p); p=PB(len(pages)+2,total)
            p.section("HOUSES (continued)",LAV)
        p.d.text((p.MAR,p.y),f"{h['number']}th House — {h['sign']} {h['degree']}",
                  font=F('sb',14),fill=rgb(DARK))
        p.y+=22
        p.y=wrap_draw(p.d,h["description"],p.MAR+16,p.y,F('s',13),MID,
                       p.W-p.MAR*2-20,20); p.y+=10
        p.d.line([(p.MAR,p.y),(p.W-p.MAR,p.y)],fill=rgb(DIV),width=1); p.y+=10
    p.space(8)
    p.section("ALL ASPECTS",LAV)
    fa=F('sb',12); fb=F('s',13)
    for ap in cd["aspects"]:
        if not p.fits(80):
            pages.append(p); p=PB(len(pages)+2,total)
            p.section("ALL ASPECTS (continued)",LAV)
        col=c(ap.get("color","MID"))
        at=f"{ap['type'].upper()}  {ap['orb']}"
        bb=p.d.textbbox((0,0),at,font=fa)
        bw=bb[2]-bb[0]+8
        p.d.rounded_rectangle([p.MAR,p.y,p.MAR+bw,p.y+18],radius=4,fill=rgb(col))
        p.d.text((p.MAR+4,p.y+2),at,font=fa,fill=rgb(BG))
        p.d.text((p.MAR+bw+8,p.y+1),f"{ap['p1']} — {ap['p2']}",font=fa,fill=rgb(DARK))
        p.y+=20
        p.y=wrap_draw(p.d,ap["description"],p.MAR+12,p.y,fb,MID,p.W-p.MAR*2-20,19)
        p.d.line([(p.MAR+20,p.y),(p.W-p.MAR,p.y)],fill=rgb(DIV),width=1); p.y+=9
    pages.append(p)

    # Final page: Nodal + Chiron + Synthesis
    p=PB(len(pages)+2,total)
    p.section("NODAL AXIS — SOUL'S EVOLUTIONARY DIRECTION",GOLD)
    nn=cd["nodal_axis"]["north_node"]; sn=cd["nodal_axis"]["south_node"]
    p.sub(f"North Node in {nn['sign']}  —  {nn['house']} House  ({nn['degree']})",GOLD)
    for para in nn.get("interpretation",[]): p.body(para)
    if nn.get("note"): p.note(nn["note"])
    p.hline()
    p.sub(f"South Node in {sn['sign']}  —  {sn['house']} House  ({sn['degree']})",LAV)
    for para in sn.get("interpretation",[]): p.body(para)
    p.hline()
    p.section("CHIRON — THE WOUNDED HEALER",MID)
    chi=cd["chiron"]
    retro=" (Retrograde)" if chi.get("retrograde") else ""
    p.sub(f"Chiron in {chi['sign']}  —  {chi['house']} House{retro}",MID)
    for para in chi.get("interpretation",[]): p.body(para)
    if chi.get("note"): p.note(chi["note"])
    p.hline()
    p.section("FINAL SYNTHESIS",GOLD)
    for para in cd["synthesis"].get("full_text",[]): p.body(para)
    # pull quote
    q=cd["synthesis"].get("pull_quote","")
    if q:
        p.d.rounded_rectangle([p.MAR,p.y,p.W-p.MAR,p.y+78],radius=12,
                                fill=rgb(DARK),outline=rgb(GOLD),width=2)
        for li,ln in enumerate(textwrap.wrap(q,width=72)[:2]):
            cx(p.d,ln,p.y+10+li*26,F('rb',18),GOLD,p.W)
        p.y+=78
    pages.append(p)

    return pages

# ─── MAIN ──────────────────────────────────────────────────────────────────
def main():
    if len(sys.argv)<2:
        print("Usage: generate_chart_pdf.py chart_data.json [output.pdf]")
        sys.exit(1)

    data_path=sys.argv[1]
    with open(data_path) as f:
        cd=json.load(f)

    out_path=sys.argv[2] if len(sys.argv)>2 else \
        f"{cd['name'].replace(' ','_')}_Natal_Chart.pdf"

    print(f"Building chart for {cd['name']}...")

    # Build all pages
    print("  Page 1: Visual poster...")
    poster=build_poster(cd)
    poster_buf=io.BytesIO(); poster.save(poster_buf,"JPEG",quality=96); poster_buf.seek(0)

    print("  Pages 2+: Text pages...")
    text_pages=build_text_pages(cd)
    page_bufs=[poster_buf]
    for i,pg in enumerate(text_pages):
        buf=io.BytesIO(); pg.img.save(buf,"JPEG",quality=94); buf.seek(0)
        page_bufs.append(buf)
        print(f"  Page {i+2}: built (y={pg.y}/{pg.H})")

    print(f"  Combining {len(page_bufs)} pages into PDF...")
    with open(out_path,"wb") as f:
        f.write(img2pdf.convert([b.read() for b in page_bufs]))

    size=os.path.getsize(out_path)/1024/1024
    print(f"Done! {out_path}  ({size:.1f}MB, {len(page_bufs)} pages)")

if __name__=="__main__":
    main()
