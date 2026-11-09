# Journal des versions

Avant une release, ajoutez un titre `## AAAA.M.N` et une puce par changement.
`tool/release_local.sh` refuse de publier si ce titre manque.
La section `## Non publié` sert de brouillon : elle n’est pas publiée.

## 2026.11.2

- The podcast page opens on the full square cover. Scrolling past it shows a frosted bar with the show name. Back, the preferred star, and the menu sit below the status bar. The episode list can be reversed, and that order is kept for the show. Play starts the first episode of that order. The third button is Subscribe, or automatic downloads once the show is subscribed. Its icon is green while automatic download is on. The description shows three lines, with Plus and Moins for the rest.
- The episode page opens on the cover, with a heart for the favorite. Under the cover: add to playlist, mark as played or unplayed, play, download, and share. The description folds the same way. Below it, a shelf shows this episode’s podcast and opens its page.
- A downloaded episode uses one green mark on lists, on the episode page, and in the action sheet. It is the same green as an active automatic download.
- The dark buttons on a podcast or episode cover use one slate fill.
- The six library cards, from Favorites through Statistics, keep their color on the border, the label, and the icon. The card background is white in the light theme and black in the dark theme. Downloads uses the downloaded-episode icon, in that green. Favorites uses the heart red.
- Playback settings include list density, Comfortable or Compact. Compact tightens episode rows and the queue in the player. The default is Comfortable. The horizontal shelves on Home stay cards.
- Add to playlist, which adds an episode to the playlist when its download finishes, is in Download manager, above Remove from playlist.
- Search ignores accents and letter case in podcast and episode titles.
- A category page lists the podcasts in that category and does not show a rank. The ranked list remains on the suggestions page.
- In Preferences, Podavio Web is the first item under Miscellaneous. The home button uses the phone-and-screen icon.
- Scanning a Podavio Web code uses the phone camera. The previous barcode library is gone.
- Merging develop into main builds the Android APKs and the Linux archive and attaches them to the GitHub release. The app and the download page use those file links when the release has them.

## 2026.11.1

- Automatic download is off for every podcast, including ones that had it on. A page lists the current subscriptions in alphabetical order. Under the name, the row shows the episode limit, and a download icon when automatic download is on. The row, its menu, and the podcast page open one sheet: a switch, a short explanation, and the limit. The default limit is 1 episode. Only the newest unplayed or in-progress episodes are downloaded, up to that limit. Finished episodes are skipped, and turning it off keeps files already on the device.
- A notifications button sits to the left of the tab bar, the same size and gap as search, and on the desktop rail. It replaces the banners for no connection, downloads, refresh, and OPML import. The sheet uses that banner’s color and shows the text. No connection comes first. A download in progress comes before a refresh. On the button, download and refresh draw a progress ring on the edge, with the remaining episode count or the remaining podcast count under the icon. Messages that used to appear at the bottom of the screen are listed there and can be closed. A successful OPML import disappears after a few seconds. Errors stay until they are closed.
- A refresh waits while downloads are running, so the two do not use the network together. Downloads are not paused for a refresh.
- Pull to refresh on a podcast page, the subscriptions page, and episode lists starts below the frosted bar, including the filter chips.
- Swiping down in the big player shrinks it with the finger. Swiping down in the queue does the same once the list is at the top, and returns to the big player. A short swipe leaves it open. If the queue is scrolled, the swipe scrolls the list first.
- Previous and next in the big player use the filled skip icons.
- Episode lists filter with chips under the title: Unplayed, Downloaded, and In progress. The filter dialog is gone. The menu can still mark every episode as played. While selecting, the menu can mark the selection played or unplayed.
- The library has an Episode cache, on the phone and in Podavio Web. From that list, cached episodes can be downloaded or added to favorites. Downloading an episode that is only cached keeps the cached file instead of fetching it again.
- On Home, a category can keep only some of its subjects. Chips show the ones that stay. A tap removes a subject. With one subject left, a tap opens the sheet to add more. The list uses the genres stored from each feed.
- Titles, authors, descriptions, and chapter names that were saved with the wrong encoding, so é appeared as Ã©, are repaired.
- A debug or profile install is named Podavio debug and can stay installed next to the published app.
- First-time setup no longer turns automatic download on for every subscription.

## 2026.11.0

- A downloaded episode plays from the file on the phone. Wi-Fi limits, mobile data, and a missing connection apply only to a remote stream. If the player cannot open the file directly, it uses a local copy.
- In the big player, the queue can scroll up into Previous episodes when Up next is short and Previous is long. The list stops growing once it no longer gets taller.
- Importing a library backup drops the open library reads before replacing the database, so the progress indicator can finish. Download and cover paths whose files are gone are cleared. Paths that are still on the device stay, and listening progress is kept. Missing covers can be fetched again.
- Scanning the Podavio Web code opens the camera in the compiled release.
- Podavio Web on the phone separates linked devices from scanning. The linked device shows the browser, the operating system, and their logos. The scan page fills the screen under the instruction, with a light shade and a clear square in the center.
- Disconnecting from the phone or the browser ends the link. Closing the browser or losing the connection marks the browser offline and keeps the link.
- Podavio Web is split into pages that share one header. The QR code is the page at https://web.podavio.com. Home, subscriptions, and the library (Favorites, Episodes, Downloads, Playlists, Statistics) have their own addresses. The code is drawn as an SVG and appears again after the browser is unlinked.
- The browser mini player matches the phone mini player. A favorite, a playlist change, or a download started in the browser runs on the phone.

## 2026.10.24

- First-time setup ends with Eco mode. Turning it on skips new cover downloads and keeps the dark theme and pure black on. It can stay off, and Settings can change it later.
- Restoring a database from the welcome screen no longer warns that the library will be replaced. Backup and restore in Settings still asks. The import no longer waits on an open database read, so the progress indicator closes instead of spinning.
- Podavio Web places the pairing title, the introduction, the steps, and the QR code in one card. The browser address is https://web.podavio.com.
- The home header opens Podavio Web with a QR code icon. The phone scans the code shown at https://web.podavio.com on a computer. Listen together is removed from the home header and the player.

## 2026.10.23

- Automatic download now fetches eligible episodes, within the per-podcast limit and the episode cache. It starts when the app opens, after a refresh or a new subscription, and when the option is turned on.
- Parallel downloads, in Download manager, caps how many files download at once, including ones started by hand. The choices are 1, 2, 3, 4, and 5, and the default is 2. A banner at the top shows how many are running and how many are waiting.
- The refresh and OPML import banners close on their own a few seconds after they finish. Opening the error list holds the banner until it is closed.
- Refreshing subscriptions and importing several feeds now handles 2 podcasts at a time.

## 2026.10.22

- Eco mode, from the home header or Settings, skips new cover downloads, the automatic cover fetch, and the tint fetch. Saved or cached covers stay, with a small leaf in the bottom left corner. Missing covers become a square filled with a color generated from the podcast name, with the same corners. The full name is written in white and kept to a modest size so it still fits in the square. In small lists the leaf sits in the center. Turning Eco mode on forces the dark theme and pure black, and neither can be turned off while Eco mode is on.
- On a podcast page, Eco mode keeps a black background.
- The first time the library is empty, a welcome screen offers setup, restoring the library from a database backup, or continuing without setup. Setup walks through an OPML import, mobile data for streaming and downloads, then streaming or automatic download with a per-podcast limit.

## 2026.10.21

- Podavio Web pairs the phone with a browser through a self-hosted relay. The library and playback position are encrypted end to end. The browser plays the episode from its remote address, and an Android notification keeps the phone reachable.
- In Download manager, Download limit caps how many episodes an automatic download fetches per podcast. The choices are unlimited, 1, 2, 3, 4, 5, 10, 20, 50, 100, 200, and 500. Episodes already downloaded and still unplayed count toward the limit. A download started by hand is not capped.
- Settings opens a Network page. Under Data usage, episode downloads, streaming, and refresh can each stay on Wi-Fi only or also use mobile data.
- Settings opens a Language page under Refresh all subscriptions. Interface language and listening language live there, no longer under Interface and Explore. Each row shows the flags of the selected languages.
- In Explore, the language button opens listening language, with the same icon as in Settings.
- Settings are grouped under Advanced (Interface, Playback, Synchronization, Notifications, Download manager, Network, Backup and restore) and Miscellaneous (Share Podavio nearby, About).
- On a podcast page, Play or Pause and the episode count sit on the cover, with Subscribe and About in the top right corner. The fade at the bottom of the cover is replaced by a light shadow.
- On a podcast page, a long title scrolls instead of shrinking.
- On a podcast page, the last episodes are no longer hidden behind the mini player and the navigation bar. The podcast menu opens above them.
- On a podcast page, an episode menu no longer offers a link to that same podcast.
- With pure black on, the mini player, the navigation bar, and the search button have a light outline.

## 2026.10.20

- On Android, Settings includes Share Podavio nearby. Over the same Wi-Fi or a phone hotspot, a QR code opens a page to download and install Podavio with no internet. Sharing stops when you leave the screen or switch apps.
- In Backup and restore, Database can export or import the full library database, and optionally save a copy every 3 days (keeps the 5 most recent). Downloaded audio files are not included.
- On Home, a category opens a numbered podcast list. Each chip is a regroupement of related catalog genres; only the category title is shown, not subcategory tags. Scrolling loads more podcasts, with a loading indicator at the bottom.
- Explore and Home categories hide podcasts you already follow.
- On a podcast page, the background follows the cover’s average color. The episode count sits above the action pills. The copyright, title, and year line under the cover is gone.
- In episode lists, a long title scrolls horizontally so you can read it in full.

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
