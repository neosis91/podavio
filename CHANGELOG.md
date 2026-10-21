# Journal des versions

Avant une release, ajoutez un titre `## AAAA.M.N` et une puce par changement.
`tool/release_local.sh` refuse de publier si ce titre manque.
La section `## Non publié` sert de brouillon : elle n’est pas publiée.

## 2026.10.20

- On Android, Settings includes Share Podavio nearby. Over the same Wi-Fi or a phone hotspot, a QR code opens a page to download and install Podavio with no internet. Sharing stops when you leave the screen or switch apps.

## 2026.10.19

- On episode lists, a long press starts multi-select. A frosted bar replaces the title with select or deselect all, and a menu for bulk actions when there are any.
- On a podcast page, Play and Pause sit in a pill that fits the label. The full podcast name stays in the title. The menu opens as a bottom sheet.
- Playing from a podcast list queues toward newer episodes. The list matches Favorites and Downloads. Download progress stays next to the episode, not on the cover.
- Preferred subscriptions show a star and sort first.
- On a podcast’s About page, hosts and other people from the feed appear, with funding links when the feed provides them.
- In Backup and restore, HTML export shares subscriptions or favorites as a page to open or send. Re-import is not supported.

## 2026.10.18

- Sur Android, l’application s’ouvre de nouveau après le logo de démarrage.

## 2026.10.17

- Sur l’accueil, la salutation suit la langue de l’interface : Bonjour, Bon après-midi, Bonsoir ou Bonne nuit. « Lectures récentes » aussi.
- Le haut des pages se voile un peu quand on fait défiler, comme sur l’accueil.
- Dans les favoris, une playlist, la page d’un podcast et la liste des épisodes, un bouton lecture lance le premier épisode.
- Lancer un épisode au milieu d’une longue liste prépare la suite. Les épisodes d’avant arrivent en remontant dans la file d’attente du lecteur, sans tout charger d’un coup.
- Dans Écoutons ensemble, une personne qui a rejoint voit le nom de la session et combien de personnes écoutent.
- En bas de l’écran, Accueil, Abonnements et Bibliothèque ont un peu d’air autour du texte, et la même taille de lettres.
- Sur Linux, le fin trait clair sous le titre de la fenêtre a disparu.
- Dans Abonnements, les filtres sont des pastilles sous le titre. Un appui active ou retire le compteur, les téléchargements automatiques et la mise à jour.
- Dans Explorer, à la place des réglages, un globe ouvre le choix des langues.
- Cette page a le même titre que l’accueil : il se voile en défilant, et la recherche est dedans. Les langues choisies sont des pastilles avec leur drapeau. La liste montre un drapeau rond quand la langue en a un, par exemple le breton, le corse ou le wallon. Le début de la liste n’est plus caché sous le titre.
- Dans Interface, Langue a le même aspect : titre qui se voile, recherche dans le titre, pastille de la langue choisie et drapeaux. Une seule langue peut être choisie, avec un rond à cocher.
- L’application s’ouvre tout de suite, sans écran d’attente. Sur Android et sur iPhone, le logo reste affiché le court instant du démarrage.

## 2026.10.16

- Dans Préférences, Synchronisation relie Podavio à gPodder ou à gPodder Sync (Nextcloud). Les abonnements et la progression d’écoute se partagent avec les autres appareils. D’autres fournisseurs peuvent s’ajouter.
- Dans Gestion des téléchargements, le téléchargement automatique est éteint. L’activer inclut tous les abonnements ; chacun peut ensuite être exclu, et le couper conserve ces choix. Le cache d’épisodes part d’illimité. On peut supprimer le fichier à la fin de la lecture, et choisir quand libérer de la place si le cache est plein. Les favoris restent.
- Dans Gestion des téléchargements, les données mobiles sont coupées. Le téléchargement automatique attend le Wi-Fi. Un téléchargement lancé à la main demande confirmation avant d’utiliser les données mobiles. L’activer autorise les deux.
- Sur l’accueil, entre Lectures récentes et Préférences, Écoutons ensemble ouvre une session sur le même Wi-Fi. Le même bouton reste dans le lecteur. Le code se partage à côté. Les autres rejoignent sans ouvrir le grand lecteur : lecture, pause, position et vitesse restent alignées. En quittant, chacun retrouve sa vitesse.
- Dans Préférences, Notifications reste silencieux. L’utilisateur active la progression d’un téléchargement, les erreurs de téléchargement, les erreurs de synchronisation, ou les nouveaux épisodes. « Prévenir des nouveaux épisodes » inclut tous les abonnements ; chacun peut ensuite être coupé, et le couper conserve ces choix.
- Dans Lectures récentes, lancer un épisode enchaîne ensuite la file d’attente, dans son ordre. Si l’épisode n’y est pas, le suivant est le premier de la file.
- Dans Interface, la teinte de la pochette est activée. Le lecteur et le haut de l’accueil suivent la pochette. La couper les laisse sur la couleur du thème. Les étagères de l’accueil se masquent et se réordonnent. Si elles sont toutes masquées alors qu’il y a quelque chose à montrer, l’accueil propose d’ouvrir Interface.
- Sur l’accueil, des pastilles s’affichent sous le titre. « Tout » montre l’accueil. Les autres proposent des podcasts d’un genre des catalogues, auxquels on n’est pas abonné : une rangée Apple Podcasts, une Podcast Index, une fyyd. Sans choix enregistré, ce sont les huit genres les plus présents dans les classements du mois, et Histoire reste affichée. Dans Interface, Catégories permet de les afficher, de les masquer et de les réordonner. Ce choix remplace ensuite le classement.

## 2026.10.15

- Dans Interface, Langue ouvre une page. Chaque langue affiche son code. « Système » est placé sous la langue du téléphone, avec le même code. Si cette langue n’est pas proposée, « Système » n’apparaît pas. Sans choix enregistré, l’application suit la langue du téléphone quand elle est disponible, sinon l’anglais.
- L’interface peut passer en allemand, espagnol, italien, portugais, néerlandais, chinois, hindi, indonésien, japonais, coréen, russe, turc, arabe et polonais. L’arabe se lit de droite à gauche. Les dates suivent la langue choisie.
- Dans Préférences, Explorer choisit les langues des podcasts. Sans choix enregistré, Explorer part de toutes les langues. « Toutes les langues » interroge les catalogues sans filtre. La liste couvre les langues courantes et les variantes par pays, dont l’arabe. Apple ouvre la boutique du pays quand elle existe.
- Le mini lecteur ne recouvre plus le bas des pages. Le dernier élément d’une liste reste lisible.
- Sans internet, un bandeau l’indique. L’accueil, la bibliothèque et les épisodes déjà là restent ouverts. Explorer attend la connexion, et l’actualisation des abonnements aussi.
- Lors d’une publication, si l’envoi vers podavio.com ne lance pas le déploiement, celui-ci est démarré.
- Dans Explorer, Langues regroupe les variantes par pays sous chaque langue. Les langues choisies restent en pastilles. « Toutes les langues » se coupe en retrouvant le choix précédent. Apple prévient quand plus de 8 boutiques seraient nécessaires.
- Dans À propos, on vérifie la mise à jour de l’application. Le moment de la dernière vérification s’affiche sous cette ligne.

## 2026.10.14

- La bibliothèque a une carte Playlists. On peut en créer, les renommer et les supprimer. « Playlist », marquée Par défaut, reprend la file d’attente.
- Le menu d’un épisode permet de l’ajouter à une ou plusieurs playlists.
- Dans le grand lecteur, la file d’attente sépare les épisodes déjà passés et ceux à suivre. On peut les réordonner. Sur un grand écran, la feuille est plus large.
- Un appui long, puis un glissement vers le bas, referme le grand lecteur et la file d’attente.
- Le grand lecteur a le même menu d’actions que les listes. La vitesse et le minuteur y sont, avec le mode voiture et le site du podcast.
- Pendant un téléchargement, le pourcentage s’affiche à côté de « Téléchargement ».
- Les cœurs des épisodes aimés sont rouges.
- Le mini lecteur est une pastille. Par défaut : le cœur et lecture / pause. Dans Lecture, « Gestion des boutons » permet d’ajouter le retour, l’avance, l’épisode suivant et fermer, et de changer leur ordre. Lecture / pause reste toujours affiché.
- Dans le grand lecteur, les boutons vont de gauche à droite : épisode précédent, retour, lecture, avance, épisode suivant.
- Entre les temps, le débit et la fréquence s’affichent quand ils sont connus, par exemple « 154 kbps · 48 kHz ».
- Le casque ouvre Sortie audio : l’appareil en cours, les Chromecast du réseau, et le volume. Pendant un Cast, le casque est bleu. L’épisode doit être accessible par une adresse internet.
- En bas du grand lecteur : les notes et la sortie audio à gauche, les chapitres et la file d’attente à droite.

## 2026.10.13

- La mise en ligne sur podavio.com part de la version déjà publiée du site. Une copie locale modifiée n’empêche plus la publication.

## 2026.10.12

- Sur l’accueil, le haut de la page se voile un peu quand on fait défiler. Un bouton, à côté des réglages, ouvre les lectures récentes.
- L’accueil propose aussi vos favoris et les épisodes écoutés récemment. « Continuer d’écouter » s’affiche en lignes plus courtes.
- La page Lectures récentes rassemble les épisodes déjà lancés.
- Dans la bibliothèque, Favoris, Épisodes et Téléchargements sont trois cartes colorées. La liste des lectures récentes est juste en dessous.
- Les trois points d’une lecture récente permettent d’aimer l’épisode, de le télécharger, de le lire juste après, de l’ajouter à la playlist, d’ouvrir le podcast ou de le partager.
- Dans le lecteur, on peut monter, descendre ou retirer un épisode de la playlist.
- Le lecteur reprend la couleur de la pochette.
- Les statistiques sont dans Préférences.
- Explorer montre 16 podcasts. « Découvrir plus » en charge d’autres à mesure qu’on descend dans la liste.
- Une fenêtre prévient quand une nouvelle version est en ligne sur podavio.com, et propose de la télécharger.
- En bas de l’écran : Accueil, Abonnements et Bibliothèque. La loupe ouvre Explorer.

## 2026.10.11

- Fichiers Android et Linux disponibles sur podavio.com.
