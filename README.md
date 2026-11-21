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
Dans un livre, ouvrez **Outils de lecture** (•••) puis **Mode de lecture**. Le choix est conservé entre les sessions et s’applique aux livres ouverts ensuite. La première ouverture après mise à jour utilise **Long strip** par défaut : défilement vertical continu (et non page par page), y compris entre les chapitres compatibles.
- **Left to Right** : pages horizontales, glisser à gauche pour avancer.
- **Right to Left** : pages horizontales, glisser à droite pour avancer.
- **Vertical** : pages successives, glisser vers le haut pour avancer.
- **Long strip** : défilement vertical libre et continu.
- **Livre animé** : pages horizontales avec un pli de papier et son ombre inspirés de Folio : de droite à gauche pour avancer et de gauche à droite pour revenir, en glissant ou avec les flèches. Le coin supérieur ou inférieur dépend de la hauteur du geste. Contrairement à Folio, cette adaptation EPUB déclenche l’animation après le geste ; la page ne suit pas le doigt. Les captures temporaires restent en mémoire et ne sont ni enregistrées ni envoyées. Si la capture est indisponible ou si les animations sont désactivées, le changement de page reste instantané.

Le lecteur tente de restaurer la position CFI lors d’un changement de mode. Les gestes et la mise en page peuvent varier selon l’EPUB ; les modes doivent être vérifiés sur appareil, en particulier pour les livres à mise en page fixe et en écriture verticale.

## Bibliothèque
- La bibliothèque présente un bouton **Importer**, une recherche par titre ou auteur, des filtres par catégorie et un compteur. Si aucun livre ne correspond, **Effacer les filtres** permet de revenir à la liste complète.
- **Reprendre la lecture** rouvre le dernier livre ouvert. Les boutons de la bibliothèque permettent de basculer entre liste et cartes ; la vue choisie est enregistrée localement.
- En lecture, les boutons en haut donnent accès au sommaire et au confort visuel. **Outils de lecture** regroupe la recherche, les signets, les passages, les modes et la lecture vocale ; la barre en bas indique la progression et permet de naviguer ou de poser un signet.
- Dans le menu ⋮ d’un livre, **Choisir une image de couverture** accepte les fichiers JPG, PNG et WebP (12 Mo et 20 mégapixels maximum). La vignette est conservée dans le stockage privé, sans modifier le fichier EPUB ni l’image d’origine. **Restaurer la couverture EPUB** rétablit la couverture intégrée si elle existe, ou la vignette par défaut sinon.
- Les réglages d’apparence, de catégories et de mise à jour sont regroupés dans l’écran **Paramètres**.

## Icône
L’illustration source est dans `assets/branding/epinal-icon.png`. Les ressources Android comprennent une icône classique et ronde pour les appareils anciens, ainsi qu’une icône adaptative pour Android 8 et versions ultérieures, déclinées aux cinq densités Android.

Le fichier `DESIGN.md` reste disponible comme référence, mais sa palette n’est pas active : l’interface utilise à nouveau les couleurs vertes précédentes.

## Compléter un livre EPUB
1. Dans la bibliothèque, touchez **Importer → Ajouter la suite d’un livre**, puis choisissez le livre existant et le nouvel EPUB complet. Vous pouvez aussi ouvrir ⋮ sur le livre puis **Ajouter la suite**. Le fichier d’origine sur l’appareil n’est pas modifié.
2. Épinal compare les sections de lecture et leurs ressources. Les nouvelles sections sont ajoutées. Pour chaque section ou ressource modifiée, consultez les extraits et choisissez **Garder** ou **Remplacer**, puis confirmez. Les extraits montrent seulement la première différence de texte ; une modification de mise en forme ou d’image peut ne pas y apparaître. Les images et styles sont parfois partagés entre plusieurs sections.
3. La bibliothèque, les catégories, la couverture, les signets et les annotations restent associés au même livre. La position de lecture est conservée, mais peut se décaler si vous remplacez une section modifiée. L’index de progression est régénéré. **⋮ → Rétablir la version précédente** remet la dernière version sauvegardée et sa position ; les annotations restent enregistrées mais celles créées dans la suite peuvent ne plus correspondre. Une seule version précédente est conservée, remplacée à chaque nouvelle mise à jour.

Par sécurité, la comparaison automatique n’accepte que les EPUB complets non chiffrés de 50 Mo maximum (80 Mo décompressés), dont les anciennes sections et ressources conservent leur ordre, identifiants et chemins, avec les nouvelles sections à la fin. Les sections répétées sont refusées. Si le fournisseur a réorganisé ou renommé les fichiers internes, ou si un nouveau chapitre est à l’intérieur d’une section existante, la comparaison peut être refusée ou demander de choisir la section entière. Aucun changement n’est appliqué en cas de refus ; vous pouvez importer l’EPUB comme nouveau livre.

## Exporter un livre
Dans la bibliothèque, ouvrez le menu **⋮** du livre, puis **Exporter le livre EPUB**. Choisissez un nom et un dossier dans le sélecteur Android. Le fichier exporté correspond à l’édition actuellement présente dans Épinal : après l’ajout d’une suite, il contient les nouvelles sections et les versions retenues lors de la comparaison. Si vous avez rétabli une version précédente, c’est celle-ci qui est exportée. Le livre privé et le fichier EPUB d’origine ne sont pas modifiés.

L’export contient le contenu de l’EPUB, pas les données propres à Épinal : progression, signets, notes, surlignages, catégories et couverture personnalisée ne sont pas intégrés. En cas d’échec pendant l’écriture, un fichier incomplet peut rester dans le dossier choisi. Vérifiez que vous avez le droit de copier ou partager le livre.

## Épinal pour Windows
Téléchargez `Epinal-Windows-x64.zip` depuis la dernière Release GitHub, puis **extrayez toute l’archive** dans un dossier de votre choix et lancez `Epinal.exe`. Ne lancez pas le programme depuis l’intérieur du ZIP : il a besoin de ses DLL et du dossier `data`. Cette version est destinée à Windows 10/11 64 bits et nécessite le **Microsoft Edge WebView2 Runtime** ; installez-le depuis Microsoft si le lecteur indique qu’il est absent. L’exécutable Windows n’est pas signé et Windows peut afficher un avertissement de sécurité.

Les livres et réglages Windows sont stockés dans les données de l’utilisateur Windows, séparément du dossier du programme. Ils ne sont pas synchronisés automatiquement avec Android. Pour transférer un livre mis à jour, exportez-le en EPUB sur l’autre appareil, copiez-le sur le PC, puis importez-le. Les positions, annotations, catégories et couvertures personnalisées ne sont pas incluses dans cet export.

Pour mettre à jour Windows, utilisez **Paramètres → Vérifier les mises à jour**, ouvrez la Release proposée et téléchargez le nouveau ZIP. Fermez Épinal, puis extrayez la nouvelle version dans un dossier propre (ou remplacez les fichiers du programme après l’avoir fermé). Les données utilisateur ne sont pas supprimées. Il n’y a pas d’installation ni de mise à jour automatique silencieuse ; l’archive est publiée sur GitHub avec son empreinte SHA-256.

Le test d’intégration WebView2 peut réussir puis signaler une erreur de nettoyage du dossier temporaire du harnais Flutter sur le runner Windows ; cette anomalie est signalée dans les logs et ne remplace pas un essai sur un PC réel.

Chaque push sur `main` lance la compilation et la publication de l’APK Android signé. Après cette publication, GitHub Actions teste le chargement d’un EPUB avec WebView2, compile la version Windows x64 et ajoute le ZIP à la même Release. La version Windows peut donc apparaître quelques minutes après l’APK ; si sa compilation échoue, l’APK Android reste publié.
