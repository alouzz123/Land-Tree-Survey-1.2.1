<p align="center">
  <img src="assets/logos/logo_land_tree.png"
       alt="Logo Land.Tree Survey"
       width="180">
</p>

# Land.Tree Survey

<p align="center">
  <a href="https://doi.org/10.5281/zenodo.23267561">
    <img src="https://zenodo.org/badge/DOI/10.5281/zenodo.23267561.svg"
         alt="DOI">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg"
         alt="Licence Apache 2.0">
  </a>
  <img src="https://img.shields.io/badge/Flutter-Mobile-02569B.svg"
       alt="Application Flutter">
</p>

**Land.Tree Survey** est une application mobile développée avec Flutter pour la collecte hors ligne et géoréférencée des données d’occupation du sol (OCSOL), des placettes et des arbres dans les systèmes agroforestiers et les paysages de savane.

L’application a été développée dans le cadre des activités scientifiques du projet **GALILEO**, avec l’appui du **Centre de Suivi Écologique (CSE)**.

## Objectif

Land.Tree Survey vise à faciliter la collecte, la gestion, la sécurisation et l’exportation des données de terrain relatives :

- à l’occupation du sol ;
- aux caractéristiques des placettes ;
- à la localisation des arbres ;
- à l’identification scientifique des espèces ;
- aux mesures dendrométriques ;
- aux photographies et observations de terrain.

L’application a été pensée pour être utilisée dans des zones où la connexion Internet est faible ou indisponible. Les données sont d’abord enregistrées localement sur l’appareil, puis synchronisées avec la base cloud lorsque le réseau devient disponible.

## Fonctionnalités principales

- caractérisation de l’occupation du sol (OCSOL) au niveau des placettes ;
- création, consultation et gestion des placettes ;
- sélection du pays du projet ;
- adaptation des listes d’espèces et d’occupation du sol au pays sélectionné ;
- inventaire dendrométrique complet des arbres ;
- relevé simple pour la localisation et l’identification rapide des arbres ;
- génération et incrémentation automatiques des identifiants ;
- conservation du préfixe d’identifiant entre les différents modes de relevé ;
- acquisition automatique des coordonnées GPS ;
- possibilité de saisir manuellement les coordonnées GPS ;
- prise et sauvegarde de photographies de terrain ;
- gestion des arbres à tronc unique et à troncs multiples ;
- mesure directe ou calcul de la hauteur au clinomètre ;
- consultation et modification des données enregistrées ;
- stockage local hors connexion avec Hive ;
- synchronisation avec Supabase lorsque le réseau est disponible ;
- exportation des données aux formats CSV et Excel ;
- interface responsive adaptée aux téléphones et aux tablettes Android.

## Occupation du sol — OCSOL

Lors de la création d’une placette, l’utilisateur peut renseigner les informations relatives à l’occupation du sol, notamment :

- la région ou la zone d’étude ;
- la superficie de la placette ;
- la catégorie d’occupation du sol ;
- la présence ou l’absence de cultures ;
- la présence ou l’absence de feux ;
- les coordonnées GPS ;
- les observations complémentaires ;
- le nom de l’agent chargé de la collecte.

Pour le Sénégal, une liste d’occupations du sol est proposée. L’option **Autre** permet de saisir manuellement une catégorie qui ne figure pas dans la liste.

Pour les autres pays pilotes, les nouvelles occupations du sol saisies par l’utilisateur peuvent être conservées et proposées lors des collectes suivantes.

## Pays pilotes

La version 1.2.1 propose quatre pays pilotes :

- Sénégal ;
- Kenya ;
- Ghana ;
- Cameroun.

L’option **Autre** permet également d’utiliser l’application dans un pays différent.

Le choix du pays est effectué au premier démarrage du projet. Il permet d’adapter les listes d’espèces et les catégories utilisées pendant la collecte.

La sélection du pays fonctionne hors ligne et ne nécessite aucune image ou ressource téléchargée depuis Internet.

## Modes de collecte

Land.Tree Survey propose deux modes de collecte des informations sur les arbres.

### Inventaire dendrométrique

Le mode dendrométrique permet d’enregistrer des informations détaillées :

- identifiant de l’arbre ;
- identifiant de la placette ;
- nom scientifique de l’espèce ;
- latitude et longitude ;
- diamètre à hauteur de poitrine ;
- configuration du tronc ;
- nombre de troncs ;
- diamètre moyen des troncs ;
- diamètre cumulé ;
- hauteur totale ;
- méthode de mesure de la hauteur ;
- distance de mesure au clinomètre ;
- angle vers la cime ;
- angle vers la base ;
- diamètre du houppier Nord–Sud ;
- diamètre du houppier Est–Ouest ;
- diamètre moyen du houppier ;
- forme du tronc ;
- photographie ;
- commentaires et observations ;
- date et heure de création.

Pour un arbre à plusieurs troncs, l’utilisateur renseigne le diamètre moyen représentatif et le nombre de troncs. L’application calcule ensuite la valeur cumulée selon la configuration définie dans le protocole de collecte.

### Relevé simple

Le relevé simple permet une collecte plus rapide. Il comprend principalement :

- l’identifiant de l’arbre ;
- le nom scientifique de l’espèce ;
- la latitude ;
- la longitude ;
- une photographie facultative ;
- les observations utiles.

Ce mode est adapté aux missions nécessitant principalement la localisation et l’identification des arbres, sans mesures dendrométriques détaillées.

## Gestion des identifiants

Lors de la première utilisation d’une placette, l’identifiant proposé par défaut commence par :

```text
Arbre01
```

L’utilisateur peut définir un préfixe adapté au projet. Par exemple :

```text
P050-A0
```

L’application génère alors :

```text
P050-A001
P050-A002
P050-A003
```

Lorsque l’utilisateur revient dans la même placette, l’application récupère le dernier identifiant enregistré et propose automatiquement le numéro suivant.

Le préfixe défini dans l’inventaire dendrométrique peut également être repris dans le relevé simple, sauf si l’utilisateur décide de le modifier.

## Mesure de la hauteur

L’application propose deux méthodes.

### Mesure directe

L’utilisateur saisit directement la hauteur totale de l’arbre en mètres.

### Mesure au clinomètre

L’utilisateur renseigne :

1. la distance horizontale entre l’observateur et l’arbre ;
2. l’angle vers la cime ;
3. l’angle vers la base.

La hauteur est calculée automatiquement selon la formule :

```text
Hauteur = Distance × [tan(angle cime) − tan(angle base)]
```

## Stockage hors ligne

Land.Tree Survey utilise Hive pour enregistrer les données localement sur l’appareil.

Le stockage local permet :

- de travailler sans connexion Internet ;
- de conserver les données après la fermeture de l’application ;
- de reprendre la collecte après le redémarrage de l’appareil ;
- de synchroniser les données lorsque la connexion devient disponible.

Il est recommandé d’effectuer régulièrement une exportation des données afin de disposer d’une copie de sauvegarde.

## Synchronisation cloud

Lorsque Supabase est configuré et qu’une connexion Internet est disponible, les données locales peuvent être synchronisées avec la base cloud.

La synchronisation concerne notamment :

- les placettes ;
- les inventaires dendrométriques ;
- les relevés simples ;
- les champs détaillés associés aux arbres ;
- les références des photographies.

La configuration Supabase doit respecter les règles de sécurité définies par l’institution responsable du déploiement.

## Exportation des données

Les données peuvent être exportées aux formats CSV et Excel.

Le classeur Excel contient trois feuilles distinctes :

1. `Placettes` ;
2. `Dendrométrique` ;
3. `Relevé simple`.

Chaque variable possède sa propre colonne afin de faciliter :

- les analyses statistiques ;
- les contrôles de qualité ;
- l’intégration dans QGIS ;
- la production de cartes ;
- les analyses dendrométriques ;
- l’exploitation des données sous R, Python ou Excel.

Les fichiers CSV utilisent un séparateur compatible avec Excel en configuration française.

Pour une intégration dans un logiciel SIG :

- utilisez la longitude comme coordonnée X ;
- utilisez la latitude comme coordonnée Y ;
- sélectionnez le système de coordonnées EPSG:4326.

## Installation de l’APK

Téléchargez l’APK depuis la section **Releases** du dépôt GitHub.

Sur l’appareil Android :

1. ouvrez le fichier APK ;
2. autorisez l’installation depuis cette source si Android le demande ;
3. installez l’application ;
4. ouvrez Land.Tree Survey ;
5. acceptez la licence d’utilisation ;
6. sélectionnez le pays du projet ;
7. autorisez l’accès à la localisation, à la caméra et aux fichiers.

Les autorisations sont nécessaires au fonctionnement du GPS, des photographies et des exportations.

## Installation pour le développement

### Prérequis

- Flutter stable ;
- SDK Android ;
- Git ;
- un éditeur comme Visual Studio Code ou Android Studio ;
- un projet Supabase si la synchronisation cloud est utilisée.

Clonez le dépôt :

```bash
git clone https://github.com/alouzz123/Land-Tree-Survey-1.2.1.git
```

Accédez au dossier :

```bash
cd Land-Tree-Survey-1.2.1
```

Installez les dépendances :

```bash
flutter pub get
```

Créez un fichier `supabase.json` à partir de `supabase.example.json`.

Exemple :

```json
{
  "SUPABASE_URL": "VOTRE_URL_SUPABASE",
  "SUPABASE_ANON_KEY": "VOTRE_CLE_PUBLIQUE"
}
```

Lancez l’application :

```bash
flutter run --dart-define-from-file=supabase.json
```

N’utilisez jamais une clé `service_role` ou une clé secrète dans l’application.

Le fichier `supabase.json` ne doit pas être ajouté au dépôt public.

## Construction de l’APK

Pour construire un APK Android en mode Release :

```bash
flutter build apk --release --dart-define-from-file=supabase.json
```

L’APK sera généré dans :

```text
build/app/outputs/flutter-apk/app-release.apk
```

Pour produire des APK plus légers selon l’architecture Android :

```bash
flutter build apk --release --split-per-abi --dart-define-from-file=supabase.json
```

## Déploiement avec Codemagic

Le projet peut être construit automatiquement avec Codemagic à partir du dépôt GitHub.

La commande de construction doit intégrer la configuration Supabase :

```bash
flutter build apk --release --dart-define-from-file=supabase.json
```

Si `supabase.json` n’est pas présent dans le dépôt pour des raisons de sécurité, utilisez les variables d’environnement sécurisées de Codemagic.

Ne publiez jamais une clé secrète dans GitHub ou dans les journaux de construction.

## Confidentialité et sécurité

Le dépôt public ne doit contenir aucune :

- donnée personnelle ;
- photographie de terrain non autorisée ;
- coordonnée sensible ;
- clé privée ;
- clé `service_role` ;
- configuration Supabase confidentielle ;
- clé de signature Android ;
- information permettant un accès non autorisé à la base de données.

La personne ou l’institution qui déploie l’application reste responsable :

- des politiques de sécurité Supabase ;
- des autorisations de collecte ;
- du consentement relatif aux photographies ;
- de la protection des données ;
- de la sauvegarde des informations collectées ;
- du respect de la législation applicable.

## Documentation

Le dépôt comprend notamment :

- un guide d’utilisation ;
- une documentation technique ;
- le schéma de la base Supabase ;
- les migrations nécessaires ;
- les fichiers de citation ;
- les remerciements institutionnels.

## Citation

Pour citer précisément la version 1.2.1 :

> Niang, A. H. (2026). *Land.Tree Survey v1.2.1 – Application mobile hors ligne pour les inventaires arborés et dendrométriques*. Zenodo. https://doi.org/10.5281/zenodo.23267562

DOI de la version 1.2.1 :

```text
https://doi.org/10.5281/zenodo.23267562
```

DOI général, toutes versions confondues :

```text
https://doi.org/10.5281/zenodo.23267561
```

## Auteur principal

**Al Housseynou Niang**  
Doctorant en Télédétection et Intelligence artificielle  
Centre de Suivi Écologique — Projet GALILEO  
ORCID : https://orcid.org/0009-0001-8438-8799

## Encadrement scientifique et remerciements

Consultez [`ACKNOWLEDGEMENTS.md`](ACKNOWLEDGEMENTS.md) pour la liste complète des institutions, partenaires et encadrants scientifiques associés au projet.

## Retours et signalement de problèmes

Les erreurs, difficultés d’utilisation et propositions d’amélioration peuvent être signalées dans l’onglet **Issues** du dépôt GitHub.

Pour signaler une erreur, précisez :

- la version de Land.Tree Survey ;
- le modèle de l’appareil ;
- la version Android ;
- le pays pilote sélectionné ;
- le mode utilisé ;
- les étapes permettant de reproduire le problème ;
- le résultat attendu ;
- le résultat obtenu ;
- une capture d’écran, si elle ne contient aucune information sensible.

Ne publiez jamais une clé, un fichier de configuration privé ou une donnée sensible dans un ticket GitHub.

## Licence

Ce logiciel est distribué sous la **licence Apache 2.0**.

Cette licence autorise notamment :

- l’utilisation du logiciel ;
- la copie ;
- la modification ;
- la redistribution ;
- l’utilisation dans d’autres projets.

Toute réutilisation doit respecter les conditions précisées dans le fichier [`LICENSE`](LICENSE), notamment :

- conserver les mentions de droit d’auteur ;
- conserver une copie de la licence Apache 2.0 ;
- indiquer les modifications apportées ;
- respecter les mentions éventuellement présentes dans un fichier `NOTICE`.

Le logiciel est fourni sans garantie, conformément aux dispositions de la licence Apache 2.0.

Copyright © 2026 Al Housseynou Niang.
