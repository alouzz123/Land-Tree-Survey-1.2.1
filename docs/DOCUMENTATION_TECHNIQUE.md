# Land.Tree Survey

## Documentation technique, fonctionnelle et de déploiement

**Institution :** Centre de Suivi Écologique (CSE), Dakar  
**Projet :** GALILEO 2025–2028  
**Auteur principal :** Al Housseynou NIANG  
**Version documentée :** 1.0.0+1  
**Date de mise à jour :** 16 août 2026

> Ce document décrit l’état réel du projet Flutter, son fonctionnement hors ligne, sa sauvegarde cloud, sa base de données, ses exports et sa chaîne de construction APK. Les valeurs sensibles sont volontairement remplacées par des paramètres génériques.

## 1. Présentation du projet

Land.Tree Survey est une application Flutter de collecte de données dendrométriques et d’occupation du sol. Elle est conçue pour les missions de terrain du CSE et du projet GALILEO, avec un fonctionnement prioritairement hors ligne et une sauvegarde cloud automatique lorsque la connexion Internet est disponible.

### Objectifs

- créer et géoréférencer des placettes d’inventaire ;
- enregistrer les paramètres des arbres et autres points inventoriés ;
- associer des photographies aux placettes et aux arbres ;
- poursuivre la collecte en absence de réseau ;
- centraliser automatiquement les données dans une base cloud sécurisée ;
- exporter les données en CSV et en véritable classeur Excel XLSX.

## 2. Architecture générale

Le projet suit une architecture locale-first : l’enregistrement Hive est prioritaire et ne dépend jamais de la disponibilité du réseau.

```text
Utilisateur
    ↓
Interface Flutter
    ↓
DatabaseService
    ├── Hive : placettes_box et arbres_box (source locale)
    ├── Exports : CSV / XLSX
    └── SupabaseSyncService
            ├── Authentification anonyme
            ├── Tables placettes et arbres
            └── Bucket privé land-tree-photos
```

### Cycle de sauvegarde

1. L’utilisateur valide un formulaire.
2. La donnée est immédiatement enregistrée dans Hive.
3. Une synchronisation cloud est tentée sans bloquer l’interface.
4. En cas d’échec réseau, la donnée reste disponible localement.
5. Une nouvelle tentative est effectuée au démarrage et au retour de la connexion.

## 3. Technologies et dépendances

| Composant | Technologie | Rôle |
|---|---|---|
| Interface | Flutter / Dart | Application Android, Web et multiplateforme |
| Base locale | Hive / hive_flutter | Collecte hors ligne et cache principal |
| Préférences | shared_preferences | Licence acceptée et identifiant de l’appareil |
| Géolocalisation | geolocator | Latitude et longitude |
| Photos | image_picker | Prise et sélection de photographies |
| Fichiers | path_provider | Répertoires privés de l’application |
| Partage | share_plus | Partage des exports |
| CSV | csv | Séparateurs et échappement compatible Excel |
| Excel | excel | Création d’un véritable classeur XLSX |
| Cloud | supabase_flutter | Authentification, PostgreSQL et Storage |
| Réseau | connectivity_plus | Détection du retour de la connexion |
| Automatisation | GitHub + Codemagic | Construction de l’APK |

## 4. Structure des dossiers

```text
lib/
├── main.dart
├── home_screen.dart
├── formulaire_screen.dart
├── models/
│   ├── placette.dart
│   ├── placette.g.dart
│   ├── arbre.dart
│   └── arbre.g.dart
├── screens/
│   ├── licence_screen.dart
│   ├── liste_placettes_screen.dart
│   └── formulaire_arbres_screen.dart
├── services/
│   ├── database_service.dart
│   ├── gps_service.dart
│   └── supabase_sync_service.dart
└── theme/
    └── app_theme.dart

assets/logos/                 Identité CSE, Land.Tree et GALILEO
supabase/schema.sql           Schéma PostgreSQL, RLS et Storage
supabase.json                 Paramètres publics de compilation (local)
codemagic.yaml                Workflow de construction APK (dépôt GitHub)
```

## 5. Modules fonctionnels

### Accueil

- statistiques des placettes et individus ;
- accès aux formulaires et à la liste des placettes ;
- indication générique de sauvegarde cloud automatique ;
- synchronisation manuelle de vérification facultative ;
- identité visuelle CSE et GALILEO.

### Licence

La licence est affichée lors de la première installation. Son acceptation est conservée dans `SharedPreferences` avec la clé `licenceAccepted`. Elle informe l’utilisateur que les données sont enregistrées localement hors ligne puis sauvegardées automatiquement dans le cloud au retour d’Internet.

### Formulaire Placette

- région existante sélectionnée dans une liste ;
- ajout d’une nouvelle région ;
- ID automatique au format `REGION-JJMMAAAA-####` ;
- superficie, GPS, occupation du sol, culture, feux, observations et agent ;
- photo facultative ;
- sauvegarde Hive puis synchronisation cloud silencieuse.

Exemple : `OUARKHOKH-15082026-0001`.

### Formulaire Arbres

- indice défini par l’utilisateur ;
- incrémentation indépendante par placette et par indice ;
- exemples : `Arbre01`, `Arbre02`, `Bordure01`, `Bordure02` ;
- espèce, DAP, hauteur, houppier N-S/E-O, diamètre moyen, état sanitaire, forme du tronc, GPS, photo et notes ;
- calcul automatique d’un volume estimé simplifié.

La clé Hive interne est composée de `placetteId::arbreId` afin d’éviter les collisions entre placettes.

## 6. Modèle de données local

### Placette

| Champ | Type | Description |
|---|---|---|
| id | String | Identifiant métier de la placette |
| region | String | Région ou zone de collecte |
| superficie | double | Superficie en hectares |
| latitude / longitude | double | Centre ou position de référence |
| occupationSol | String | Classe d’occupation du sol |
| presenceCulture | bool | Présence de culture |
| presenceFeux | bool | Présence de traces de feu |
| observations | String | Observations libres |
| agent | String | Agent de collecte |
| dateCreation | DateTime | Horodatage local |

### Arbre

| Champ | Type | Description |
|---|---|---|
| id | String | ID visible, par exemple Arbre01 |
| placetteId | String | Placette parente |
| nomEspece | String | Nom scientifique et éventuellement local |
| dap | double | Diamètre à hauteur de poitrine en cm |
| hauteur | double | Hauteur totale en m |
| diametreCouronne | double? | Diamètre moyen du houppier |
| etatSanitaire | String? | Vivant, mort, malade ou attaqué |
| observations | String? | GPS, houppier, forme, photo et notes sérialisés |
| dateCreation | DateTime | Horodatage local |

## 7. Configuration cloud

### Prérequis administrateur

1. Créer un projet Supabase.
2. Ouvrir le SQL Editor.
3. Exécuter `supabase/schema.sql` une seule fois.
4. Activer **Authentication > Providers > Anonymous Sign-Ins**.
5. Vérifier les tables `placettes` et `arbres`.
6. Vérifier le bucket privé `land-tree-photos`.

### Paramètres de compilation

Créer `supabase.json` à la racine du projet :

```json
{
  "SUPABASE_URL": "https://IDENTIFIANT_PROJET.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_VOTRE_CLE_PUBLIQUE"
}
```

Ne jamais placer une clé `service_role` ou une clé secrète dans l’application, GitHub ou l’APK.

### Authentification et isolation

- l’application crée une session anonyme lorsqu’aucune session n’existe ;
- un `device_id` persistant est créé dans `SharedPreferences` ;
- les clés cloud associent l’ID métier et le `device_id` ;
- les politiques RLS limitent l’accès aux lignes de l’utilisateur authentifié ;
- les photos sont stockées sous `user_id/device_id/...` dans un bucket privé.

### Tables cloud

`placettes` utilise la clé primaire `(id, device_id)`.  
`arbres` utilise la clé primaire `(id, placette_id, device_id)` et une clé étrangère vers la placette. Les placettes sont synchronisées avant les arbres.

## 8. Exécution et développement

### Installation

```bash
flutter clean
flutter pub get
```

### Test sur Chrome

```bash
flutter run -d chrome --dart-define-from-file=supabase.json
```

### Test sans cloud

```bash
flutter run -d chrome
```

Dans ce cas, l’application reste utilisable localement, mais affiche dans la console que la configuration cloud n’a pas été fournie.

## 9. GitHub et gestion des versions

```bash
git status
git add .
git commit -m "Mise à jour Land.Tree Survey"
git push origin main
```

Le dépôt doit de préférence être privé. Avant chaque push, vérifier que `supabase.json` ne contient qu’une clé publique `sb_publishable_...`.

## 10. Construction APK avec Codemagic

Le fichier `codemagic.yaml` doit se trouver à la racine du dépôt :

```yaml
workflows:
  android-apk:
    name: Build Land Tree Survey APK
    max_build_duration: 60

    environment:
      flutter: stable

    scripts:
      - name: Vérifier la configuration cloud
        script: |
          test -f supabase.json
          echo "Configuration cloud trouvée"

      - name: Installer les dépendances
        script: flutter pub get

      - name: Construire l'APK
        script: flutter build apk --release --dart-define-from-file=supabase.json

    artifacts:
      - build/app/outputs/flutter-apk/app-release.apk
```

Après un push sur `main`, sélectionner le workflow `android-apk` dans Codemagic et lancer le build. Le journal doit contenir `assembleRelease`, pas `assembleDebug`.

## 11. Export des données

### CSV

L’export crée deux fichiers rectangulaires :

- `LandTree_Placettes_DATE.csv` ;
- `LandTree_Arbres_DATE.csv`.

Les fichiers utilisent UTF-8 avec BOM, `sep=;`, le séparateur point-virgule et l’échappement des textes. Ils s’ouvrent correctement dans une configuration française d’Excel.

### Excel

L’export produit un véritable fichier `.xlsx` avec deux feuilles :

- `Placettes` ;
- `Arbres`.

Les mesures sont écrites comme valeurs numériques et non comme un texte tabulé déguisé en fichier Excel.

## 12. Photos et stockage Android

Les chemins publics recherchés sont notamment :

```text
/storage/emulated/0/Pictures/LandTree_Survey/Placettes/
/storage/emulated/0/Pictures/LandTree_Survey/Arbres/
/storage/emulated/0/Download/LandTree_Survey/
```

Un repli vers le répertoire privé de l’application est utilisé lorsque nécessaire. Sur le Web, les données textuelles sont synchronisées, mais les chemins de fichiers locaux persistants ne sont pas disponibles de la même manière.

## 13. Sécurité et bonnes pratiques

- conserver le dépôt GitHub en privé ;
- n’utiliser que la clé publique dans le client Flutter ;
- conserver RLS activé sur toutes les tables ;
- conserver le bucket photo privé ;
- ne jamais journaliser ni partager une clé secrète ;
- tester le mode hors ligne avant chaque mission ;
- vérifier la présence des données cloud après une collecte test ;
- sauvegarder les exports avant toute réinstallation de l’application.

## 14. Dépannage

| Message | Cause | Correction |
|---|---|---|
| Supabase non configuré | Paramètres absents du build | Ajouter `--dart-define-from-file=supabase.json` |
| Anonymous sign-ins are disabled | Connexions anonymes désactivées | Activer Anonymous Sign-Ins |
| Forbidden use of secret API key | Clé secrète utilisée dans le client | Utiliser la clé publique publishable |
| PGRST205 table not found | Schéma non créé ou cache non rechargé | Exécuter `supabase/schema.sql` |
| Permission.photos non implémentée Web | Permission mobile appelée sur Web | Conserver le garde `kIsWeb` |
| Platform._operatingSystem sur Web | Utilisation directe de `Platform` | Éviter les appels fichier mobile sur Web |
| TextEditingController disposed | Contrôleur détruit avant la fermeture du dialogue | Utiliser le widget de dialogue autonome corrigé |
| CupertinoPageTransitionsBuilder introuvable | Incompatibilité de version Flutter CI | Utiliser `FadeUpwardsPageTransitionsBuilder` |
| CSV dans une seule colonne | Mauvais séparateur ou absence d’échappement | Utiliser les exports CSV corrigés avec `sep=;` |
| Build `assembleDebug` | Mauvais workflow Codemagic | Sélectionner `android-apk` utilisant `--release` |

## 15. Points à finaliser avant production

1. Remplacer `com.example.cse_field_dendro` par un identifiant Android officiel, par exemple `sn.cse.landtreesurvey`.
2. Créer une clé de signature Android de production et ne plus utiliser `signingConfigs.debug` pour le build release.
3. Mettre en place la propagation des suppressions locales vers le cloud.
4. Ajouter un état de synchronisation par enregistrement : en attente, synchronisé ou en erreur.
5. Ajouter des tests unitaires pour les IDs, les exports et la synchronisation.
6. Prévoir une stratégie de migration Hive lors des changements de modèle.
7. Ajouter l’export GPX si requis par le protocole terrain.
8. Réviser la durée de licence affichée : la période indiquée `1er janvier 2025 au 31 décembre 2028` correspond à quatre années civiles, et non trois.

## 16. Checklist avant mission

- [ ] APK release installé sur chaque tablette ;
- [ ] licence acceptée ;
- [ ] création d’une placette test ;
- [ ] création d’un Arbre01 et d’un Bordure01 ;
- [ ] coordonnées GPS vérifiées ;
- [ ] test photo réalisé ;
- [ ] test sans Internet réalisé ;
- [ ] synchronisation vérifiée après retour du réseau ;
- [ ] données visibles dans les tables cloud ;
- [ ] export CSV et XLSX ouvert dans Excel ;
- [ ] chargeurs, batteries externes et espace de stockage vérifiés.

## 17. Checklist de publication

- [ ] `flutter pub get` réussi ;
- [ ] aucune clé secrète dans Git ;
- [ ] `supabase.json` présent dans l’environnement de build ;
- [ ] schéma cloud installé ;
- [ ] connexions anonymes activées ;
- [ ] `codemagic.yaml` présent sur `main` ;
- [ ] build `assembleRelease` réussi ;
- [ ] APK téléchargé et testé ;
- [ ] numéro de version incrémenté dans `pubspec.yaml` ;
- [ ] changements documentés dans `MODIFICATIONS_REGION.md`.

---

**Responsable technique :** Al Housseynou NIANG  
**Institution :** Centre de Suivi Écologique (CSE), Dakar  
**Cadre :** Projet GALILEO 2025–2028
