# Épinal Windows — application native

Cette branche `windows` contient le projet Windows en C#/.NET et WebView2, indépendant d’Android. La branche `main` reste celle d’Android en Flutter ; les deux branches sont développées et construites séparément.

**État : migration Windows en cours, version expérimentale.** Le code natif ne couvre pas encore toutes les fonctions de l’ancienne version Flutter. Le workflow Windows construit et teste un installateur expérimental distinct, sans publier de mise à jour stable ni remplacer l’ancienne installation.

- Projet et consignes : [native_windows/README.md](native_windows/README.md).
- Construire localement : `dotnet build native_windows/Epinal.Windows/Epinal.Windows.csproj` (Windows ou SDK .NET avec ciblage Windows).
- Vérifier le cœur : `dotnet run --project native_windows/Epinal.Core.Tests`.
- Le workflow `.github/workflows/windows.yml` produit l’artefact expérimental après ses tests sur Windows. Android n’est ni compilé ni publié par ce workflow.

Les anciennes versions Windows Flutter sont conservées dans l’historique Git et dans les releases déjà publiées. La migration des données doit rester sauvegardée et non destructive ; ne pas utiliser cette version pour remplacer la version stable avant validation complète.
