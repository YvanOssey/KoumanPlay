-- Généré par tool/generate_seed.dart, ne pas modifier à la main.

insert into public.languages (id, name, "group", region, color, sort) values
  ('baoule', 'Baoulé', 'Akan', 'Centre · Bouaké, Yamoussoukro', '#D4A017', 0),
  ('bete', 'Bété', 'Krou', 'Centre-Ouest · Gagnoa, Daloa', '#16A34A', 1),
  ('dioula', 'Dioula', 'Mandé', 'Nord et tout le pays · langue des marchés', '#EA580C', 2),
  ('senoufo', 'Sénoufo', 'Gour', 'Nord · Korhogo, Ferkessédougou', '#2563EB', 3)
on conflict (id) do update set name = excluded.name, "group" = excluded."group", region = excluded.region, color = excluded.color, sort = excluded.sort;

insert into public.levels (id, language_id, category_id, sort, title, kind, pass_ratio) values
  ('baoule-6', 'baoule', null, 1, 'La force du groupe', 'proverbes', 0.6),
  ('baoule-7', 'baoule', null, 2, 'La sagesse des anciens', 'proverbes', 0.6),
  ('baoule-8', 'baoule', null, 3, 'Patience et parole', 'proverbes', 0.6),
  ('baoule-1', 'baoule', null, 4, 'Salutations', 'mots', 0.6),
  ('baoule-2', 'baoule', null, 5, 'La famille', 'mots', 0.6),
  ('baoule-3', 'baoule', null, 6, 'Les nombres', 'mots', 0.6),
  ('baoule-4', 'baoule', null, 7, 'Se présenter', 'phrases', 0.6),
  ('baoule-5', 'baoule', null, 8, 'Au quotidien', 'phrases', 0.6),
  ('bete-6', 'bete', null, 1, 'Proverbes', 'proverbes', 0.6),
  ('bete-1', 'bete', null, 2, 'Salutations', 'mots', 0.6),
  ('bete-2', 'bete', null, 3, 'La famille', 'mots', 0.6),
  ('bete-3', 'bete', null, 4, 'Les nombres', 'mots', 0.6),
  ('bete-4', 'bete', null, 5, 'Se présenter', 'phrases', 0.6),
  ('bete-5', 'bete', null, 6, 'Au quotidien', 'phrases', 0.6),
  ('dioula-6', 'dioula', null, 1, 'Proverbes', 'proverbes', 0.6),
  ('dioula-1', 'dioula', null, 2, 'Salutations', 'mots', 0.6),
  ('dioula-2', 'dioula', null, 3, 'La famille', 'mots', 0.6),
  ('dioula-3', 'dioula', null, 4, 'Les nombres', 'mots', 0.6),
  ('dioula-4', 'dioula', null, 5, 'Se présenter', 'phrases', 0.6),
  ('dioula-5', 'dioula', null, 6, 'Au quotidien', 'phrases', 0.6),
  ('senoufo-6', 'senoufo', null, 1, 'Proverbes', 'proverbes', 0.6),
  ('senoufo-1', 'senoufo', null, 2, 'Salutations', 'mots', 0.6),
  ('senoufo-2', 'senoufo', null, 3, 'La famille', 'mots', 0.6),
  ('senoufo-3', 'senoufo', null, 4, 'Les nombres', 'mots', 0.6),
  ('senoufo-4', 'senoufo', null, 5, 'Se présenter', 'phrases', 0.6),
  ('senoufo-5', 'senoufo', null, 6, 'Au quotidien', 'phrases', 0.6)
on conflict (id) do update set language_id = excluded.language_id, category_id = excluded.category_id, sort = excluded.sort, title = excluded.title, kind = excluded.kind, pass_ratio = excluded.pass_ratio;

insert into public.activities (id, level_id, proverb, original, language, question, answers, correct, explanation, audio, xp, validated, sort) values
  ('prov-1-01', 'baoule-6', 'On ne balaie pas la cour avec une seule main.', null, null, 'Que veut dire ce proverbe ?', '["On a besoin des autres pour réussir.","Il faut travailler très tôt le matin.","La cour doit toujours rester propre.","Il ne faut jamais se reposer."]'::jsonb, 0, 'La coopération rend les tâches plus faciles et plus solides.', null, 20, false, 0),
  ('prov-1-02', 'baoule-6', 'Une seule tête ne tient pas conseil.', null, null, 'Quelle idée se cache derrière ce proverbe ?', '["Le chef doit décider seul.","Les décisions importantes se prennent à plusieurs.","Il faut parler le moins possible.","Les réunions sont une perte de temps."]'::jsonb, 1, 'Chez les Akan, le conseil réunit plusieurs voix : une décision partagée est plus sage.', null, 20, false, 1),
  ('prov-1-03', 'baoule-6', 'L''arbre seul face au vent se brise.', null, null, 'Que nous apprend ce proverbe ?', '["Il faut couper les arbres isolés.","Le vent est plus fort que tout.","Isolé, on est plus fragile face aux difficultés.","Il faut planter des arbres partout."]'::jsonb, 2, 'Une forêt résiste au vent, un arbre seul casse : la communauté protège.', null, 20, false, 2),
  ('prov-1-04', 'baoule-6', 'Si tu veux aller vite, marche seul ; si tu veux aller loin, marchons ensemble.', null, null, 'Quel conseil donne ce proverbe ?', '["Il faut toujours marcher vite.","Les longs voyages sont dangereux.","Seul on va vite, mais ensemble on va plus loin.","Il vaut mieux voyager seul."]'::jsonb, 2, 'Les grands projets demandent du temps et des partenaires.', null, 20, false, 3),
  ('prov-1-05', 'baoule-6', 'Celui qui demande son chemin ne se perd pas.', null, null, 'Quelle idée se rapproche de ce proverbe ?', '["Demander de l''aide est une force.","Il ne faut jamais voyager.","Les chemins sont toujours courts.","On doit tout savoir seul."]'::jsonb, 0, 'Poser une question permet d''avancer avec plus de confiance.', null, 20, false, 4),
  ('prov-2-01', 'baoule-7', 'Ce qu''un vieillard voit assis, un jeune ne le voit pas debout.', null, null, 'Que veut dire ce proverbe ?', '["Les jeunes ont une meilleure vue.","L''expérience des aînés permet de voir plus loin.","Il faut rester assis pour réfléchir.","Les vieillards ne se lèvent plus."]'::jsonb, 1, 'Les années d''expérience donnent un regard que la jeunesse n''a pas encore.', null, 20, false, 5),
  ('prov-2-02', 'baoule-7', 'Personne ne montre Dieu à un enfant.', null, null, 'Quel est le sens de ce proverbe ?', '["Les enfants ne doivent pas poser de questions.","Certaines vérités sont évidentes, même pour les plus jeunes.","Il faut tout apprendre aux enfants.","Les enfants ne comprennent rien."]'::jsonb, 1, 'Certaines choses n''ont pas besoin d''être enseignées : chacun les perçoit naturellement.', null, 20, false, 6),
  ('prov-2-03', 'baoule-7', 'Il n''est pas interdit de revenir chercher ce que l''on a oublié.', null, null, 'Ce proverbe est à l''origine du symbole Sankofa. Que signifie-t-il ?', '["Il ne faut jamais regarder en arrière.","On peut retourner à ses racines pour mieux avancer.","Oublier est une faute grave.","Il faut tout noter pour ne rien oublier."]'::jsonb, 1, 'Sankofa, l''oiseau qui regarde en arrière : connaître son passé aide à construire l''avenir.', null, 20, false, 7),
  ('prov-2-04', 'baoule-7', 'C''est dans les vieilles marmites qu''on fait les bonnes sauces.', null, null, 'Que veut dire cette expression ?', '["Il faut garder ses vieux ustensiles.","L''expérience et l''ancienneté donnent les meilleurs résultats.","Les nouvelles marmites sont dangereuses.","Il faut cuisiner longtemps."]'::jsonb, 1, 'On reconnaît la valeur de ce qui a fait ses preuves avec le temps.', null, 20, false, 8),
  ('prov-2-05', 'baoule-7', 'Quand un vieillard meurt, c''est une bibliothèque qui brûle.', null, null, 'Que veut transmettre cette phrase ?', '["Les bibliothèques sont fragiles.","Les savoirs des aînés disparaissent s''ils ne sont pas transmis.","Les vieillards lisent beaucoup.","Il faut construire plus de bibliothèques."]'::jsonb, 1, 'Cette phrase, popularisée par Amadou Hampâté Bâ, rappelle l''urgence de transmettre les savoirs oraux.', null, 20, false, 9),
  ('prov-3-01', 'baoule-8', 'La parole est comme l''eau versée : on ne peut plus la ramasser.', null, null, 'Quel conseil donne ce proverbe ?', '["Il faut boire beaucoup d''eau.","Il faut réfléchir avant de parler.","Il ne faut jamais parler.","L''eau est précieuse."]'::jsonb, 1, 'Une parole dite ne se reprend pas : on mesure ses mots.', null, 20, false, 10),
  ('prov-3-02', 'baoule-8', 'Un tronc d''arbre a beau séjourner dans l''eau, il ne deviendra jamais crocodile.', null, null, 'Que veut dire ce proverbe ?', '["On ne change pas sa nature profonde.","Les crocodiles vivent dans les arbres.","Il ne faut pas jeter de bois dans l''eau.","Avec le temps, tout se transforme."]'::jsonb, 0, 'On peut imiter les autres, mais on reste qui on est.', null, 20, false, 11),
  ('prov-3-03', 'baoule-8', 'Quand tu ne sais pas où tu vas, regarde d''où tu viens.', null, null, 'Quelle idée exprime ce proverbe ?', '["Il faut toujours rentrer chez soi.","Connaître ses origines aide à trouver sa voie.","Les voyages sont inutiles.","Il faut avoir une carte."]'::jsonb, 1, 'Nos racines sont une boussole quand l''avenir est flou.', null, 20, false, 12),
  ('prov-3-04', 'baoule-8', 'La patience est un arbre aux racines amères, mais aux fruits très doux.', null, null, 'Que nous apprend ce proverbe ?', '["Les fruits sont meilleurs que les racines.","Attendre est difficile, mais la récompense en vaut la peine.","Il ne faut pas manger de racines.","Il faut planter des arbres fruitiers."]'::jsonb, 1, 'La patience coûte sur le moment, mais elle porte ses fruits.', null, 20, false, 13),
  ('prov-3-05', 'baoule-8', 'Le mensonge donne des fleurs, mais pas de fruits.', null, null, 'Quel est le sens de ce proverbe ?', '["Les fleurs sont plus belles que les fruits.","Le mensonge peut sembler réussir, mais il ne mène à rien de durable.","Il faut planter des fleurs.","Mentir est parfois utile."]'::jsonb, 1, 'Un mensonge peut briller un moment, il ne construit rien de solide.', null, 20, false, 14)
on conflict (id) do update set level_id = excluded.level_id, proverb = excluded.proverb, original = excluded.original, language = excluded.language, question = excluded.question, answers = excluded.answers, correct = excluded.correct, explanation = excluded.explanation, audio = excluded.audio, xp = excluded.xp, validated = excluded.validated, sort = excluded.sort;

insert into public.challenges (id, role, unlock_after_level, title, description, reward_xp, duration_min, difficulty, steps, note_prompt, sort) values
  ('jeune-proverbe-famille', 'jeune', 'baoule-6', 'Le proverbe de ma famille', 'Demande à un aîné de ton entourage un proverbe qu''on disait dans sa famille.', 100, 15, 'Facile', '["Choisis un aîné de ton entourage : grand-parent, oncle, tante, voisin…","Demande-lui un proverbe qu''on disait dans sa famille.","Demande-lui ce qu''il veut dire et quand on l''utilise.","Note le proverbe et son sens ci-dessous."]'::jsonb, 'Le proverbe et son sens', 0),
  ('jeune-jeux-autrefois', 'jeune', 'baoule-7', 'Les jeux d''autrefois', 'Découvre à quoi jouait un aîné quand il avait ton âge.', 100, 20, 'Facile', '["Demande à un aîné à quoi il jouait quand il était enfant.","Fais-toi expliquer les règles du jeu.","Essayez d''y jouer ensemble, même quelques minutes.","Note le nom du jeu et ce que tu as appris."]'::jsonb, 'Le nom du jeu et ses règles', 1),
  ('jeune-geste-numerique', 'jeune', 'baoule-8', 'Un geste numérique', 'Apprends à un aîné à envoyer un message vocal sur son téléphone.', 120, 15, 'Moyen', '["Assieds-toi avec un aîné et son téléphone.","Montre-lui comment enregistrer et envoyer un message vocal.","Laisse-le essayer seul pendant que tu l''encourages.","Demande-lui de t''envoyer un proverbe en vocal."]'::jsonb, 'Comment ça s''est passé ?', 2),
  ('senior-transmets-proverbe', 'senior', 'baoule-6', 'Transmets un proverbe', 'Partage avec un jeune un proverbe qu''on disait dans votre famille.', 100, 15, 'Facile', '["Choisis un jeune de ton entourage : petit-enfant, neveu, voisin…","Partage-lui un proverbe de ta famille.","Explique-lui ce qu''il veut dire et quand on l''utilise.","Note le proverbe et son sens ci-dessous."]'::jsonb, 'Le proverbe et son sens', 3),
  ('senior-raconte-jeu', 'senior', 'baoule-7', 'Raconte un jeu d''autrefois', 'Apprends à un jeune un jeu de ton enfance.', 100, 20, 'Facile', '["Pense à un jeu de ton enfance.","Explique ses règles à un jeune.","Jouez-y ensemble quelques minutes.","Note le nom du jeu et ses règles."]'::jsonb, 'Le nom du jeu et ses règles', 4),
  ('senior-geste-numerique', 'senior', 'baoule-8', 'Apprends un geste numérique', 'Demande à un jeune de t''apprendre à envoyer un message vocal.', 120, 15, 'Moyen', '["Demande à un jeune de t''aider avec ton téléphone.","Fais-toi montrer comment enregistrer un message vocal.","Essaie seul, il est là pour t''aider.","Envoie-lui un proverbe en vocal."]'::jsonb, 'Comment ça s''est passé ?', 5)
on conflict (id) do update set role = excluded.role, unlock_after_level = excluded.unlock_after_level, title = excluded.title, description = excluded.description, reward_xp = excluded.reward_xp, duration_min = excluded.duration_min, difficulty = excluded.difficulty, steps = excluded.steps, note_prompt = excluded.note_prompt, sort = excluded.sort;

delete from public.levels where id not in ('baoule-6', 'baoule-7', 'baoule-8', 'baoule-1', 'baoule-2', 'baoule-3', 'baoule-4', 'baoule-5', 'bete-6', 'bete-1', 'bete-2', 'bete-3', 'bete-4', 'bete-5', 'dioula-6', 'dioula-1', 'dioula-2', 'dioula-3', 'dioula-4', 'dioula-5', 'senoufo-6', 'senoufo-1', 'senoufo-2', 'senoufo-3', 'senoufo-4', 'senoufo-5');
