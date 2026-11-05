# Épinal — lecteur EPUB Android

Première version de lecteur Android, conçue pour fonctionner localement et sans compte.

## Fonctionnalités disponibles
- Import d’un fichier EPUB depuis le sélecteur Android (100 Mo maximum), copie privée dans l’application.
- Bibliothèque locale, recherche par titre ou auteur, ouverture et retrait sans toucher au fichier d’origine.
- Lecture des chapitres de la séquence EPUB, navigation, reprise du dernier chapitre et de la position verticale.
- Taille de texte ajustable, thèmes clair, sépia et sombre.
- Fichiers locaux seulement : aucun accès réseau, JavaScript désactivé et ressources d’EPUB confinées à l’archive.

## Limites connues
- La liste des parties reflète l’ordre interne du livre et les noms de fichiers, **pas** la véritable table des matières EPUB.
- EPUB 2/3 à texte redistribuable simples visés ; mise en page fixe, scripts interactifs, multimédia, polices ou encodages particuliers ne sont pas garantis. Les EPUB protégés par DRM ne sont pas pris en charge.
- Pas encore de couvertures extraites, signets multiples, annotations, recherche dans le texte, synthèse vocale, dictionnaire ou synchronisation. La reprise est une position en pixels, pas un EPUB CFI : elle peut être approximative après changement de format d’écran ou de taille du texte.
- Les données sont locales ; désinstaller l’application les supprime. Faire une sauvegarde des fichiers d’origine.

## Génération de l’APK
Chaque push sur `main` ou lancement manuel de **Générer l’APK Android** produit un APK signé téléchargeable depuis l’onglet **Actions**, dans l’artefact `Epinal-APK-signe` (conservé 90 jours). Une exécution doit réussir avant qu’un APK soit disponible. Le numéro de version utilise le numéro de l’exécution GitHub Actions. L’artefact n’est pas automatiquement publié dans GitHub Releases.

Secrets Actions requis : `KEYSTORE_BASE64` (contenu PKCS#12 encodé en base64), `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Ne jamais committer ces valeurs. Conserver une copie de sauvegarde sécurisée de la clé ET des mots de passe : perdre la clé peut empêcher la mise à jour des installations existantes. Pour une application déjà publiée, il faut réutiliser sa clé d’origine (ou gérer Play App Signing).

Pour compiler localement : Android SDK 35, JDK 17, Gradle 8.9, puis `gradle assembleDebug`. Une compilation de production nécessite les variables d’environnement indiquées dans `app/build.gradle`.

## Feuille de route
1. Tests instrumentés sur appareils et jeux d’EPUB réels, véritable table des matières EPUB 2/3, couvertures et meilleure restauration des positions.
2. Signets, surlignage et notes, recherche dans le livre, personnalisation avancée et accessibilité.
3. Synthèse vocale, collections, statistiques, dictionnaire et sauvegarde/synchronisation facultative.
4. Étudier Readium pour une compatibilité EPUB 2/3, accessibilité et positions plus robustes ; les DRM exigent une intégration et des licences spécifiques.
