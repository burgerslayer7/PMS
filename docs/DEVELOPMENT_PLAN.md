# Plan de développement et d'intégration

## 1. Périmètre de l'audit

Ce plan compare Pokémon Mount System (PMS) `0.2.0-beta.2` avec
les fonctionnalités publiques et observables du dépôt Dramatic Sky Ride.

Références Sky Ride relues :

- branche publique `main` au commit `759f521` ;
- dernière release publiée `v0.2.18`, tag `723c29b` ;
- README, changelogs, notes de release, documentation et backlog publics ;
- historique fonctionnel documenté des versions `0.1.0` à `0.2.18`.

La release Sky Ride `0.2.18` restaure volontairement le runtime pré-sandbox
de `0.2.11`. Les versions `0.2.12` à `0.2.17` ont aussi été relues pour
identifier les expériences retirées, notamment Open Sky, le fallback PokéPC
embarqué et les bridges sandbox. Une fonctionnalité retirée n'est pas traitée
comme une exigence de parité automatique. Open Sky est désormais explicitement
exclu du périmètre PMS.

### Frontière clean-room

Aucun fichier source Lua de Dramatic Sky Ride n'a été lu, copié, adapté ou
transposé pour cet audit. Sky Ride ne sert que de référence produit. Chaque
fonction ci-dessous doit être conçue à neuf à partir :

- de l'API publique Gen1Recomp++ moderne ;
- des contrats publics des providers ;
- de l'architecture et des tests propres à PMS ;
- des retours de tests réels de PMS.

Les assets, tables, algorithmes, structures et hacks internes de Sky Ride ne
doivent jamais être importés dans PMS.

La branche expérimentale Sky Ride `release/0.3.0-clean-rewrite` est également
exclue comme source de conception ou de code. PMS conserve sa propre
architecture. Le retour au droit `filesystem` de Sky Ride `0.2.18` ne doit pas
être reproduit : toutes les intégrations PMS restent sandbox-safe.

## 2. Conclusion de l'audit

PMS possède déjà un meilleur socle moderne et autonome que la stable actuelle
de Sky Ride : fallback 2D de 251 espèces, API v2, sandbox, machine d'état,
sélection de providers avec repli par espèce et fonctionnement natif Gen1/Gen2.

L'écart principal n'est plus le nombre de montures. Il se situe dans quatre
domaines :

1. durcissement du cycle combat/carte/sauvegarde et validation réelle des six
   jeux ;
2. personnalité du déplacement, effets et interface utilisateur ;
3. intégrations publiques complètes avec Wild Skies, followers et personnages
   alternatifs ;
4. vrai déplacement voxel relatif à la caméra, sans voler le renderer ni sa
   caméra.

Deux décisions de périmètre sont fermes :

- **Stadium est gelé.** L'adapter minimal actuel `tag`/`untag` reste disponible
  sur Gen1 pour compatibilité et repli, mais PMS n'ajoutera pas de motion transforms,
  d'import/cache de modèles, de selles, d'animations ou de nouveau renderer
  Stadium. Seules les corrections de régression et de cleanup sont admises.
- **Gen2-3D-Sprites est abandonné.** Aucun probe, tag, bridge de mouvement ou
  adaptation de PMS ne doit être ajouté pour ce runtime.
- **Open Sky est abandonné.** PMS ne développera ni navigation régionale, ni
  carte aérienne, ni landmarks, ni module ou assets Open Sky. Ce sujet ne fait
  plus partie de la roadmap.

## 3. Matrice d'écarts

| Domaine | État PMS 0.2.0-beta.2 | Travail restant |
| --- | --- | --- |
| Ground / Surf / Flight natifs | Présent | Stabiliser sur les six jeux réels |
| Catalogue | 40 espèces, 42 profils de mode | Aucun élargissement nécessaire pour la parité |
| Assets autonomes | 251 feuilles PokéPC embarquées et validées | Garder ce fallback obligatoire dans chaque build |
| Tailles Pokédex | Présent pour le builtin ; partiel pour l'art externe | Overrides utilisateur, trim et calibration par provider |
| Vitesses par espèce | Présent, de x0,8 à x2, sprint x2 | Ajouter accélération, freinage, inertie et maniabilité |
| Ground Ride | Jouable, collisions et murets bidirectionnels | Gallop, endurance, effets et politique intérieur/cave |
| Visible Surf | Jouable, monture native masquée | Réglages par espèce, sillage, cris et Suicune amphibie |
| Flight 2D | Haute altitude, airspace sans obstacles au sol | Validation complète, mouvement plus fluide et feedback |
| Changement de mode | Ground/Flight et Flight/Surf directs | Généraliser la transaction et tester toutes les erreurs |
| Connexions de cartes | Présent en Gen1/Gen2 | Matrice portes, caves, stairs, téléports et scripts |
| Combat | Suspension/reprise de base | Faint, perte, évolution, retrait, ordre d'équipe et délai free-roam |
| Sauvegarde | Session active persistée | Persister séparément les trois dernières sélections valides |
| Progression | Move + badge Surf/Fly | Politiques séparées, story/discovery gates configurables |
| Interactions | Interactions du sol neutralisées en vol | Politique sûre pour PC, objets, scripts et field moves |
| Environnements Ground | Pas de politique complète | Adapter Gen1/Gen2, intérieur, caves et auto-dismount configurable |
| Rider 2D | Crop assis et lift par taille | Profils directionnels/provider, personnages alternatifs |
| Menu | Action `MOUNT` dans l'équipe | Entrée START `MOUNTS`, états, prérequis et monture courante |
| Réglages | 7 réglages plats | Simple/Advanced, groupes, effets, contrôles et tailles |
| HUD / effets | Debug HUD et ombre 2D | Altitude, gallop, landing cue, poussière, cris et vibration |
| Musique de vol | Absent | Provider audio facultatif, sans scan de fichiers tiers |
| Wilds of Kanto | Art sélectionné et masquage du doublon | Remplacer le bridge combat privé par un contrat public |
| Wild Skies | Marqueur `freeFlying` uniquement | Interception `takeFlyer`, événements et sprite source publics |
| Followers EX / PokéPC runtime | Masquage générique seulement | Adapters de sélection/synchronisation publics et testés |
| Crystal 251 dans Gen1 | Résolution via les données fusionnées | Tests d'identité, formes et progression Gen2 injectée |
| Voxel billboard | Battle Art/Dramaless + PotatoVoxel Gen1/Gen2, altitude et art partagé | Orientation caméra, 1ST/3RD et mouvement libre |
| Stadium Gen1 | `tag`/`untag` de l'acteur | Gelé : maintenance anti-régression et fallback seulement |
| Gen2-3D-Sprites | Non supporté | Abandonné : aucune adaptation prévue |
| Hot reload | Cleanup de base | Tests répétés avec providers qui apparaissent/disparaissent |
| Open Sky | Hors périmètre | Abandonné : aucune implémentation prévue |

## 4. Principes d'implémentation

### 4.1 Gameplay unique

PMS reste le seul propriétaire du mode monté, du Pokémon choisi, de la
progression, du mouvement et du cycle combat/carte. Un provider ne doit jamais
devenir un second moteur de vol.

### 4.2 Détection par capacités

Les identifiants et versions servent à la matrice de test, jamais comme preuve
unique de compatibilité. Chaque adapter vérifie les fonctions et capacités
qu'il consomme, puis se replie sans casser la session.

### 4.3 Deux drivers de mouvement

- `TileStepDriver` : Gen1/Gen2 natif 2D, raccords de cartes et règles moteur ;
- `FreeMoveDriver` : uniquement lorsqu'un renderer expose une base caméra et
  une commande de déplacement publiques et réversibles.

`FlightController` conserve l'altitude et les règles de gameplay. Il ne doit
pas contenir de code Battle Art, Dramaless ou caméra.

### 4.4 Vol haut par défaut

Le comportement validé par les tests utilisateur reste la règle : en vol
stable, les bâtiments, portes, PNJ, herbes et Pokémon au sol n'interagissent
pas avec le joueur. Une éventuelle collision voxel de basse altitude devra
être une option distincte, désactivée par défaut et soumise à une décision
produit avant développement.

### 4.5 Dégradation locale

Une absence de modèle, sprite ou API ne doit invalider que le provider pour la
monture concernée. La chaîne existante reste : Stadium minimal → voxel
billboard → 2D externe → builtin. La présence de Stadium dans cette chaîne ne
constitue pas un jalon de développement : seul son repli sûr est maintenu.

## 5. Plan par jalons

### M0 — Geler la référence et les contrats

Objectif : empêcher une dérive du périmètre avant de reprendre les features.

**Statut : terminé.** Le contrat machine-readable et son gate CI/package sont
actifs depuis `33e3a4f`.

- conserver ce document et la matrice d'écarts dans le dépôt ;
- maintenir `config/integration_scope.json`, l'inventaire machine-readable des
  intégrations actives, gelées et exclues ;
- enregistrer les versions testées, sans leur donner valeur de preuve ;
- exécuter `tools/validate_scope.py` en CI pour interdire toute dépendance ou
  asset Sky Ride, tout module Open Sky et toute extension Stadium ;
- documenter les décisions produit nécessitant validation.

Sortie : aucun changement gameplay, tests actuels toujours verts.

### M1 — Stabilisation native 2D

Objectif : obtenir une base irréprochable avant le voxel.

**Statut : en cours.** La première tranche sécurise déjà la reprise de l'acteur
visible, l'ownership follower et `map.reloaded` avec un retry borné.

- finir les retours de rendu `0.1.6` sur Red/Yellow/Gold/Crystal ;
- valider les quatre directions et toutes les tailles builtin ;
- vérifier portes, caves, stairs, téléports, seams et scripted warps ;
- vérifier battle, perte, save/load et changement de carte dans les trois modes ;
- éliminer les sprites orphelins, doubles riders et followers masqués à tort ;
- ajouter des cartes de test reproductibles et un snapshot debug exportable.

Ordre de validation : Gold → Red → Yellow → Crystal → Blue → Silver.

Sortie : Arcanine, Lapras, Charizard et Ho-Oh passent leurs cartes courtes en
2D builtin, sans autre mod.

### M2 — Lifecycle, identité et sécurité

Objectif : rendre chaque transition transactionnelle et récupérable.

**Statut : terminé côté automatisable.** `MountIdentity`, la reprise free-roam
après combat, les trois sélections persistantes et les politiques de carte,
environnement et interaction sont implémentés. La matrice ROM reste dans M1.

- créer `MountIdentity` pour suivre slot, espèce, forme, shiny et fingerprint ;
- revalider après combat : vivant, présent, move, badge et mode compatible ;
- attendre le vrai retour free-roam avant remount ;
- persister `lastGround`, `lastSurf` et `lastFlight` indépendamment ;
- centraliser `MapTransitionPolicy`, `EnvironmentPolicy` et
  `InteractionPolicy` ;
- restaurer proprement après perte, évolution, changement d'équipe et reload ;
- tester rollback atomique lorsqu'un changement de mode échoue.

Sortie : aucun faux état monté après combat, warp, reload ou erreur provider.

### M3 — Mobilité et personnalité des espèces

Objectif : donner un comportement réellement différent à chaque monture sans
coupler le gameplay au renderer.

**Statut : en cours.** Les profils bornés de lancement, accélération, freinage,
virage, boost et vitesse verticale sont consommés par les trois contrôleurs.
Les effets, l'endurance et Suicune amphibie restent à faire.

- étendre les profils avec accélération, freinage, boost, turn rate et inertie ;
- ajouter gallop/endurance Ground et boost Flight ;
- rendre la vitesse verticale configurable par espèce ;
- implémenter Suicune amphibie avec transition Ground/Surf continue ;
- conserver le sprint x2 comme multiplicateur lisible ;
- ajouter des transforms 2D légers : bob, lean, pitch, bank et buoyancy ;
- ajouter cris, poussière/sillage, atterrissage, rumble et HUD minimal.

En 2D native, la personnalité améliore la cadence et la présentation mais
reste alignée sur la grille moteur. Le déplacement analogique continu attend
le driver voxel de M6.

Sortie : profils de données complets et tests déterministes pour les 42 modes.

### M4 — Menu et réglages

Objectif : rendre le mod utilisable sans parcourir l'équipe pour chaque choix.

**Statut : en cours.** START → MOUNTS, les vues Simple/Advanced, l'échelle
globale et les overrides Dex sont actifs sur l'API publique commune Gen1/Gen2.
Les hints contextuels et un éditeur visuel d'overrides restent à faire.

- ajouter une entrée START `MOUNTS` via `ui.start_menu.items` ;
- grouper Ground, Surf, Flight, Dismount et Options ;
- afficher sélection, état KO et prérequis manquants ;
- ajouter vues Simple/Advanced avec `visible_if` ;
- ajouter Show Rider, shortcuts, sprint/boost, altitude, ombre, effets,
  Visible Surf, ledges, followers, air encounters et remount ;
- ajouter taille globale et overrides par espèce sans casser le sizing Pokédex ;
- ajouter hints contextuels et erreurs courtes ;
- conserver toutes les clés persistantes lors d'un changement de vue.

Sortie : menu identique fonctionnellement en Gen1 et Gen2, clavier et manette.

### M5 — Écosystème 2D par APIs publiques

Objectif : supprimer les bridges fragiles avant le voxel.

**Statut : en cours.** Wild Skies fournit maintenant les rencontres exactes,
les événements PMS sont publics et Followers EX/Wilds récupèrent l'autorité de
trail par `syncTrailers`. Wilds 1.12 n'expose toujours pas de guard public de
contact au sol : le bridge privé existant reste confiné en attendant ce seam.

#### Wilds of Kanto 2.2.x

- conserver `resolveFollowerSprite` et les changements de style à chaud ;
- utiliser la synchronisation follower publique quand elle existe ;
- proposer/consommer un guard public de contact en vol ;
- retirer l'enveloppement actuel de `logic._startBattle` dès que ce guard est
  disponible ;
- tester builtin, Pokédex, HGSS, PokeMMO, PMD et fallback par espèce.

#### Wild Skies 1.12.x

- conserver les commandes publiques PMS existantes et ajouter un getter
  `currentMount()` ainsi que des événements PMS takeoff/landed ;
- utiliser `flyerAt`/`takeFlyer` pour l'interception de l'oiseau exact ;
- faire correspondre distance verticale et altitude PMS ;
- enregistrer le fallback volant PMS via `registerSpriteSource` seulement si
  Wilds n'est pas déjà l'autorité ;
- laisser Wild Skies propriétaire des spawns, flocks, cooldowns et combats.

#### Followers et personnages

- adapter PokéPC Followers 0.8.x et Followers EX 1.0.x par exports publics ;
- ajouter un provider de rider pour OTF Player Switcher ou équivalent ;
- garantir qu'un seul follower correspondant à la monture est masqué ;
- détecter et refuser deux moteurs de vol actifs, notamment Free Fly ou le
  `FlyYourPokemon` de certains packs Stadium Gen2.

#### Audio facultatif

- définir un petit `FlightAudioProvider` public ;
- accepter des pistes déclarées par un provider activé, jamais en parcourant
  le dossier d'un autre mod ;
- laisser combats, jingles et musique de carte prioritaires ;
- restaurer la musique correcte après landing, Surf, battle et map change.

Sortie : matrice PMS seul, puis PMS + chaque intégration séparée.

### M6 — Voxel et mouvement relatif à la caméra

Objectif : offrir un vrai vol libre sans voler la caméra au renderer.

- introduire `MovementOrientationProvider` et `FreeMoveDriver` ;
- demander une capacité publique donnant base caméra, mode et commande de
  mouvement, ou faire évoluer Voxel Companion sans utiliser d'internals ;
- intégrer d'abord Battle Art 1.9.x puis Dramaless 2.0.x ;
- gérer 1ST : rider/mount cachés ou vue immersive négociée ;
- gérer 3RD : rider visible, offsets dédiés et mouvement écran-relatif ;
- maintenir altitude, map seams, combat et transitions dans PMS ;
- profiler les appels par frame et interdire les allocations/scans lourds ;
- conserver l'adapter de présentation PotatoVoxel déjà intégré et étendre le
  mouvement relatif uniquement s'il expose un jour une commande publique ;
- étendre ensuite à Terrarium et Voxel Ascendant uniquement s'ils exposent une
  capacité compatible.

Blocage connu : Voxel Companion v1 permet l'observation, les phases de rendu
et un delta caméra, mais ne constitue pas encore à lui seul une commande
publique complète de déplacement libre du joueur. Ce jalon peut nécessiter une
petite évolution coordonnée du contrat provider.

Sortie : Charizard Gen1 et Ho-Oh Gen2 se déplacent continûment vers l'avant de
l'écran en 1ST/3RD, sans modification globale de caméra par PMS.

### M7 — Hardening et release stable

Objectif : terminer par une matrice réelle, pas seulement par des mocks Lua.

- six jeux : Red, Blue, Yellow, Gold, Silver, Crystal ;
- trois modes et toutes les transitions ;
- clavier, Xbox, PlayStation et contrôles portables ;
- builtin, Wilds, Followers EX, Wild Skies, Battle Art et Dramaless ;
- smoke test du seul adapter Stadium existant, sans nouvelle fonctionnalité ;
- combinaisons prioritaires et providers absents/malades ;
- save/load, battle, evolution, blackout, map reload et hot reload répété ;
- profiling et seuils d'absence de fuite d'acteur/provider ;
- ZIP extrait rechargé dans les deux modkits, checksum et release GitHub.

Sortie : aucun nouveau système pendant ce jalon, uniquement correction,
documentation et stabilisation.

## 6. Ordre d'intégration des providers

| Ordre | Projet de référence | Rôle PMS | Condition de passage |
| ---: | --- | --- | --- |
| 1 | PMS builtin | Référence autonome 2D | Toujours disponible |
| 2 | Wilds of Kanto 2.2.x | Art 2D + follower | API publique uniquement |
| 3 | Wild Skies 1.12.x | Écosystème aérien | Interception de l'entité exacte |
| 4 | PokéPC 0.8.x / Followers EX 1.0.x | Followers optionnels | Aucun état persistant modifié |
| 5 | Battle Art 1.9.x | Premier host voxel | Caméra reste host-owned |
| 6 | Dramaless 2.0.x | Deuxième host voxel | Même contrat, adapter minimal |
| 7 | PotatoVoxel 1.9.6 + PR #69 | Host voxel Gen1/Gen2 | Adapter pipeline/pose, aucun internal |
| 8 | Crystal 251 0.11.x | Gen2 injectée dans Gen1 | Toujours facultatif |
| 9 | Autres voxel hosts | Compatibilité secondaire | Capability contract disponible |

Les numéros de version ci-dessus décrivent les références auditées, pas des
checks codés en dur.

Stadium n'apparaît pas dans cet ordre d'intégration : son adapter Gen1 actuel
est conservé en maintenance uniquement. Gen2-3D-Sprites et Open Sky en sont
absents parce qu'ils sont entièrement hors périmètre.

## 7. Gates de décision produit

Demander une confirmation avant de :

- activer par défaut des story/discovery gates supplémentaires ;
- démonter automatiquement dans de nouveaux types de cartes ;
- ajouter une collision voxel basse altitude qui contredirait le vol libre
  haut actuellement demandé ;
- changer les raccourcis actuels ou le multiplicateur de sprint ;
- ajouter/retirer des espèces du catalogue ;
- rendre un autre mod obligatoire.

Open Sky n'est pas un gate futur mais une fonctionnalité abandonnée. Relancer
un développement Stadium ou réintroduire Open Sky demanderait une nouvelle
décision de produit et un nouveau périmètre, pas une simple étape de ce plan.

## 8. Prochaine tranche recommandée

M2 est terminé côté automatisable et M3/M4/M5 possèdent désormais une première
tranche fonctionnelle. Les tests utilisateur restent surtout concentrés sur
Pokémon Gold en 2D. La priorité suivante est donc M1 : valider et durcir le
même ZIP sur Red, Yellow et Crystal, puis Blue et Silver, avant d'étendre le
voxel.

Après cette matrice ROM, reprendre M3 pour les effets et Suicune amphibie, puis
M5 pour remplacer le dernier guard Wilds privé dès qu'un export public existe.
M6 reste bloqué pour le déplacement libre caméra-relatif tant que Voxel
Companion n'expose pas de commande publique et réversible de mouvement.
