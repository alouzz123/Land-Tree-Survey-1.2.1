# Structure recommandée du dépôt Land.Tree Survey

## Fichiers obligatoires ou fortement recommandés

```text
cse_field_dendro_2026/
├── android/                    # Projet Android Flutter
├── assets/                     # Logos et ressources autorisées
├── docs/                       # Guides utilisateur et technique
├── lib/                        # Code source Dart/Flutter
├── supabase/                   # Schéma et migrations sans secrets
├── test/                       # Tests, lorsqu’ils sont disponibles
├── .gitignore                  # Exclusion des secrets et fichiers générés
├── .zenodo.json               # Métadonnées utilisées par Zenodo
├── ACKNOWLEDGEMENTS.md         # Institutions et encadrement scientifique
├── CHANGELOG.md                # Historique des versions
├── CITATION.cff                # Citation normalisée du logiciel
├── LICENSE                     # À ajouter après validation institutionnelle
├── README.md                   # Présentation et installation
├── codemagic.yaml              # Construction automatisée de l’APK
├── pubspec.lock                # Versions précises des dépendances
├── pubspec.yaml                # Dépendances et version du logiciel
└── supabase.example.json       # Exemple sans vraie clé
```

## À ne jamais publier

- clé Supabase `service_role` ;
- mot de passe, jeton GitHub ou certificat de signature Android ;
- fichier `key.properties` ou fichier `.jks` ;
- données personnelles des agents ;
- données de terrain non autorisées ;
- photographies non consenties ;
- coordonnées sensibles ;
- véritable fichier `supabase.json` si sa publication n’est pas autorisée.

## Fichiers à joindre à la release GitHub

- `Land.Tree-Survey-v1.2.1.apk` ;
- `Land.Tree-Survey-v1.2.1-source.zip` ;
- guide utilisateur PDF ou PowerPoint ;
- documentation technique PDF ;
- notes de version.

## Procédure de publication

1. Copier les fichiers de ce pack à la racine du projet.
2. Renommer `GITIGNORE_A_AJOUTER.txt` en `.gitignore`, ou fusionner son contenu
   avec le `.gitignore` existant.
3. Faire valider les auteurs, contributeurs, affiliations, logos et licence.
4. Ajouter les ORCID dans les métadonnées, lorsqu’ils sont disponibles.
5. Vérifier que le dépôt ne contient aucun secret ni donnée confidentielle.
6. Construire et tester l’APK stable.
7. Créer le tag Git `v1.2.1`.
8. Activer le dépôt GitHub dans Zenodo.
9. Publier la release GitHub avec l’APK et les documents.
10. Vérifier la fiche Zenodo avant de diffuser le DOI.
