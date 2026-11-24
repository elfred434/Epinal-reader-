# Épinal Windows natif — chantier expérimental

**Cette version n’est pas achevée, ne remplace pas la version Flutter et ne doit pas être publiée comme stable.** L’APK Android et le processus de publication stable n’ont pas été modifiés. La compilation sous Windows et les essais d’interface réels doivent être validés avant toute utilisation de confiance.

## Contenu actuel

- Application WPF .NET 8 et WebView2, profil séparé dans `%APPDATA%\Epinal Native Experimental` ; import par copie privée, recherche, ouverture EPUB, sommaire, navigation, réglage de taille, thèmes, défilement, catégories, signets, passages/notes, lecture vocale, export et transfert de position `EPINAL1`.
- « Ajouter la suite » compare le livre complet : les sections et ressources antérieures modifiées sont présentées une par une, avec aperçu textuel quand il s’agit d’un chapitre. L’utilisateur choisit l’ancienne ou la nouvelle version pour chaque conflit, puis confirme. Le fichier interne est mis à jour et sa version précédente peut être restaurée. Les sections déplacées ou renommées et les EPUB trop volumineux sont refusés prudemment ; une position ou annotation peut ne plus correspondre à un chapitre corrigé.
- Gestion des catégories, suppression de signets, modification et suppression de notes, couvertures personnalisées ou d’origine, réglages de lecture persistants et reprise du dernier livre. Les modes Flutter vertical, droite-à-gauche et livre animé ne sont pas encore reproduits.
- Reprise optionnelle depuis le profil Flutter après fermeture de l’ancienne application : copie indépendante de la bibliothèque et de ses positions, catégories, signets et passages, ainsi qu’une sauvegarde complète du profil source. La dernière sauvegarde d’édition est également copiée et peut être restaurée ; sa position est reprise uniquement si son empreinte correspond. La reprise ne synchronise pas les deux versions.
- Contrôleur de mise à jour : vérifie GitHub uniquement pour un asset natif nommé précisément `Epinal-Native-Setup-x64.exe` (jamais l’installateur Flutter), télécharge avec limites et SHA-256, demande confirmation et lance l’installateur. Aucun tel installateur natif stable n’est publié à ce stade. Le SHA-256 détecte des corruptions mais ne prouve pas l’identité de l’éditeur : signature Authenticode à prévoir.
- Un installateur **expérimental distinct** a son propre identifiant et installe l’application dans un autre dossier ; il ne met pas à jour Épinal stable. Une CI Windows distincte construit et teste cette version sans créer de release.

## Vérifications

`dotnet run --project native_windows/Epinal.Core.Tests` teste le transfert de position, l’import par copie indépendante, la comparaison et la restauration d’une suite simple, la reprise du profil, les choix de modifications, la persistance des réglages et les refus de téléchargement. `dotnet build native_windows/Epinal.Windows/Epinal.Windows.csproj` compile l’interface ; sous Linux, cela ne teste pas son exécution Windows ou WebView2.

## À terminer avant toute publication stable

- Tests fonctionnels complets sur Windows avec WebView2, vrais EPUB variés et lecteur d’écran ; robustesse du pont local, navigation, notes, recherche, thèmes et voix.
- Parité avec les fonctionnalités Flutter : modes de lecture, gestes, lecture vocale, accessibilité, réglages et autres fonctions manquantes ou différentes ; vérifier avec un inventaire fonctionnel détaillé.
- Tester toutes les étapes de migration sur une copie réelle, retours arrière, pannes, gros fichiers et formats inhabituels ; maintenir une sauvegarde avant l’installation.
- Signature, mise à jour depuis un vrai installateur natif, fermeture/redémarrage, erreurs de réseau ou d’installation, et installation/réinstallation/désinstallation sur Windows réel. Ne pas modifier les releases ni l’installateur stables avant ces validations.
- Avant redistribution de l’installateur : vérifier la provenance exacte et les licences de **toutes** les dépendances incorporées aux bundles JavaScript ; les notices déjà copiées dans `Reader/licenses` ne constituent pas encore un inventaire complet.
