# Épinal Reader — Flutter / Dart

Lecteur EPUB Android en français. L’application conserve l’identifiant `com.epinal.reader` et utilise la même clé de signature que la version Android initiale, afin d’être installée **par-dessus** celle-ci sur Android 7 (API 24) ou plus récent. Android 6, pris en charge par l’ancienne version, n’est plus compatible avec cette version de Flutter.

## Fonctions
- Import de fichiers EPUB, bibliothèque locale, recherche par titre/auteur, détection des doublons, couverture lorsque disponible, suppression sans toucher au fichier d’origine.
- Lecture EPUB 2/3 sans DRM grâce à `flutter_epub_viewer` / EPUB.js : table des matières, navigation, position et progression, recherche dans le texte.
- Signets, surlignages jaunes et notes locales. Sélectionner du texte puis choisir **Surligner la sélection** dans le menu de lecture ; retrouver ou supprimer les passages depuis **Passages et notes**.
- Taille de texte, thèmes clair/sépia/sombre et pagination ou défilement ; lecture vocale de la page courante (moteur et voix Android requis).
- Vérification de la dernière GitHub Release au démarrage et manuellement depuis Paramètres → Vérifier les mises à jour, téléchargement de l’APK, contrôle SHA-256 et ouverture de l’installateur système.
- Les livres importés dans la version native précédente sont copiés à la première ouverture. Les positions de cette ancienne version, enregistrées en pixels plutôt qu’en CFI, ne sont pas converties. Les fichiers d’origine restent intacts.

## Mise à jour et signature
Chaque push sur `main` construit un APK signé, l’enregistre comme artefact Actions et le publie dans une GitHub Release `v1.0.NUMÉRO`, sous le nom `Epinal.apk`. Le numéro de build utilise `GITHUB_RUN_NUMBER` et augmente. L’application compare ce numéro à la dernière release publique et vérifie le `digest` SHA-256 de l’asset GitHub avant installation. Android vérifie la signature à l’installation.

La première version native ne dispose pas du vérificateur : installer une première fois cette version Flutter par-dessus elle. Ensuite, les nouvelles versions peuvent être proposées par l’application. Android exige la confirmation de l’utilisateur et, si nécessaire, l’autorisation d’installer depuis cette source ; aucune installation silencieuse n’est promise. La même clé et le même identifiant sont obligatoires ; la clé et ses mots de passe doivent être conservés en lieu sûr. La désinstallation supprime les données locales. Si l’autorisation a été refusée, relancer le téléchargement depuis la vérification de mise à jour.

Le workflow a besoin des secrets Actions `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Ne jamais les ajouter au dépôt. Le dépôt et ses Releases doivent rester publics pour la recherche des mises à jour sans authentification. Pour une distribution via Google Play, remplacer l’auto-installation par l’API de mise à jour Google Play et respecter ses règles de publication.

## Limites et confidentialité
- Les données et livres sont locaux ; les sauvegarder séparément. Pas encore de synchronisation, sauvegarde/export d’annotations, dictionnaire, traductions ni collections.
- La synthèse vocale lit la page affichée, pas automatiquement tout le livre. La voix dépend de l’appareil ; elle est actuellement configurée en français.
- Les EPUB avec DRM, scripts et mise en page fixe complexes ne sont pas garantis. Les scripts intégrés aux livres sont désactivés. Comme le moteur utilise une WebView, éviter les EPUB non fiables ; les ressources externes éventuelles peuvent nécessiter un accès réseau.
- La compatibilité et l’installation par-dessus doivent être vérifiées sur de vrais appareils, avec des EPUB représentatifs et sur plusieurs versions d’Android.

## Développement
Flutter 3.47.9, JDK 17, Android SDK et `flutter pub get`. `flutter analyze` puis `flutter test`. La compilation de release nécessite les variables d’environnement de signature du workflow. Les dépendances sont verrouillées dans `pubspec.lock`.

## Apparence et catégories
- Depuis Paramètres → Apparence, choisissez Clair, Sombre ou Confort visuel. Le choix est mémorisé et applique aussi une palette de lecture correspondante. Dans le livre, **Confort de lecture** permet d’adapter le thème indépendamment, ainsi que la taille du texte.
- Le mode Confort utilise des tons chauds, un fond adouci et un interligne plus large dans les livres compatibles. Il ne modifie pas la luminosité de l’écran et n’est pas un dispositif médical ; ajustez également la luminosité dans Android selon votre confort.
- Depuis Paramètres → Gérer les catégories, créez, renommez ou supprimez des catégories. Le menu de chaque livre permet de lui attribuer plusieurs catégories ; filtrez ensuite par catégorie ou choisissez « Sans catégorie ». Supprimer une catégorie ne supprime pas les livres. Les catégories restent stockées localement.
- Dans le sommaire d’un livre, recherchez un titre ou un numéro de chapitre pour filtrer la liste ; la recherche ignore les majuscules et les accents, et un appui ouvre directement le chapitre.

### Limiter les caches dans l’espace de travail
Dans Arena, utilisez `scripts/flutter-local.sh pub get`, puis `scripts/flutter-local.sh analyze --no-pub` et `scripts/flutter-local.sh test --no-pub` (Flutter doit être dans le `PATH`, ou définissez `FLUTTER_BIN`). Le script place les caches de l’outil et de Pub sous `~/.cache/epinal-reader`, dossier exclu des sauvegardes Arena. Les répertoires générés `.dart_tool` et `build` peuvent être supprimés après les tests ; ils sont régénérés automatiquement. Ne supprimez pas les sources, les fichiers EPUB personnels ni la sauvegarde de la clé de signature.

## Modes de lecture
Dans un livre, ouvrez le menu ⋮ puis **Mode de lecture**. Le choix est conservé entre les sessions et s’applique aux livres ouverts ensuite. La première ouverture après mise à jour utilise **Long strip** par défaut : défilement vertical continu (et non page par page), y compris entre les chapitres compatibles.
- **Left to Right** : pages horizontales, glisser à gauche pour avancer.
- **Right to Left** : pages horizontales, glisser à droite pour avancer.
- **Vertical** : pages successives, glisser vers le haut pour avancer.
- **Long strip** : défilement vertical libre et continu.
- **Livre animé** : pages horizontales avec un effet de feuilletage, en glissant à gauche ou à droite ou avec les flèches. L’animation démarre après le geste ; elle ne suit pas le doigt. Les captures temporaires restent en mémoire et ne sont ni enregistrées ni envoyées. Si la capture est indisponible ou si les animations sont désactivées, le changement de page reste instantané.

Le lecteur tente de restaurer la position CFI lors d’un changement de mode. Les gestes et la mise en page peuvent varier selon l’EPUB ; les modes doivent être vérifiés sur appareil, en particulier pour les livres à mise en page fixe et en écriture verticale.

## Bibliothèque
- Les boutons de la barre de bibliothèque permettent de basculer entre la liste et les cartes. La vue choisie est enregistrée localement.
- Dans le menu ⋮ d’un livre, **Choisir une image de couverture** accepte les fichiers JPG, PNG et WebP (12 Mo et 20 mégapixels maximum). La vignette est conservée dans le stockage privé, sans modifier le fichier EPUB ni l’image d’origine. **Restaurer la couverture EPUB** rétablit la couverture intégrée si elle existe, ou la vignette par défaut sinon.
- Les réglages d’apparence, de catégories et de mise à jour sont regroupés dans l’écran **Paramètres**.

## Icône
L’illustration source est dans `assets/branding/epinal-icon.png`. Les ressources Android comprennent une icône classique et ronde pour les appareils anciens, ainsi qu’une icône adaptative pour Android 8 et versions ultérieures, déclinées aux cinq densités Android.

## Palette Épinal
La palette est issue de `DESIGN.md` : accents garance et outremer, progression dorée, papiers vélin et sépia, et nuit douce. Les préférences d’apparence et de lecture existantes sont conservées ; **Sépia** et **Confort visuel** partagent les couleurs parchemin, avec un interligne accru pour le confort. Les couleurs de certains EPUB à mise en page imposée peuvent différer.
