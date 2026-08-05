#!/usr/bin/env python3
"""Build the CYP Formulation Clouds worksheet: one A3 landscape .docx page.

Everything on the page is a real Word AutoShape with editable text, so the
sheet can be printed and written on, or typed into during a session.

    python3 build_clouds.py [output.docx]
"""
import os
import sys
import zipfile

EMU = 914400          # EMU per inch
TW = 1440             # twips per inch
PT100 = 12700         # EMU per point

PAGE_W, PAGE_H = 16.535, 11.693   # A3 landscape (420 x 297 mm)

FONT = "Trebuchet MS"             # rounded, humanist, on every Windows and Mac
MUTED = "55606B"

EMDASH = "—"
MIDDOT = "·"

# The DrawingML "cloud" preset puts its text rectangle at
# l 2977/21600, t 3262/21600, r 17087/21600, b 17337/21600 of the shape box --
# noticeably smaller than the box and not centred inside it.
CL, CT, CR, CB = 2977 / 21600, 3262 / 21600, 17087 / 21600, 17337 / 21600

NS = (
    'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
    'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
    'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
    'xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape" '
    'xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup" '
    'xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" '
    'xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing" '
    'mc:Ignorable="w14 wp14"'
)


def emu(inches):
    return str(int(round(inches * EMU)))


def hp(pt):
    return str(int(round(pt * 2)))          # half-points


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


_id = [100]


def next_id():
    _id[0] += 1
    return _id[0]


# ---------------------------------------------------------------------------
# text
# ---------------------------------------------------------------------------
def run(text, size=12, bold=False, italic=False, color="3A4451", font=FONT,
        spacing=None):
    """A text run. Child order follows EG_RPrBase -- Word and LibreOffice both
    silently drop properties that appear out of schema order."""
    rpr = ['<w:rFonts w:ascii="%s" w:hAnsi="%s" w:cs="%s"/>' % (font, font, font)]
    if bold:
        rpr.append("<w:b/><w:bCs/>")
    if italic:
        rpr.append("<w:i/><w:iCs/>")
    rpr.append('<w:color w:val="%s"/>' % color)
    if spacing:
        rpr.append('<w:spacing w:val="%d"/>' % spacing)
    rpr.append('<w:sz w:val="%s"/><w:szCs w:val="%s"/>' % (hp(size), hp(size)))
    return ('<w:r><w:rPr>%s</w:rPr><w:t xml:space="preserve">%s</w:t></w:r>'
            % ("".join(rpr), esc(text)))


def para(runs, align="center", before=0, after=0, line=None):
    sp = '<w:spacing w:before="%d" w:after="%d"' % (before * 20, after * 20)
    if line:
        sp += ' w:line="%d" w:lineRule="auto"' % int(line * 20)
    ppr = '<w:pPr>%s/><w:jc w:val="%s"/></w:pPr>' % (sp, align)
    return "<w:p>%s%s</w:p>" % (ppr, "".join(runs))


# ---------------------------------------------------------------------------
# shapes
# ---------------------------------------------------------------------------
def shape(name, x, y, w, h, geom="rect", fill=None, grad=None, line=None,
          line_w=2.0, content="", insets=(0.1, 0.08, 0.1, 0.08), anchor="t",
          z=10, adj=None, shadow=None):
    """A shape floating over the page. x/y/w/h and insets are in inches,
    measured from the top-left corner of the paper."""
    sid = next_id()
    if grad:
        fill_xml = ('<a:gradFill rotWithShape="1"><a:gsLst>'
                    '<a:gs pos="0"><a:srgbClr val="%s"/></a:gs>'
                    '<a:gs pos="100000"><a:srgbClr val="%s"/></a:gs>'
                    '</a:gsLst><a:lin ang="5400000" scaled="0"/></a:gradFill>' % grad)
    elif fill:
        fill_xml = '<a:solidFill><a:srgbClr val="%s"/></a:solidFill>' % fill
    else:
        fill_xml = "<a:noFill/>"

    if line:
        ln_xml = ('<a:ln w="%d" cap="rnd"><a:solidFill><a:srgbClr val="%s"/>'
                  "</a:solidFill><a:round/></a:ln>" % (int(line_w * PT100), line))
    else:
        ln_xml = "<a:ln><a:noFill/></a:ln>"

    eff = ""
    if shadow:
        eff = ('<a:effectLst><a:outerShdw blurRad="69850" dist="38100" dir="5400000" '
               'algn="ctr" rotWithShape="0"><a:srgbClr val="%s"><a:alpha val="20000"/>'
               "</a:srgbClr></a:outerShdw></a:effectLst>" % shadow)

    av = "<a:avLst/>"
    if adj:
        av = "<a:avLst>%s</a:avLst>" % "".join(
            '<a:gd name="%s" fmla="val %d"/>' % kv for kv in adj.items())

    l, t, r, b = insets
    body = ('<wps:bodyPr rot="0" spcFirstLastPara="0" vertOverflow="overflow" '
            'horzOverflow="overflow" vert="horz" wrap="square" '
            'lIns="%s" tIns="%s" rIns="%s" bIns="%s" numCol="1" spcCol="0" '
            'rtlCol="0" fromWordArt="0" anchor="%s" anchorCtr="0" forceAA="0" '
            'compatLnSpc="1"><a:prstTxWarp prst="textNoShape"><a:avLst/>'
            "</a:prstTxWarp><a:noAutofit/></wps:bodyPr>"
            % (emu(l), emu(t), emu(r), emu(b), anchor))

    txbx = ("<wps:txbx><w:txbxContent>%s</w:txbxContent></wps:txbx>" % content
            if content else "")

    return (
        "<w:r><w:drawing>"
        '<wp:anchor distT="0" distB="0" distL="0" distR="0" simplePos="0" '
        'relativeHeight="%d" behindDoc="0" locked="0" layoutInCell="0" allowOverlap="1">'
        '<wp:simplePos x="0" y="0"/>'
        '<wp:positionH relativeFrom="page"><wp:posOffset>%s</wp:posOffset></wp:positionH>'
        '<wp:positionV relativeFrom="page"><wp:posOffset>%s</wp:posOffset></wp:positionV>'
        '<wp:extent cx="%s" cy="%s"/>'
        '<wp:effectExtent l="0" t="0" r="0" b="0"/><wp:wrapNone/>'
        '<wp:docPr id="%d" name="%s"/><wp:cNvGraphicFramePr/>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<a:graphicData uri="http://schemas.microsoft.com/office/word/2010/'
        'wordprocessingShape">'
        '<wps:wsp><wps:cNvSpPr txBox="0"/><wps:spPr bwMode="auto">'
        '<a:xfrm><a:off x="0" y="0"/><a:ext cx="%s" cy="%s"/></a:xfrm>'
        '<a:prstGeom prst="%s">%s</a:prstGeom>%s%s%s</wps:spPr>%s%s'
        "</wps:wsp></a:graphicData></a:graphic></wp:anchor></w:drawing></w:r>"
        % (z, emu(x), emu(y), emu(w), emu(h), sid, name,
           emu(w), emu(h), geom, av, fill_xml, ln_xml, eff, txbx, body)
    )


# ---------------------------------------------------------------------------
# the five clouds, in the order a formulation is usually talked through
# ---------------------------------------------------------------------------
CLOUDS = [
    dict(n="1", q="What do people worry about for you?",
         hint="What other people have noticed",
         g1="F3F9FE", g2="D2E9FA", ln="7FBBE4", ac="17557F", bg="2E86C1"),
    dict(n="2", q="What have been the things you have found difficult in your life?",
         hint="Things that have happened to you",
         g1="F7F4FD", g2="E1D8F7", ln="A08FDC", ac="473489", bg="6A56B8"),
    dict(n="3", q="What are the things that trigger you, or make things more "
                  "difficult for you?",
         hint="Moments, places, people or feelings",
         g1="FFF7F0", g2="FCDFC7", ln="EDA974", ac="98460F", bg="D2712A"),
    dict(n="4", q="What are the things that keep you stuck?",
         hint="What gets in the way of things changing",
         g1="FFFCEE", g2="FAEBBA", ln="DFBB56", ac="755600", bg="9C7400"),
    dict(n="5", q="What are the things that help you and keep you safe?",
         hint="Your people, your places, your ways of coping",
         g1="F0F9F3", g2="D1ECDA", ln="7BC199", ac="19613B", bg="2E9160"),
]

M = 0.42                                    # page margin
ROW1_Y, ROW1_H, COL_W = 1.80, 4.30, 4.95    # three clouds across
ROW2_Y, ROW2_H, ROW2_W = 6.44, 4.78, 7.55   # two wider clouds below

POS = [
    (M,     ROW1_Y, COL_W,  ROW1_H),
    (5.80,  ROW1_Y, COL_W,  ROW1_H),
    (11.18, ROW1_Y, COL_W,  ROW1_H),
    (M,     ROW2_Y, ROW2_W, ROW2_H),
    (8.58,  ROW2_Y, ROW2_W, ROW2_H),
]

BADGE_D = 0.54


def build_body():
    parts = []

    # ---- header -----------------------------------------------------------
    parts.append(shape("Sun glow", 0.44, 0.40, 1.02, 1.02, geom="ellipse",
                       fill="FFEECA", z=4))
    parts.append(shape("Sun", 0.60, 0.56, 0.70, 0.70, geom="ellipse",
                       fill="FFC94F", z=5))

    parts.append(shape(
        "Title", 1.66, 0.34, 9.6, 0.80, anchor="ctr", insets=(0, 0, 0, 0), z=6,
        content=para([run("My Clouds", size=40, bold=True, color="1F4E79",
                          spacing=-4)], align="left")))

    parts.append(shape(
        "Subtitle", 1.70, 1.09, 10.4, 0.36, anchor="ctr", insets=(0, 0, 0, 0), z=7,
        content=para([run("There are no right or wrong answers " + EMDASH +
                          " write, draw or just talk about whatever you like "
                          "in each cloud.", size=13, color=MUTED)], align="left")))

    # name / date card -- the rules are shapes, so they always print
    card_x, card_y, card_w, card_h = 12.30, 0.42, 3.82, 1.06
    parts.append(shape("Name card", card_x, card_y, card_w, card_h,
                       geom="roundRect", adj={"adj": 15000}, fill="F5FAFD",
                       line="CBDFEE", line_w=1.25, z=8))
    for j, label in enumerate(("Name", "Date")):
        row_y = card_y + 0.22 + j * 0.36
        parts.append(shape(label + " label", card_x + 0.24, row_y, 0.62, 0.26,
                           anchor="ctr", insets=(0, 0, 0, 0), z=9 + j,
                           content=para([run(label, size=12, bold=True,
                                             color="46687F")], align="left")))
        parts.append(shape(label + " rule", card_x + 0.86, row_y + 0.245,
                           card_w - 1.08, 0.014, fill="AFC9DA", z=11 + j))

    parts.append(shape("Divider", M, 1.58, 15.70, 0.03, fill="E1EBF4", z=3))

    # ---- clouds -----------------------------------------------------------
    for i, (c, (x, y, w, h)) in enumerate(zip(CLOUDS, POS)):
        wide = w > 6
        text_top = CT * h                     # top of the cloud's text rectangle

        # the badge clears the cloud's crown; the question starts just under it
        badge_y = y + (0.40 if not wide else 0.42)
        top_ins = (badge_y + BADGE_D + 0.10) - (y + text_top)

        # pad the left inset to pull the text back onto the shape's true centre.
        # Narrow clouds take only part of the correction so the question keeps
        # enough width to break tidily; the leftover offset is under 0.1 in.
        recentre = (1 - CL - CR) * w * (0.55 if not wide else 1.0)
        side = 0.03 if not wide else 0.34
        badge_x = x + w * (CL + CR) / 2 + recentre / 2 - BADGE_D / 2

        content = (
            para([run(c["q"], size=16, bold=True, color=c["ac"])],
                 align="center", line=14.5) +
            para([run(c["hint"], size=10.5, italic=True, color=MUTED)],
                 align="center", before=6)
        )
        parts.append(shape("Cloud " + c["n"], x, y, w, h, geom="cloud",
                           grad=(c["g1"], c["g2"]), line=c["ln"], line_w=2.25,
                           content=content, anchor="t", z=20 + i, shadow="63839C",
                           insets=(side + recentre, top_ins, side, 0.2)))

        parts.append(shape("Badge " + c["n"], badge_x, badge_y, BADGE_D, BADGE_D,
                           geom="ellipse", fill=c["bg"], anchor="ctr", z=40 + i,
                           insets=(0.02, 0.02, 0.02, 0.02),
                           content=para([run(c["n"], size=15, bold=True,
                                             color="FFFFFF")], align="center")))

    # ---- footer -----------------------------------------------------------
    parts.append(shape(
        "Footer", M, 11.24, 8.0, 0.3, anchor="ctr", insets=(0, 0, 0, 0), z=2,
        content=para([run("Formulation clouds  " + MIDDOT +
                          "  for children and young people", size=9.5,
                          color="67737F")], align="left")))

    # every shape hangs off a single, deliberately tiny paragraph
    holder = ('<w:p><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/>'
              '<w:rPr><w:sz w:val="2"/></w:rPr></w:pPr>%s</w:p>' % "".join(parts))

    sect = ('<w:sectPr><w:pgSz w:w="%d" w:h="%d" w:orient="landscape" w:code="8"/>'
            '<w:pgMar w:top="284" w:right="284" w:bottom="284" w:left="284" '
            'w:header="0" w:footer="0" w:gutter="0"/>'
            '<w:cols w:space="708"/><w:docGrid w:linePitch="360"/></w:sectPr>'
            % (int(PAGE_W * TW), int(PAGE_H * TW)))

    return "<w:body>%s%s</w:body>" % (holder, sect)


# ---------------------------------------------------------------------------
# package
# ---------------------------------------------------------------------------
XML_DECL = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\r\n'

CONTENT_TYPES = XML_DECL + (
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.'
    'relationships+xml"/><Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/word/document.xml" ContentType="application/vnd.'
    'openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.'
    'openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.'
    'openxmlformats-package.core-properties+xml"/>'
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.'
    'openxmlformats-officedocument.extended-properties+xml"/></Types>'
)

ROOT_RELS = XML_DECL + (
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/'
    '2006/relationships/officeDocument" Target="word/document.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/'
    'relationships/metadata/core-properties" Target="docProps/core.xml"/>'
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/'
    '2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>'
)

DOC_RELS = XML_DECL + (
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/'
    '2006/relationships/styles" Target="styles.xml"/></Relationships>'
)

STYLES = XML_DECL + (
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    "<w:docDefaults><w:rPrDefault><w:rPr>"
    '<w:rFonts w:ascii="%s" w:hAnsi="%s" w:cs="%s"/>'
    '<w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr></w:rPrDefault>'
    '<w:pPrDefault><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/>'
    "</w:pPr></w:pPrDefault></w:docDefaults>"
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
    '<w:name w:val="Normal"/><w:qFormat/></w:style></w:styles>' % (FONT, FONT, FONT)
)

CORE = XML_DECL + (
    '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/'
    'metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" '
    'xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/'
    'dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    "<dc:title>My Clouds</dc:title>"
    "<dc:subject>Formulation clouds for children and young people</dc:subject>"
    "<cp:revision>1</cp:revision></cp:coreProperties>"
)

APP = XML_DECL + (
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/'
    'extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/'
    '2006/docPropsVTypes"><Application>Microsoft Office Word</Application>'
    "<Pages>1</Pages></Properties>"
)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "CYP_Formulation_Clouds.docx")

    document = XML_DECL + "<w:document %s>%s</w:document>" % (NS, build_body())

    parts = {
        "[Content_Types].xml": CONTENT_TYPES,
        "_rels/.rels": ROOT_RELS,
        "word/_rels/document.xml.rels": DOC_RELS,
        "word/document.xml": document,
        "word/styles.xml": STYLES,
        "docProps/core.xml": CORE,
        "docProps/app.xml": APP,
    }

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for name, data in parts.items():
            z.writestr(name, data.encode("utf-8"))

    print("wrote %s (%d bytes)" % (out, os.path.getsize(out)))


if __name__ == "__main__":
    main()
