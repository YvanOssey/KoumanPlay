"""Ajoute à assets/content/content_v2.json les proverbes et quiz « Trésors » sourcés.

Chaque question cite sa source dans l'explication. Tout reste `validated: false`
jusqu'à la relecture par un locuteur de référence (DEHE Firmin).
Relançable : les niveaux et questions ajoutés sont remplacés, pas dupliqués.

    python tool/add_sourced_content.py
    python tool/harder_distractors.py   # mauvaises réponses plausibles, seuil 70 %
    dart run tool/generate_seed.dart
"""
import json
from pathlib import Path

CONTENT = Path(__file__).resolve().parent.parent / "assets" / "content" / "content_v2.json"

NZASSA = ("Source : Touman Kouadio H., « Proverbes et culture : le cas des proverbes baoulé et sénoufo "
          "de Côte d'Ivoire », revue Nzassa, Université Alassane Ouattara.")
AFRO = "Source : Dr Y., afrolegends.com."
ZOKO = "Source : Habib Zoko, Proverbes ivoiriens chez les Bétés."
CMA = "Source : The Cleveland Museum of Art (Open Access). Voir la fiche dans la Bibliothèque."
Q = "Que veut dire ce proverbe ?"

# (id, proverbe, original ou None, bonne réponse, 3 mauvaises réponses, explication, source)
PROVERBS = {
    ("baoule", "baoule-9", "Aimer et partager"): [
        ("nz-bci-01", "L'être humain est meilleur que l'or.", "srã ble ɔ ti kpa tra sika ɔklwɛ",
         "Une personne vaut plus que toutes les richesses.",
         ["L'or est le bien le plus précieux.", "Il faut garder son or caché.", "Les riches sont meilleurs que les autres."],
         "Chez les Baoulé, l'or est le bien le plus précieux, mais l'être humain vaut plus encore : on aime son prochain sans cupidité.", NZASSA),
        ("nz-bci-02", "L'amour appelle l'amour.", "klolɛ flɛ klolɛ",
         "Celui qui aime les autres est aimé en retour.",
         ["Il ne faut aimer qu'une seule personne.", "L'amour rend aveugle.", "Il faut se méfier de ceux qui nous aiment."],
         "Aimer les autres attire leur amour : si chacun aime, le monde se remplit d'amour.", NZASSA),
        ("nz-bci-03", "Le jour de ton prochain est aussi ton jour.", "viégu i tchin ɔ ti ɔ liɛ",
         "Il faut être solidaire de ceux qui nous entourent.",
         ["Chacun doit vivre sa propre journée.", "Il faut se lever tôt.", "Les fêtes des autres ne nous regardent pas."],
         "Ce proverbe rappelle à l'ordre celui qui s'éloigne de la solidarité.", NZASSA),
        ("nz-bci-04", "Chaque arbre a ses fruits.", "ɔ le baka kun ni ma",
         "Celui qui fait le bien en récoltera les fruits.",
         ["Tous les arbres se ressemblent.", "Il faut planter beaucoup d'arbres.", "Chacun doit garder ce qu'il a."],
         "Le bienfait n'est jamais perdu : celui qui fait le bien sera béni.", NZASSA),
        ("nz-bci-05", "Si on ne voit pas le cadavre, on ne fabrique pas son cercueil.", None,
         "Il ne faut pas juger quelqu'un sans le connaître.",
         ["Il faut préparer les funérailles à l'avance.", "Il faut toujours croire ce qu'on entend.", "Les morts doivent être vus par tous."],
         "Ce proverbe combat les préjugés : on ne prête pas de défauts à quelqu'un sans avoir vécu avec lui.", NZASSA),
        ("nz-bci-06", "On n'emballe pas la vie dans une feuille de taro.", "be kiti man koko gna nu",
         "La vie est précieuse, il faut la protéger.",
         ["Il faut emballer ses affaires avec soin.", "Les feuilles de taro sont solides.", "La vie est courte, il faut en profiter."],
         "La feuille de taro sèche et se déchire vite au soleil : on ne confie pas la vie, premier droit de chacun, à quelque chose d'aussi fragile.", NZASSA),
    ],
    ("baoule", "baoule-10", "Respect et vivre-ensemble"): [
        ("nz-bci-07", "Les champignons ne poussent pas au faîte de l'arbre.", "waka ti nu fí mã ŋdre",
         "Personne ne doit se placer au-dessus de l'autorité.",
         ["Les champignons poussent partout.", "Il faut grimper aux arbres avec prudence.", "Les meilleures choses sont tout en haut."],
         "L'enfant qui grandit à l'ombre de ses parents, dans le respect, profite de leurs conseils pour réussir.", NZASSA),
        ("nz-bci-08", "On n'exerce pas le pouvoir en ignorant les enfants.", None,
         "Ceux qui dirigent doivent tenir compte des jeunes.",
         ["Les enfants ne doivent pas parler aux chefs.", "Le pouvoir revient aux plus jeunes.", "Un chef doit avoir beaucoup d'enfants."],
         "Le pouvoir des anciens se soucie de l'avenir de la nouvelle génération : les jeunes comptent.", NZASSA),
        ("nz-bci-09", "On ne fonde pas un campement avec quelqu'un avec qui on ne s'entend pas.", "be ni srã be di mã be bo mã nãmwe",
         "Vivre et travailler ensemble demande de bien s'entendre.",
         ["Il vaut mieux vivre seul.", "Un campement doit être construit loin du village.", "Il faut toujours suivre le plus fort."],
         "Un véritable appel à l'entente pour une vie sociale harmonieuse.", NZASSA),
        ("nz-bci-10", "Avant de te marier, renseigne-toi.", "adja bisa",
         "Il faut bien connaître la personne avant de s'engager.",
         ["Il faut se marier jeune.", "Le mariage se décide par les parents seuls.", "Il ne faut jamais se marier."],
         "Prendre le temps de connaître le caractère de l'autre évite bien des unions difficiles.", NZASSA),
        ("nz-bci-11", "Le linge sale se lave en famille.", None,
         "On règle d'abord ses différends en famille, avant de les exposer.",
         ["Il faut laver son linge à la maison.", "Les problèmes doivent être réglés devant tout le village.", "La famille doit tout cacher."],
         "On ne saute pas d'étape : chef de famille, chef de village, chef de canton, puis roi.", NZASSA),
    ],
    ("baoule", "baoule-11", "Travail et paix"): [
        ("nz-bci-12", "Si tu ne te fatigues pas, tu ne riras pas.", "a fɛ mã a sri mã",
         "Pour connaître le bonheur, il faut travailler.",
         ["Il faut éviter de se fatiguer.", "Rire fatigue beaucoup.", "Le travail empêche d'être heureux."],
         "Celui qui veut jouir du bonheur doit se mettre au travail.", NZASSA),
        ("nz-bci-13", "C'est la personne qui creuse dans la termitière qui a la poitrine rouge.", "srã mɔ ɔ fu srwe jɛ i wue ɔ blo",
         "Celui qui mérite les honneurs se reconnaît à ses efforts.",
         ["Les termitières sont dangereuses.", "Il faut se protéger du soleil.", "Le rouge est la couleur des chefs."],
         "La terre rouge de la termitière colore la poitrine de celui qui creuse : ses exploits se voient.", NZASSA),
        ("nz-bci-14", "Si tu déterres l'igname, recouvre les racines du manioc avec de la terre.", "sè a tu duo kata agba bo",
         "Il faut protéger les ressources pour les générations futures.",
         ["Il faut planter l'igname avant le manioc.", "Le manioc est meilleur que l'igname.", "Il faut récolter tout le champ d'un coup."],
         "Une image tirée des champs pour appeler à préserver la nature et en faire profiter ceux qui viendront après.", NZASSA),
        ("nz-bci-15", "Là où on garde sa poterie d'huile, on n'y lance pas des pierres.", "lika nga be ŋgo sɛ ɔ o lɛ be to mã lɛ jɔbu",
         "On ne fait pas de mal à ce qui nous fait vivre.",
         ["Il faut ranger l'huile en hauteur.", "Les poteries cassent facilement.", "Il ne faut jamais lancer de pierres."],
         "Lancer des pierres casserait les poteries et ferait perdre l'huile : on prend soin de sa communauté et de son pays.", NZASSA),
        ("nz-bci-16", "C'est quand il y a la paix au village qu'il peut y avoir la paix en brousse.", None,
         "La paix commence en famille avant de s'étendre à toute la société.",
         ["La brousse est plus calme que le village.", "Il faut partir en brousse pour être tranquille.", "La paix ne dépend que des chefs."],
         "Le village, c'est la famille ; la brousse, toute la société : s'entendre avec les siens permet de s'entendre avec les autres.", NZASSA),
        ("nz-bci-17", "Le pardon est le dernier mot.", None,
         "Il faut savoir pardonner pour mettre fin aux conflits.",
         ["Celui qui parle en dernier a raison.", "Il ne faut jamais pardonner.", "Il faut toujours avoir le dernier mot."],
         "Il n'y a plus rien à dire à celui qui refuse le pardon : les sages poussent ainsi à la réconciliation.", NZASSA),
    ],
    ("senoufo", "senoufo-6", "Solidarité et sagesse"): [
        ("nz-sen-01", "Quand le doigt fait mal, l'œil n'a pas sommeil.", "kabani kana ja ɲɛ̃pini ko bãna wunɔ̃i",
         "Il faut être solidaire de ceux qui souffrent.",
         ["Il faut soigner ses blessures rapidement.", "La douleur empêche de dormir.", "Chacun doit régler ses propres problèmes."],
         "L'amour du prochain pousse à aider ceux qui sont en difficulté : le vrai bonheur est partagé.", NZASSA),
        ("nz-sen-02", "Sur la tête du méchant, il ne pousse pas de cornes.", None,
         "La méchanceté n'apporte ni honneur ni dignité.",
         ["Les méchants sont faciles à reconnaître.", "Seuls les animaux ont des cornes.", "Il faut craindre les méchants."],
         "Les cornes symbolisent l'autorité, la dignité et l'honneur : le méchant n'est ni béni ni élevé.", NZASSA),
        ("nz-sen-03", "Il ne faut pas demander au sel d'être sucré.", "faɡa jasɔɡi jeɡi tɛ̃nɛ̃ sikaʀawi dɛlɛi",
         "Il faut accepter les autres dans leur différence.",
         ["Il ne faut pas trop saler la sauce.", "Le sucre est meilleur que le sel.", "Il faut changer ceux qui sont différents."],
         "Exiger de l'autre qu'il soit ce qu'il n'est pas crée des conflits : chacun est utile à sa façon, comme le sel dans la sauce.", NZASSA),
        ("nz-sen-04", "L'enfant obéissant ne meurt pas de faim.", "kateʔe ko pi lowe kui",
         "Écouter ses parents apporte des avantages.",
         ["Les enfants doivent manger beaucoup.", "Il faut obéir à tout le monde.", "La faim rend les enfants sages."],
         "Les parents sont ceux qui trouvent la nourriture : l'obéissance ne produit que des avantages.", NZASSA),
        ("nz-sen-05", "L'homme est mieux que l'argent.", None,
         "Les personnes passent avant l'argent.",
         ["Il faut gagner beaucoup d'argent.", "Les hommes gagnent plus que les femmes.", "L'argent rend les gens meilleurs."],
         "Les Sénoufo font primer l'humanité en toute circonstance (les Baoulé disent de même : « l'être humain est meilleur que l'or »).", NZASSA),
    ],
    ("senoufo", "senoufo-7", "Vivre ensemble"): [
        ("nz-sen-06", "Le criquet est seul dans son trou, mais il n'est pas le seul sous l'arbre.", None,
         "Le chef décide en concertation avec les sages.",
         ["Les criquets vivent seuls.", "Il faut se cacher pour être tranquille.", "Le chef décide toujours seul."],
         "Le criquet, c'est le chef : il paraît seul car les décisions sont prises en son nom, mais il a le soutien des notables et des sages.", NZASSA),
        ("nz-sen-07", "La femme d'un tel est belle, cela ne veut pas dire qu'elle a bon caractère.", "wɔ̃ co wu ɲɔ̃ ɡiɡe j̄o we fuɡi ɲɔ̃i",
         "La vraie beauté est celle du comportement.",
         ["Il faut épouser la plus belle femme.", "La beauté est le plus important.", "Il ne faut pas regarder la femme des autres."],
         "La beauté physique peut tromper : les Sénoufo conseillent de se fier à la beauté intérieure.", NZASSA),
        ("nz-sen-08", "Le matin, les oiseaux s'envolent, mais le soir, ils reviennent tous au nid.", "ɲiɡidãni fij̄ãɡele nalali cãɡi ɡakɔ ɡolugo ɡezaʀi mã",
         "On peut partir chercher ailleurs, mais il faut revenir à ses racines.",
         ["Les oiseaux se lèvent tôt.", "Il ne faut jamais quitter son village.", "Le soir, il faut rentrer avant la nuit."],
         "Le matin est le temps de la recherche, le soir celui du retour : l'expatrié qui revient enrichit son pays.", NZASSA),
        ("nz-sen-09", "Dieu s'appuie sur toi-même pour t'aider.", "kolocɔlɔ sewe siʔi mu na bu mu dɛbɛ",
         "Il faut faire des efforts pour réussir.",
         ["Il suffit d'attendre l'aide de Dieu.", "Il faut aider les autres avant soi.", "Personne ne peut nous aider."],
         "Garder espoir, mais redoubler d'efforts : l'effort favorise la réussite.", NZASSA),
        ("nz-sen-10", "C'est celui qui a tué la panthère qui doit avoir la tête rasée.", None,
         "Les honneurs reviennent à celui qui a vraiment excellé.",
         ["Les chasseurs doivent se raser la tête.", "Il est interdit de chasser la panthère.", "Le plus âgé reçoit tous les honneurs."],
         "Chez les Sénoufo, on honore le chasseur dozo qui a tué une panthère en lui rasant la tête : le mérite se reconnaît.", NZASSA),
        ("nz-sen-11", "Les chefs n'arrangent pas leurs palabres devant l'assemblée.", "kaʔa fɔbele ko be kasi cɔ̃ʀi kaʔa sibele jɛmai",
         "Les conflits entre responsables se règlent avec discrétion.",
         ["Les chefs ne se disputent jamais.", "Tout doit être discuté devant le village.", "Les chefs ne parlent pas en public."],
         "Régler les différends loin des regards préserve le respect et évite les tensions.", NZASSA),
    ],
    ("bete", "bete-6", "Sagesse bété"): [
        ("afro-bev-01", "Lorsque l'œil pleure, le nez ne se réjouit pas.", None,
         "Le malheur d'une personne touche aussi ses proches.",
         ["Il ne faut pas pleurer en public.", "Le nez et les yeux sont liés.", "Chacun vit son malheur seul."],
         "Le malheur de quelqu'un touche aussi ses parents et ses amis.", AFRO),
        ("afro-bev-02", "Quand le doigt ne sait où aller, il entre dans le nez.", None,
         "Trop d'inactivité pousse à faire des bêtises.",
         ["Il faut garder les mains propres.", "Le doigt connaît toujours son chemin.", "Il faut se reposer souvent."],
         "Trop d'inactivité conduit à n'importe quelle bêtise.", AFRO),
        ("afro-bev-03", "Les doigts de la main n'ont pas la même longueur.", None,
         "Les hommes ne sont pas tous égaux.",
         ["Il faut prendre soin de ses mains.", "Le plus grand doigt est le plus fort.", "Tout le monde a les mêmes chances."],
         "Les hommes ne sont jamais égaux.", AFRO),
        ("zoko-bev-01", "Seul son coiffeur peut toucher la tête du roi.", None,
         "Pour obtenir quelque chose de quelqu'un, il faut d'abord gagner sa confiance.",
         ["Personne ne doit toucher le roi.", "Il faut bien choisir son coiffeur.", "Le roi doit se coiffer lui-même."],
         "Pour profiter de quelqu'un, il faut d'abord gagner son amitié.", ZOKO),
        ("zoko-bev-02", "Tu donnes des conseils au renard, donnes-en aussi à la poule.", None,
         "Celui qui est en danger doit aussi être prudent.",
         ["Les renards écoutent les conseils.", "Il faut garder les poules enfermées.", "Il ne faut conseiller que les forts."],
         "Le renard mange les poules : la poule, elle, ne doit pas s'éloigner de chez elle.", ZOKO),
    ],
}

# Quiz « Trésors » : (id, intitulé affiché, question, bonne réponse, mauvaises, explication)
TREASURES = {
    ("baoule", "baoule-12", "Trésors baoulé"): [
        ("cma-q-bci-01", "Masque portrait mblo", "Quand sortent les masques mblo ?",
         "Lors de danses de divertissement", ["Pour la guerre", "Seulement aux funérailles des rois", "Pour les récoltes d'igname"],
         "Les masques mblo, très appréciés des Baoulé, sortent lors de danses de divertissement. Ils sont vus comme les portraits de personnes connues."),
        ("cma-q-bci-02", "Pendentifs en or baoulé", "À quoi les objets en or sont-ils liés chez les Baoulé ?",
         "Aux esprits des ancêtres", ["Aux travaux des champs", "À la chasse", "Au commerce du sel"],
         "Les objets en or sont les seules œuvres baoulé liées aux esprits des ancêtres. On les sort lors des grandes occasions, comme les funérailles."),
        ("cma-q-bci-03", "Pendentifs en or baoulé", "Avec quelle technique ces pendentifs sont-ils coulés ?",
         "La cire perdue", ["Le tissage", "La poterie", "La sculpture sur bois"],
         "L'orfèvre façonne le modèle en cire ; la cire fond dans un moule où l'on verse ensuite l'or liquide."),
        ("cma-q-bci-04", "Pendentif au front marqué « ngwa »", "Que signifie « ngwa », la marque en croissant sur le front ?",
         "La lune", ["Le soleil", "L'étoile", "La rivière"],
         "La scarification en forme de croissant sur le front s'appelle ngwa, la « lune »."),
        ("cma-q-bci-05", "Couple de statuettes asye usu", "Que représentent souvent les statuettes baoulé sculptées par paires ?",
         "Des esprits de la brousse", ["Des rois et des reines", "Des jumeaux", "Des chasseurs célèbres"],
         "Elles représentent souvent les asye usu, esprits de la brousse ; on les sculpte belles et parées pour les séduire."),
        ("cma-q-bci-06", "Masque kplé kplé", "Dans quelle danse le masque kplé kplé apparaît-il en premier ?",
         "La danse goli", ["Le zaouli", "L'abissa", "Le boloye"],
         "Le kplé kplé ouvre la danse goli, où quatre paires de masques se succèdent ; il est porté par de jeunes garçons."),
        ("cma-q-bci-07", "Poulie de métier à tisser", "À quoi sert une poulie de métier à tisser ?",
         "À soutenir et séparer les fils", ["À moudre le grain", "À porter l'eau", "À battre le tambour"],
         "Placée au-dessus du tisserand, la poulie soutient les fils ; on la décore d'une sculpture agréable à regarder."),
    ],
    ("senoufo", "senoufo-8", "Trésors sénoufo"): [
        ("cma-q-sen-01", "Maternité sénoufo", "Dans la société sénoufo, par qui l'héritage se transmet-il ?",
         "Par les femmes (lignée maternelle)", ["Par le fils aîné", "Par le chef du village", "Par les forgerons"],
         "La maternité des ancêtres est centrale chez les Sénoufo, où l'héritage se transmet par les femmes."),
        ("cma-q-sen-02", "Maternité sénoufo", "Comment s'appelle la Grande Mère qui nourrit les initiés du « lait du savoir » ?",
         "Katyeleeo (ou Maleeo)", ["Abla Pokou", "Mami Wata", "Yaa Asantewaa"],
         "Pour certains Sénoufo, la Grande Mère Katyeleeo, ou Maleeo, nourrit les jeunes initiés du « lait du savoir »."),
        ("cma-q-sen-03", "Casque sénoufo", "Ce casque marquait le passage d'un garçon à une nouvelle classe d'âge, avant son initiation à…",
         "Le Poro", ["Le Goli", "Le Zaouli", "Le Dipri"],
         "Ce casque était porté lors des rituels de passage d'une classe d'âge à l'autre, avant l'initiation au Poro."),
        ("cma-q-sen-04", "Oiseau-trophée sénoufo", "À qui remettait-on l'oiseau-trophée ?",
         "Au vainqueur d'un concours de culture à la houe", ["Au meilleur chasseur", "Au chef du village", "Au plus jeune initié"],
         "Le bâton surmonté de l'oiseau récompense le vainqueur d'un concours de culture entre jeunes hommes."),
        ("cma-q-sen-05", "Oiseau-trophée sénoufo", "Quel oiseau est représenté sur ce trophée ?",
         "Un aigle en vol", ["Un calao", "Un hibou", "Un perroquet"],
         "Le trophée représente un aigle en vol, qui surmontait un long bâton."),
    ],
}

# Ordre des niveaux par langue après ajout : proverbes, trésors, puis mots et phrases.
ORDER = {
    "baoule": ["baoule-6", "baoule-7", "baoule-8", "baoule-9", "baoule-10", "baoule-11", "baoule-12",
               "baoule-1", "baoule-2", "baoule-3", "baoule-4", "baoule-5"],
    "senoufo": ["senoufo-6", "senoufo-7", "senoufo-8", "senoufo-1", "senoufo-2", "senoufo-3", "senoufo-4", "senoufo-5"],
}


def activity(aid, level_id, prompt, original, language, question, right, wrong, explanation):
    return {"id": aid, "levelId": level_id, "proverb": prompt, "original": original,
            "language": language if original else None, "question": question,
            "answers": [right, *wrong], "correct": 0, "explanation": explanation, "xp": 20, "validated": False}


def main():
    d = json.loads(CONTENT.read_text(encoding="utf-8"))
    names = {l["id"]: l["name"] for l in d["languages"]}
    levels = {l["id"]: l for l in d["levels"]}
    new_ids, new_acts = set(), []

    def ensure_level(lang, lid, title, kind):
        lvl = levels.get(lid) or {"id": lid, "languageId": lang, "order": 0, "passRatio": 0.6}
        lvl.update(title=title, kind=kind)
        levels[lid] = lvl

    for (lang, lid, title), items in PROVERBS.items():
        ensure_level(lang, lid, title, "proverbes")
        for aid, prov, orig, right, wrong, expl, src in items:
            new_ids.add(aid)
            new_acts.append(activity(aid, lid, prov, orig, names[lang], Q, right, wrong, f"{expl} {src}"))
    for (lang, lid, title), items in TREASURES.items():
        ensure_level(lang, lid, title, "tresors")
        for aid, prompt, question, right, wrong, expl in items:
            new_ids.add(aid)
            new_acts.append(activity(aid, lid, prompt, None, None, question, right, wrong, f"{expl} {CMA}"))

    for lang, ids in ORDER.items():
        for n, lid in enumerate(ids, start=1):
            levels[lid]["order"] = n
    d["levels"] = sorted(levels.values(), key=lambda l: (list(names).index(l["languageId"]), l["order"]))
    d["activities"] = [a for a in d["activities"] if a["id"] not in new_ids] + new_acts
    CONTENT.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(new_acts)} questions ajoutées ; {len(d['activities'])} au total.")


if __name__ == "__main__":
    main()
