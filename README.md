# Land.Tree Survey

**Land.Tree Survey** est une application mobile Flutter conçue pour la collecte
hors ligne et géoréférencée des données d’inventaire des arbres dans les
systèmes agroforestiers et les paysages de savane.

## Fonctionnalités principales

- création et gestion de placettes ;
- sélection du pays du projet ;
- relevé simple : identifiant, espèce, GPS et photographie ;
- inventaire dendrométrique : diamètre, hauteur, houppier et multi-troncs ;
- génération et incrémentation des identifiants par placette ;
- acquisition GPS avec possibilité de saisie manuelle ;
- stockage local hors connexion avec Hive ;
- synchronisation avec Supabase lorsque le réseau est disponible ;
- modification des données enregistrées ;
- export en CSV et Excel avec trois ensembles de données : placettes,
  inventaires dendrométriques et relevés simples.

## Installation pour le développement

Prérequis : Flutter stable et SDK Android.

```bash
flutter pub get
flutter run --dart-define-from-file=supabase.json
```

Créez `supabase.json` à partir de `supabase.example.json`. N’utilisez jamais une
clé `service_role` dans l’application.

## Construction de l’APK

```bash
flutter build apk --release --dart-define-from-file=supabase.json
```

## Confidentialité des données

Le dépôt public ne doit contenir aucune donnée personnelle, photographie de
terrain non autorisée, coordonnée sensible ou clé privée. La personne qui
déploie l’application est responsable de la configuration des politiques de
sécurité Supabase et de la conformité de la collecte.

## Citation

Consultez `CITATION.cff`. Le DOI Zenodo sera ajouté après la publication de la
première release scientifique.

## Encadrement scientifique

Consultez `ACKNOWLEDGEMENTS.md` pour la liste complète des institutions et des
encadrants scientifiques.

## Licence

La licence doit être validée avec le CSE, le projet GALILEO et les institutions
concernées avant la publication publique. Consultez `LICENCE_A_VALIDER.md`.
