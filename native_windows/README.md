# Épinal Windows natif — chantier expérimental

**Cette version n’est pas achevée, ne remplace pas la version Flutter et ne doit pas être publiée comme stable.** L’APK Android et le processus de publication stable n’ont pas été modifiés. La compilation sous Windows et les essais d’interface réels doivent être validés avant toute utilisation de confiance.

## Contenu actuel

- Application WPF .NET 8 et WebView2, profil séparé dans `%APPDATA%\Epinal Native Experimental` ; import par copie privée, recherche, ouverture EPUB, sommaire, navigation, réglage de taille, thèmes, défilement, catégories, signets, passages/notes, lecture vocale, export et transfert de position `EPINAL1`.
- « Ajouter la suite » n’accepte actuellement qu’une nouvelle édition dont toutes les anciennes ressources (à part le paquet et les documents de navigation) restent inchangées et dont l’ordre de lecture se prolonge strictement. Il ne sait pas encore examiner les corrections des chapitres comme la version Flutter. Restauration de la dernière version conservée.
- Reprise optionnelle depuis le profil Flutter après fermeture de l’ancienne application : copie indépendante de la bibliothèque et de ses positions, catégories, signets et passages, ainsi qu’une sauvegarde complète du profil source. Les anciennes sauvegardes de versions de livres sont dans cette sauvegarde mais ne sont pas encore restaurables dans l’interface native. La reprise ne synchronise pas les deux versions.
- Contrôleur de mise à jour : vérifie GitHub uniquement pour un asset natif nommé précisément `Epinal-Native-Setup-x64.exe` (jamais l’installateur Flutter), télécharge avec limites et SHA-256, demande confirmation et lance l’installateur. Aucun tel installateur natif stable n’est publié à ce stade. Le SHA-256 détecte des corruptions mais ne prouve pas l’identité de l’éditeur : signature Authenticode à prévoir.
- Un installateur **expérimental distinct** a son propre identifiant et installe l’application dans un autre dossier ; il ne met pas à jour Épinal stable. Une CI Windows distincte construit et teste cette version sans créer de release.

## Vérifications

`dotnet run --project native_windows/Epinal.Core.Tests` teste le transfert de position, l’import par copie indépendante, la comparaison et la restauration d’une suite simple, la reprise du profil et les refus de téléchargement. `dotnet build native_windows/Epinal.Windows/Epinal.Windows.csproj` compile l’interface ; sous Linux, cela ne teste pas son exécution Windows ou WebView2.

## À terminer avant toute publication stable

- Tests fonctionnels complets sur Windows avec WebView2, vrais EPUB variés et lecteur d’écran ; robustesse du pont local, navigation, notes, recherche, thèmes et voix.
- Parité avec les fonctionnalités Flutter : revue des modifications anciennes dans les éditions, restauration des anciennes sauvegardes, gestion complète des catégories, marque-pages et passages, couvertures, modes de lecture, réglages et autres fonctions manquantes.
- Tester toutes les étapes de migration sur une copie réelle, retours arrière, pannes, gros fichiers et formats inhabituels ; maintenir une sauvegarde avant l’installation.
- Signature, mise à jour depuis un vrai installateur natif, fermeture/redémarrage, erreurs de réseau ou d’installation, et installation/réinstallation/désinstallation sur Windows réel. Ne pas modifier les releases ni l’installateur stables avant ces validations.
