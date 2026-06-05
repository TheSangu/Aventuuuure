#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génère un guide .docx clair (sans dépendance externe) pour configurer
l'envoi automatique des pas. Construit un paquet OOXML minimal et valide."""

import os
import zipfile

OUT = os.path.join(os.path.dirname(__file__), "..", "Guide-Nico-Envoyer-mes-pas.docx")


def esc(t):
    return (t.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
             .replace('"', "&quot;"))


def run(text, bold=False, mono=False, color=None, size=None):
    rpr = ""
    props = ""
    if bold:
        props += "<w:b/>"
    if mono:
        props += '<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/>'
    if color:
        props += f'<w:color w:val="{color}"/>'
    if size:
        props += f'<w:sz w:val="{size*2}"/>'
    if props:
        rpr = f"<w:rPr>{props}</w:rPr>"
    # préserve les espaces
    return f'<w:r>{rpr}<w:t xml:space="preserve">{esc(text)}</w:t></w:r>'


def para(runs="", style=None, spacing_after=120):
    ppr = "<w:pPr>"
    if style:
        ppr += f'<w:pStyle w:val="{style}"/>'
    ppr += f'<w:spacing w:after="{spacing_after}"/>'
    ppr += "</w:pPr>"
    if isinstance(runs, str):
        runs = run(runs) if runs else ""
    return f"<w:p>{ppr}{runs}</w:p>"


def heading(text, lvl=1):
    return para(run(text, bold=True, color=("0A2540" if lvl == 1 else "2F7FD6"),
                    size=(16 if lvl == 1 else 13)),
                style=f"Heading{lvl}", spacing_after=80)


def title(text):
    return para(run(text, bold=True, color="0A2540", size=22), spacing_after=60)


def code(text):
    # Paragraphe encadré gris, police monospace.
    ppr = ('<w:pPr><w:shd w:val="clear" w:color="auto" w:fill="F2F4F7"/>'
           '<w:pBdr><w:top w:val="single" w:sz="4" w:space="2" w:color="D0D7DE"/>'
           '<w:left w:val="single" w:sz="4" w:space="2" w:color="D0D7DE"/>'
           '<w:bottom w:val="single" w:sz="4" w:space="2" w:color="D0D7DE"/>'
           '<w:right w:val="single" w:sz="4" w:space="2" w:color="D0D7DE"/></w:pBdr>'
           '<w:spacing w:after="120"/></w:pPr>')
    return f"<w:p>{ppr}{run(text, mono=True, size=10)}</w:p>"


def step(n, runs):
    """Étape numérotée : « n. » en gras suivi du contenu (liste de runs)."""
    head = run(f"{n}.  ", bold=True, color="2F7FD6")
    if isinstance(runs, str):
        runs = run(runs)
    return para(head + runs, spacing_after=120)


def bullet(runs):
    if isinstance(runs, str):
        runs = run(runs)
    return para(run("•  ", bold=True) + runs, spacing_after=80)


# ---------------------------------------------------------------------------
BODY = []
B = BODY.append

B(title("Envoyer mes pas automatiquement"))
B(para(run("Guide pas à pas — à suivre une seule fois (≈ 10 minutes).", color="6B7280")))

B(para(run("Avant de commencer", bold=True) + run("  : récupère le « jeton » que ton ami t'a transmis (un texte qui commence par "), spacing_after=40))
B(code("github_pat_……"))
B(para(run("Tu le colleras à l'étape 12. Garde aussi ces deux valeurs sous les yeux :")))
B(code("Adresse : https://api.github.com/repos/thesangu/Aventuuuure/contents/data/pas/"))
B(code("Branche : claude/stoic-goodall-cY7kL"))

# Partie A
B(heading("Partie A — Créer le raccourci", 1))
B(step(1, run("Ouvre l'application ") + run("Raccourcis", bold=True) + run(" (icône grise avec deux carrés colorés).")))
B(step(2, run("En bas, choisis l'onglet ") + run("Raccourcis", bold=True) + run(", puis touche le ") + run("+", bold=True) + run(" en haut à droite.")))
B(step(3, run("Touche ") + run("Ajouter une action", bold=True) + run(". Pour chaque action ci-dessous, tape son nom dans la ") + run("barre de recherche", bold=True) + run(" en bas, puis touche-la.")))

B(heading("Action 1 — lire les pas", 2))
B(bullet(run("Cherche ") + run("« Rechercher des échantillons de santé »", bold=True) + run(" et ajoute-la.")))
B(bullet(run("Touche ") + run("Type", bold=True) + run(" → choisis ") + run("Nombre de pas", bold=True) + run(".")))
B(bullet(run("Touche ") + run("Ajouter un filtre", bold=True) + run(" → ") + run("Date de début", bold=True) + run(" → ") + run("est", bold=True) + run(" → ") + run("aujourd'hui", bold=True) + run(".")))

B(heading("Action 2 — additionner", 2))
B(bullet(run("Cherche ") + run("« Calculer la statistique »", bold=True) + run(".")))
B(bullet(run("Règle l'opération sur ") + run("Somme", bold=True) + run(" (le reste se remplit tout seul).")))

B(heading("Action 3 — la date", 2))
B(bullet(run("Cherche ") + run("« Date »", bold=True) + run(" (elle donne la date du jour).")))

B(heading("Action 4 — mettre la date au bon format", 2))
B(bullet(run("Cherche ") + run("« Formater la date »", bold=True) + run(".")))
B(bullet(run("Touche le format → ") + run("Personnalisé", bold=True) + run(" → écris exactement :")))
B(code("yyyy-MM-dd"))

B(heading("Action 5 — préparer le texte", 2))
B(bullet(run("Cherche ") + run("« Texte »", bold=True) + run(". Dans le cadre, tu vas écrire la ligne ci-dessous.")))
B(bullet(run("Astuce : pour insérer un résultat précédent, touche le ") + run("bouton variable", bold=True) + run(" au-dessus du clavier.")))
B(bullet(run("Écris ") + run("{\"date\":\"", mono=True) + run("  puis insère la variable ") + run("Date formatée", bold=True) + run("  puis ") + run("\",\"pas\":", mono=True) + run("  puis insère la variable ") + run("Statistique", bold=True) + run("  puis ") + run("}", mono=True) + run(".")))
B(para(run("Le résultat doit ressembler à ceci :", color="6B7280")))
B(code('{"date":"[Date formatée]","pas":[Statistique]}'))

B(heading("Action 6 — encoder", 2))
B(bullet(run("Cherche ") + run("« base64 »", bold=True) + run(" et choisis ") + run("« Encoder le texte »", bold=True) + run(". Elle prend automatiquement le texte de l'action 5.")))

# Partie B
B(heading("Partie B — L'envoi vers GitHub", 1))
B(heading("Action 7 — Obtenir le contenu de l'URL", 2))
B(step(7, run("Cherche ") + run("« Obtenir le contenu de l'URL »", bold=True) + run(" et ajoute-la.")))
B(step(8, run("Dans le champ ") + run("URL", bold=True) + run(", écris l'adresse, insère la variable ") + run("Date formatée", bold=True) + run(", puis ") + run(".json", mono=True) + run(" :")))
B(code("https://api.github.com/repos/thesangu/Aventuuuure/contents/data/pas/[Date formatée].json"))
B(step(9, run("Touche ") + run("▾ Afficher plus", bold=True) + run(".")))
B(step(10, run("Méthode", bold=True) + run(" → choisis ") + run("PUT", bold=True) + run(".")))
B(step(11, run("En-têtes", bold=True) + run(" → touche ") + run("Ajouter un en-tête", bold=True) + run(" DEUX fois :")))
B(bullet(run("Clé : ") + run("Authorization", mono=True) + run("   →   Valeur : ") + run("Bearer github_pat_……", mono=True)))
B(para(run("        (garde le mot ", color="6B7280") + run("Bearer", mono=True, color="6B7280") + run(" et une espace avant le jeton)", color="6B7280"), spacing_after=60))
B(bullet(run("Clé : ") + run("Accept", mono=True) + run("   →   Valeur : ") + run("application/vnd.github+json", mono=True)))
B(step(12, run("Corps de la requête", bold=True) + run(" → choisis ") + run("JSON", bold=True) + run(", puis ") + run("Ajouter un champ", bold=True) + run(" TROIS fois :")))
B(bullet(run("Type ") + run("Texte", bold=True) + run(" — nom ") + run("message", mono=True) + run(" — valeur ") + run("pas", mono=True)))
B(bullet(run("Type ") + run("Texte", bold=True) + run(" — nom ") + run("content", mono=True) + run(" — valeur : insère la variable ") + run("Texte encodé", bold=True) + run(" (action 6)")))
B(bullet(run("Type ") + run("Texte", bold=True) + run(" — nom ") + run("branch", mono=True) + run(" — valeur ") + run("claude/stoic-goodall-cY7kL", mono=True)))
B(step(13, run("En haut, donne un nom au raccourci (ex. ") + run("Envoyer mes pas", bold=True) + run(") puis touche ") + run("OK", bold=True) + run(".")))

# Partie C
B(heading("Partie C — Tester", 1))
B(step(14, run("Lance le raccourci en le touchant.")))
B(step(15, run("La première fois, l'iPhone demande l'accès à ") + run("Santé", bold=True) + run(" → touche ") + run("Autoriser", bold=True) + run(".")))
B(step(16, run("S'il n'y a ") + run("pas de message rouge", bold=True) + run(", c'est réussi ✓. Préviens ton ami : tes pas apparaîtront sur son écran de suivi dans la minute.")))

# Partie D
B(heading("Partie D — Le rendre automatique chaque jour", 1))
B(step(17, run("Dans ") + run("Raccourcis", bold=True) + run(", va dans l'onglet ") + run("Automatisation", bold=True) + run(" (en bas), puis touche ") + run("+", bold=True) + run(".")))
B(step(18, run("Choisis ") + run("Heure du jour", bold=True) + run(" → règle ") + run("22:00", bold=True) + run(", ") + run("Quotidiennement", bold=True) + run(" → ") + run("Suivant", bold=True) + run(".")))
B(step(19, run("Choisis ") + run("Exécuter le raccourci", bold=True) + run(" → sélectionne ") + run("Envoyer mes pas", bold=True) + run(".")))
B(step(20, run("Désactive ") + run("Demander avant d'exécuter", bold=True) + run(" et confirme.")))
B(para(run("✓ Terminé ! Chaque soir à 22 h, tes pas s'envoient tout seuls.", bold=True, color="2ECC8F")))

# Dépannage
B(heading("En cas de souci", 1))
B(bullet(run("Message rouge au test : vérifie l'adresse (aucune espace, bien ") + run(".json", mono=True) + run(" à la fin).")))
B(bullet(run("Vérifie que la valeur de ") + run("Authorization", mono=True) + run(" commence bien par ") + run("Bearer ", mono=True) + run("(avec l'espace).")))
B(bullet(run("Vérifie que les trois champs JSON s'appellent exactement ") + run("message", mono=True) + run(", ") + run("content", mono=True) + run(", ") + run("branch", mono=True) + run(".")))

document_xml = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:body>' + "".join(BODY) +
    '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
    '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="709" w:footer="709" w:gutter="0"/>'
    '</w:sectPr></w:body></w:document>'
)

styles_xml = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:docDefaults><w:rPrDefault><w:rPr>'
    '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>'
    '<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="fr-FR"/>'
    '</w:rPr></w:rPrDefault></w:docDefaults>'
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/>'
    '<w:pPr><w:keepNext/><w:spacing w:before="240" w:after="80"/></w:pPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/><w:basedOn w:val="Normal"/>'
    '<w:pPr><w:keepNext/><w:spacing w:before="160" w:after="60"/></w:pPr></w:style>'
    '</w:styles>'
)

content_types = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
    '</Types>'
)

rels = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
    '</Relationships>'
)

doc_rels = (
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>'
)

with zipfile.ZipFile(OUT, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", content_types)
    z.writestr("_rels/.rels", rels)
    z.writestr("word/_rels/document.xml.rels", doc_rels)
    z.writestr("word/document.xml", document_xml)
    z.writestr("word/styles.xml", styles_xml)

print("écrit", os.path.abspath(OUT), os.path.getsize(OUT), "octets")
