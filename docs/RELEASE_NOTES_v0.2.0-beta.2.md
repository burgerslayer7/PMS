# Pokémon Mount System v0.2.0-beta.2

Cette bêta ajoute la première intégration complète de PotatoVoxel sans reprendre
ni modifier son code. PMS reste propriétaire des montures, déplacements,
vitesses, collisions et transitions ; PotatoVoxel garde le monde voxel, sa
caméra et son pipeline graphique.

## Intégré

- détection dédiée de PotatoVoxel sur Gen1 et Gen2 par le pipeline voxel du
  moteur, sans utiliser son chargeur de modules interne ;
- acteur de monture ordinaire compatible avec son rendu de billboards ;
- vraie altitude visuelle de Flight transmise par `actor:pose()` ;
- dresseur élevé avec la monture, recentré sur le siège et affiché sans les
  rangées de jambes de la pose debout ;
- même fournisseur de sprites en 2D et en voxel : builtin, Wilds sélectionné,
  PokéMMO/True Size ;
- redimensionnement nearest-neighbour des feuilles Wilds classiques sur la
  géométrie Pokédex déjà intégrée à PMS ;
- maintien inchangé des adapters Battle Art et Dramaless ;
- abandon explicite de Gen2-3D-Sprites / Stadium 2. PMS ne le détecte plus et
  ne lui transmet plus d'acteur ;
- maintien du seul adapter Stadium Gen1 en mode maintenance.

## Prérequis PotatoVoxel

Utiliser une version de PotatoVoxel contenant la PR #69 « Fix Sprites bigger
than 16x16 ». La release publique 1.9.6 ne contenait pas encore ce correctif au
moment de l'intégration ; son `main` le contient déjà.

## Validation automatisée

- 82 tests Lua / plus de 1 060 assertions ;
- PMS seul : chargeurs Gen1 et Gen2 validés ;
- PMS + PotatoVoxel : chargeurs conjoints Gen1 et Gen2 validés ;
- 251 feuilles fallback et feuilles Pokédex validées ;
- manifest, périmètre d'intégration et paquet ZIP contrôlés.

PotatoVoxel produit encore sur Gen2 un avertissement amont concernant un
registre de transitions Gen1 sans cible Gen2. Le mod reste chargé et PMS ne
produit aucune erreur ; le smoke test distingue explicitement cet avertissement
d'une régression d'intégration.

## Tests en jeu prioritaires

1. Red ou Yellow + PotatoVoxel : Arcanine, Lapras puis Charizard.
2. Gold puis Crystal + PotatoVoxel : Arcanine, Lapras, Charizard et Ho-Oh.
3. Pour chaque monture : déplacement, sprint, carte voisine, combat, retour de
   combat et démontage.
4. Flight : vérifier la hauteur 3D, le dresseur assis et l'absence de contact
   avec portes/PNJ/terrain.
5. Wilds : changer le style entre follower classique et PokéMMO, puis vérifier
   que la même source est utilisée en 2D et en voxel.
