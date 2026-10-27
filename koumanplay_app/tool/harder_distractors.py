"""Remplace les mauvaises réponses des questions par des réponses plausibles.

Chaque mauvaise réponse ressemble à un vrai sens (lecture au pied de la lettre,
morale voisine ou contraire), mais ne correspond pas au proverbe d'après sa
source. On évite les lectures qui pourraient aussi être justes.
À lancer après tool/add_sourced_content.py :

    python tool/harder_distractors.py
    dart run tool/generate_seed.dart
"""
import json
from pathlib import Path

CONTENT = Path(__file__).resolve().parent.parent / "assets" / "content" / "content_v2.json"

WRONG = {
    "prov-1-01": ["Chacun doit s'occuper de sa propre part du travail.", "Il vaut mieux bien faire une tâche que la faire vite.", "Un travail bâclé se voit toujours."],
    "prov-1-02": ["Le chef doit d'abord écouter sa propre sagesse.", "Il ne faut pas trop réfléchir avant d'agir.", "Celui qui parle seul n'est pas écouté."],
    "prov-1-03": ["Il faut savoir plier pour ne pas rompre.", "Les difficultés finissent toujours par passer.", "Celui qui se met en avant s'expose aux critiques."],
    "prov-1-04": ["Il faut choisir entre la vitesse et la sécurité.", "Les longs voyages demandent une bonne préparation.", "Mieux vaut avancer seul que mal accompagné."],
    "prov-1-05": ["Il faut toujours suivre le chemin de ses parents.", "Celui qui connaît sa route n'a besoin de personne.", "La prudence évite bien des erreurs."],
    "prov-2-01": ["Les jeunes doivent rester debout devant les anciens.", "La patience permet de mieux observer les choses.", "Il faut se reposer pour avoir les idées claires."],
    "prov-2-02": ["La foi doit s'apprendre dès l'enfance.", "Les enfants doivent respecter ce qui est sacré.", "Les parents ne peuvent pas tout expliquer à leurs enfants."],
    "prov-2-03": ["Il faut toujours vérifier qu'on n'a rien oublié.", "On a le droit de changer d'avis.", "Le passé est passé, il faut regarder devant."],
    "prov-2-04": ["Il faut garder les recettes des anciens.", "Ce qui est simple est souvent le meilleur.", "Il ne faut pas jeter ce qui peut encore servir."],
    "prov-2-05": ["Les aînés sont les gardiens des livres et des archives.", "Il faut honorer les anciens après leur mort.", "Le savoir écrit vaut plus que la parole."],
    "prov-3-01": ["Une promesse doit toujours être tenue.", "Les paroles s'oublient aussi vite qu'elles sont dites.", "Il ne faut pas gaspiller ce qui est précieux."],
    "prov-3-02": ["Avec le temps, on finit par s'adapter à son milieu.", "Il faut se méfier des apparences.", "La patience ne suffit pas sans le talent."],
    "prov-3-03": ["Quand on hésite, il vaut mieux faire demi-tour.", "Il faut demander conseil avant de partir.", "Il ne faut jamais quitter sa terre natale."],
    "prov-3-04": ["Ce qui commence mal finit souvent mal.", "Il faut savoir profiter des moments doux de la vie.", "Le travail de la terre demande beaucoup de soins."],
    "prov-3-05": ["Un beau discours vaut mieux qu'un long silence.", "Les apparences reflètent souvent la réalité.", "Un petit mensonge peut parfois rendre service."],
    "nz-bci-01": ["La richesse finit toujours par se perdre.", "Un homme honnête finit par devenir riche.", "Il faut travailler dur pour gagner sa vie."],
    "nz-bci-02": ["L'amour se mérite par les cadeaux.", "Il faut aimer sans rien attendre en retour.", "Le véritable amour est rare."],
    "nz-bci-03": ["Chaque jour apporte sa part de bonheur.", "Il faut savoir attendre son tour.", "Le temps passe pour tout le monde de la même façon."],
    "nz-bci-04": ["Il faut planter des arbres pour ses enfants.", "Il ne faut pas convoiter ce qui appartient aux autres.", "Tout finit par mûrir avec le temps."],
    "nz-bci-05": ["Il faut respecter les morts.", "Il vaut mieux croire ce que disent les autres.", "Les mauvaises nouvelles arrivent toujours vite."],
    "nz-bci-06": ["Il ne faut pas confier ses secrets à n'importe qui.", "Les choses simples sont souvent les plus solides.", "Il faut bien choisir ses outils pour chaque travail."],
    "nz-bci-07": ["Chaque chose pousse à l'endroit qui lui convient.", "Les plus petits sont souvent les plus utiles.", "Il ne faut pas chercher la richesse trop loin."],
    "nz-bci-08": ["Les enfants doivent apprendre à obéir aux chefs.", "Un chef doit avoir une grande famille.", "Le pouvoir se transmet de père en fils."],
    "nz-bci-09": ["Il faut bien choisir l'endroit où l'on s'installe.", "On ne doit jamais quitter son village.", "Chacun doit construire sa propre maison."],
    "nz-bci-10": ["Il faut l'accord de ses parents pour se marier.", "Le mariage doit se préparer longtemps à l'avance.", "Il faut choisir un conjoint de sa région."],
    "nz-bci-11": ["Il faut garder sa maison propre et rangée.", "On ne doit jamais parler de sa famille aux autres.", "Les tâches ménagères se partagent en famille."],
    "nz-bci-12": ["Il faut savoir se reposer pour profiter de la vie.", "Le rire est le meilleur remède à la fatigue.", "Ceux qui travaillent trop oublient de rire."],
    "nz-bci-13": ["Le travail de la terre abîme le corps.", "Il faut se protéger avant un travail difficile.", "Les honneurs reviennent toujours aux plus âgés."],
    "nz-bci-14": ["Il faut finir un travail avant d'en commencer un autre.", "Il faut récolter chaque culture au bon moment.", "Il faut aider son voisin dans ses champs."],
    "nz-bci-15": ["Il faut ranger ses biens précieux en lieu sûr.", "La colère fait perdre ce qu'on a de plus cher.", "Il ne faut pas se disputer devant les enfants."],
    "nz-bci-16": ["Le village est plus sûr que la brousse.", "Il faut faire la paix avec la nature.", "Quand tout va bien au village, on peut partir en voyage."],
    "nz-bci-17": ["Celui qui parle en dernier a toujours raison.", "Il faut attendre que l'autre s'excuse en premier.", "Un conflit se règle par la parole des anciens."],
    "nz-sen-01": ["Une petite douleur peut empêcher de dormir.", "Il faut soigner un problème avant qu'il grandisse.", "Il faut rester vigilant la nuit."],
    "nz-sen-02": ["Les méchants finissent toujours punis.", "Il faut se méfier de ceux qui se vantent.", "La force ne fait pas le chef."],
    "nz-sen-03": ["Chaque plat a sa recette.", "Il faut savoir doser les choses.", "La vérité est parfois difficile à entendre."],
    "nz-sen-04": ["Un enfant doit apprendre à se nourrir seul.", "Les parents doivent d'abord nourrir leurs enfants.", "Il faut partager sa nourriture avec les enfants."],
    "nz-sen-05": ["Un homme travailleur gagne toujours de l'argent.", "Il vaut mieux prêter de l'argent qu'en emprunter.", "Un homme se juge à sa richesse."],
    "nz-sen-06": ["Chacun est seul face à ses problèmes.", "Les petits ont aussi leur place dans la communauté.", "Il faut sortir de chez soi pour se faire des amis."],
    "nz-sen-07": ["Il ne faut pas envier la femme d'un autre.", "La beauté se transmet de mère en fille.", "Il faut écouter les compliments avec méfiance."],
    "nz-sen-08": ["Il faut se lever tôt pour réussir.", "Il faut rentrer chez soi avant la nuit.", "Les enfants finissent toujours par quitter leurs parents."],
    "nz-sen-09": ["Il faut aider les autres comme Dieu nous aide.", "La prière suffit pour obtenir ce qu'on veut.", "Dieu aide d'abord ceux qui sont dans le besoin."],
    "nz-sen-10": ["Les chasseurs doivent respecter les animaux.", "Il faut finir ce qu'on a commencé.", "Celui qui prend des risques doit en payer le prix."],
    "nz-sen-11": ["Les chefs doivent rendre la justice en public.", "Un chef ne doit jamais se disputer.", "Les palabres doivent être réglées par les anciens."],
    "afro-bev-01": ["Il ne faut pas montrer sa tristesse aux autres.", "Les larmes finissent toujours par sécher.", "On ne peut pas être heureux quand on est malade."],
    "afro-bev-02": ["Quand on ne sait pas quoi faire, il faut demander conseil.", "Les mauvaises habitudes commencent dès l'enfance.", "Il faut savoir où l'on va avant de partir."],
    "afro-bev-03": ["Il faut unir ses forces comme les doigts de la main.", "Les aînés doivent passer avant les jeunes.", "Il ne faut pas comparer ses enfants entre eux."],
    "zoko-bev-01": ["Seuls les proches peuvent critiquer un chef.", "Il faut respecter le corps du roi.", "Chaque métier a ses privilèges."],
    "zoko-bev-02": ["Il ne faut pas faire confiance aux rusés.", "Il faut écouter les deux camps avant de juger.", "Les conseils ne servent à rien aux méchants."],
    "cma-q-bci-01": ["Lors des funérailles", "Pour l'initiation des garçons", "Pour rendre la justice"],
    "cma-q-bci-02": ["Au mariage", "À la royauté seulement", "À la protection des récoltes"],
    "cma-q-bci-03": ["Le martelage à froid", "Le filage de l'or", "Le moulage dans le sable"],
    "cma-q-bci-04": ["Le soleil", "L'étoile du matin", "La rivière"],
    "cma-q-bci-05": ["Des ancêtres de la famille", "Des jumeaux", "Un roi et une reine"],
    "cma-q-bci-06": ["Le zaouli", "L'abissa", "Le boloye"],
    "cma-q-bci-07": ["À enrouler le fil filé", "À tasser les fils tissés", "À teindre les bandes de tissu"],
    "cma-q-sen-01": ["Par le fils aîné", "Par le chef du bois sacré", "Par les forgerons"],
    "cma-q-sen-02": ["Abla Pokou", "Mami Wata", "Yaa Asantewaa"],
    "cma-q-sen-03": ["Le Sandogo", "Le Goli", "Le Dipri"],
    "cma-q-sen-04": ["Au meilleur chasseur", "Au meilleur danseur", "Au plus jeune initié"],
    "cma-q-sen-05": ["Un calao", "Un hibou", "Un vautour"],
}

# Seuil de réussite des niveaux : 70 % des proverbes ou questions réussis.
PASS_RATIO = 0.7


def main():
    d = json.loads(CONTENT.read_text(encoding="utf-8"))
    changed = 0
    for a in d["activities"]:
        wrong = WRONG.get(a["id"])
        if not wrong:
            continue
        right = a["answers"][a["correct"]]
        assert right not in wrong and len(set(wrong)) == 3, a["id"]
        a["answers"], a["correct"] = [right, *wrong], 0
        changed += 1
    for level in d["levels"]:
        level["passRatio"] = PASS_RATIO
    missing = [a["id"] for a in d["activities"] if a["id"] not in WRONG]
    CONTENT.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{changed} questions mises à jour ; sans nouvelles réponses : {missing or 'aucune'}")


if __name__ == "__main__":
    main()
