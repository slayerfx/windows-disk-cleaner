# windows-disk-cleaner

**Libère de la place sur le disque système de Windows en un double-clic, sans toucher à tes fichiers.**

*English version: [README.md](README.md)*

`windows-disk-cleaner` supprime uniquement ce qui se reconstruit tout seul ou ne sert plus. Commence par une simulation pour voir exactement ce qu'il ferait : il ne supprime jamais tes documents, tes jeux ni tes téléchargements.

## Démarrage rapide

1. Télécharge le projet (**Code → Download ZIP**) et décompresse-le où tu veux, par exemple dans `Documents\windows-disk-cleaner`.
   Si Windows bloque les fichiers : clic droit sur le ZIP → **Propriétés** → coche **Débloquer** avant de décompresser.
2. Double-clique sur **`Analyze.cmd`** : une simulation qui ne change rien et liste ce qui pourrait être libéré.
3. Double-clique sur **`Clean.cmd`** et accepte la demande de droits administrateur. Un bilan s'affiche à la fin.

Chaque passage est noté dans `windows-disk-cleaner.log`, à côté du script. Les messages sont en français ou en anglais, selon la langue de Windows.

## Ce qu'il nettoie

| Étape | Quoi | Pourquoi c'est sûr |
|---|---|---|
| Caches de shaders NVIDIA des anciens pilotes | Fichiers de `%LOCALAPPDATA%\NVIDIA\DXCache` (et `LocalLow`) des pilotes précédents | Chaque mise à jour du pilote repart sur un nouveau cache et ne relit jamais l'ancien : il peut grossir de plusieurs Go à chaque mise à jour. Le cache du pilote actuel est conservé. |
| Fichiers d'installation de pilotes | Paquet gardé par la NVIDIA App, `C:\NVIDIA\DisplayDriver`, `C:\AMD` | Restes de pilotes déjà installés. Un pilote téléchargé mais pas encore installé est conservé. |
| Anciennes versions d'applis qui se mettent à jour seules | Dossiers `app-x.y.z` à côté d'un `Update.exe` (Discord, Slack…) | La version la plus récente et celle en cours d'utilisation sont conservées. |
| Caches des navigateurs | Chrome, Edge, Brave, Vivaldi, Opera, Firefox | Uniquement les caches : historique, mots de passe, cookies, extensions et données des sites sont conservés. Ignoré si le navigateur est ouvert. |
| Caches d'applis | Discord, Slack, cache web de Steam, cache web de l'Epic Games Launcher | Ignoré si l'appli est ouverte. |
| Éditeurs de code | VS Code, VS Code Insiders, Cursor : extensions téléchargées, caches internes, extensions obsolètes | Ignoré si l'éditeur est ouvert. |
| Caches de gestionnaires de paquets | npm, Yarn, pip, cache HTTP de NuGet | Reconstruits automatiquement au besoin. |
| Fichiers temporaires | `%TEMP%` et `C:\Windows\Temp`, de plus de 7 jours | Les fichiers en cours d'utilisation sont ignorés et les jonctions ne sont jamais suivies. |
| Rapports de plantage et d'erreurs | De plus de 14 jours | Ne servent qu'à analyser un plantage. |
| Windows | **Nettoyage de disque** de Windows (catégories sûres uniquement), anciens téléchargements de Windows Update, anciens journaux CBS, cache d'optimisation de distribution, `DISM /StartComponentCleanup` | Les outils de Microsoft eux-mêmes. |
| Déplacements *(optionnel, désactivé)* | Par exemple les gros installeurs des Téléchargements vers un autre disque | **Déplacés, jamais supprimés.** |
| Corbeille *(optionnel, désactivé)* | | |

Catégories du Nettoyage de disque utilisées : fichiers temporaires et d'installation, nettoyage de Windows Update, anciens paquets de pilotes, fichiers d'optimisation de distribution, cache de shaders DirectX, miniatures, rapports d'erreurs, fichiers de vidage mémoire, journaux et fichiers abandonnés des mises à niveau, fichiers temporaires de Microsoft Defender, journaux du Hub de commentaires, anciens fichiers de l'index de recherche, pages web hors connexion et fichiers de synchronisation temporaires. Une ancienne installation de Windows (`Windows.old`) n'est supprimée que si elle a plus de 30 jours.

## Ce qu'il ne touche jamais

Tes documents, photos, vidéos et téléchargements (sauf si tu ajoutes une règle de déplacement, et même là ils sont seulement déplacés), tes sauvegardes de jeux, les programmes et jeux installés, l'historique, les mots de passe et les cookies des navigateurs, le cache de shaders du pilote actuel, les versions de l'Historique des fichiers, les fichiers de Windows utilisés par « Réinitialiser ce PC », et la Corbeille sauf si tu l'actives.

Supprimer les anciens paquets de pilotes empêche le Gestionnaire de périphériques de « restaurer » un pilote à sa version précédente. Désactive `runDiskCleanup` si tu veux garder cette possibilité.

## Configuration

Tout fonctionne sans configuration. Pour personnaliser, copie `config.example.json` en `config.json` (à côté du script, ignoré par git) ou passe `-Config chemin\du\fichier.json`.

| Clé | Par défaut | Rôle |
|---|---|---|
| `tempAgeDays` | `7` | Âge minimum des fichiers temporaires à supprimer |
| `crashDumpAgeDays` | `14` | Âge minimum des rapports de plantage et d'erreurs à supprimer |
| `runDiskCleanup` | `true` | Lancer le Nettoyage de disque de Windows avec les catégories sûres |
| `runDism` | `true` | Lancer `DISM /StartComponentCleanup` (quelques minutes) |
| `emptyRecycleBin` | `false` | Vider la Corbeille |
| `steps` | tout à `true` | Désactiver une étape : `nvidiaShaderCache`, `driverInstallers`, `oldAppVersions`, `browserCaches`, `appCaches`, `codeEditors`, `packageCaches`, `tempFiles`, `crashDumps`, `windows` |
| `moveRules` | aucune | Fichiers à déplacer vers un autre disque (voir plus bas) |
| `extraCleanup` | aucun | Fichiers supplémentaires à supprimer (voir plus bas) |

**Les règles de déplacement** déplacent vers `destination` les fichiers de `folder` (par défaut ton dossier Téléchargements, noté `{Downloads}`) qui correspondent à `include`, dépassent `minSizeMB` et ont plus de `minAgeDays` jours. Une règle est ignorée si le disque de destination est absent.

```json
"moveRules": [
  { "name": "Gros installeurs", "enabled": true, "folder": "{Downloads}",
    "include": ["*.exe", "*.msi", "*.iso"], "minSizeMB": 200, "minAgeDays": 7,
    "destination": "D:\\Archives\\Installeurs" }
]
```

**Les nettoyages personnalisés** suppriment des fichiers (jamais des dossiers) qui correspondent à un chemin. Les jokers et les variables d'environnement sont acceptés ; les chemins trop proches de la racine d'un disque sont refusés.

```json
"extraCleanup": [
  { "name": "Tampon de replay d'un jeu", "path": "C:\\Jeux\\UnJeu\\tmp\\replay.bin", "minAgeDays": 0 }
]
```

## En ligne de commande

```powershell
powershell -ExecutionPolicy Bypass -File .\windows-disk-cleaner.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File .\windows-disk-cleaner.ps1 -Config D:\ma-config.json -Language fr
```

| Paramètre | Rôle |
|---|---|
| `-DryRun` | Montrer ce qui serait fait, sans rien changer |
| `-Config <fichier>` | Utiliser un fichier de configuration JSON |
| `-Language fr\|en` | Forcer la langue (par défaut : langue de Windows) |
| `-NoElevate` | Ne pas demander les droits administrateur (étapes Windows sautées) |
| `-NoPause` | Ne pas attendre Entrée à la fin |

## Prérequis

Windows 10 ou 11 avec Windows PowerShell 5.1 (inclus). Les droits administrateur ne servent qu'aux étapes Windows et au paquet de la NVIDIA App. Si ton compte n'est pas administrateur, les étapes du profil utilisateur s'appliquent au compte qui valide la demande.

## Avertissement

Fourni tel quel, sans garantie. Lance d'abord `Analyze.cmd` et lis ce qu'il indique.

## Licence

[MIT](LICENSE)
