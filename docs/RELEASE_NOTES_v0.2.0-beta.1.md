# Pokémon Mount System v0.2.0-beta.1

Cette beta regroupe la première grande tranche du plan d'intégration 2D. Elle
reste une réécriture propre : aucun code ni asset Dramatic Sky Ride n'a été
repris. Open Sky est exclu et Stadium reste gelé à son adapter de compatibilité
minimal.

## Intégré

- menu commun **START → MOUNTS** sur Gen1 et Gen2 ;
- réglages Simple/Advanced, rider, ombre, raccourcis, sprint, momentum,
  murets, rencontres aériennes et vitesse verticale ;
- tailles Pokédex, multiplicateur global et overrides par numéro de Dex ;
- accélération, freinage, lancement, virage, boost et vitesse verticale par
  espèce, avec sprint ×2 conservé ;
- politiques centralisées de carte, environnement et interaction ;
- identité stable de la monture, trois dernières sélections persistées et
  reprise après combat seulement au vrai retour free-roam ;
- interception exacte d'un Pokémon Wild Skies par son API publique ;
- restitution de l'autorité follower à Followers EX ou Wilds par
  `syncTrailers`, sans modifier leurs réglages ;
- getter public `currentMount()` et événements takeoff/landed ;
- observation coopérative Battle Art/Dramaless via Voxel Companion API v1,
  sans prise de contrôle de la caméra ni du pipeline monde.
- diagnostic Crystal 251 par ses seuls exports publics (`dexSize`, révision et
  fingerprint), sans dépendance ni appel à son runtime de combat.

## Validation automatisée

- 77 tests Lua / 1 022 assertions ;
- chargeur officiel Gen1 : 3/3 ;
- chargeur officiel Gen2 : 3/3 ;
- 251 feuilles fallback, 120 variantes historiques et 40 feuilles montures
  Pokédex validées ;
- manifest, périmètre d'intégration et contenu du ZIP contrôlés.

## À valider en jeu

Le harnais ne remplace pas un test avec ROM. Tester en priorité Arcanine,
Lapras, Charizard et Ho-Oh sur Gold, Red, Yellow et Crystal : déplacement,
portes/seams, combat, save/load, changement direct Ground/Surf/Flight et retour
du follower. Les détails sont dans `docs/TESTING.md`.

## Limites volontaires

- aucun développement Stadium supplémentaire ;
- aucun module, asset ou projet Open Sky ;
- pas encore de mouvement voxel continu relatif caméra : l'API Voxel
  Companion v1 fournit l'orientation et le rendu, pas une commande publique de
  déplacement du joueur ;
- validation ROM-backed des six jeux encore nécessaire avant une stable.
