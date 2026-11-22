# Journal des versions

Chaque changement visible ajoute un fichier `changelog.d/*.md` :
une puce en anglais, une ou deux phrases. Le nom du fichier, en minuscules
et avec des tirets, fixe l’ordre. Quand la pull request est fusionnée dans
`develop`, ces fichiers sont rassemblés sous un titre `## AAAA.M.N`.
La fusion de `develop` dans `main` publie cette version.
`python3 tool/changelog.py collect` fait le même rassemblement.
Une pull request vers `develop` sans fragment porte `[skip changelog]`
dans son titre, ou l’étiquette `skip-changelog`.

## 2026.11.18

- A local context score, from silence, loudness, dynamic range, speech and chapters, confirms or rejects a fingerprint match and can propose a passage the fingerprint missed. - EfficientAT mn04 labels can be fused as extra evidence when the optional offline model is enabled. The app does not bundle a neural runtime.
- Repeated ads in downloaded episodes are matched with Olaf landmarks instead of Chromaprint, and a match is capped at 60 seconds. The start and end still snap to silence. - A new episode is compared with saved ad sequences first, and preview playback stops at the end of the detected passage.

- Settings include an Analysis management page that lists every podcast with at least one download, grouped by hosting source, with status and known ad, sting, sponsor, and outro counts. Automatic skip applies to the whole app, and a repeated portion longer than two minutes stays out of the comparison.


## 2026.11.17

- Ad ends extend to the next short silence, a repeated sting just after an ad is its own chapter, and an outro runs through to the end of the file. Content between detected segments keeps the podcaster's chapter titles, or is named Episode when the feed has none.

- Detected portions snap to a held silence on both the start and the end. A repeated sting of about three seconds anywhere in the first three minutes is its own chapter, even when each episode places it at a different time.

- Short network stings in the first three minutes are located with Olaf landmarks. The chapter keeps the log-mel window, so the start and the end stay the same, in about a second instead of about sixteen.



## 2026.11.16

- Analysis of downloaded episodes is faster and still runs off the main thread. Similar passages get a tighter start and end, and analysis slows down while audio is playing.

## 2026.11.15

- The analysis screen names the episode in progress, the current step, and an estimate of the time left.
- The player no longer shows a snackbar when it skips a passage. A button skips a passage whose automatic skip is off, and detected passages are merged into the chapter list.

## 2026.11.14

- Automatic fingerprinting no longer freezes the app. A long download is read in pieces, analysis stops after a timeout instead of retrying forever, and a setting turns automatic analysis off.

## 2026.11.13

- Downloaded episodes are fingerprinted after the file is saved. Repeated ads, sponsors, and jingles in the same podcast show up for review, and the classification screen can analyze episodes already on the phone.

- Short jingles in downloaded episodes are matched with a log-mel template, and a repeated network sting can mark the ad block around it. The classification screen labels that block as a network sting.

- Repeated music inside a single downloaded episode, such as a refrain or a background bed, is no longer listed as a skip. A spoken repeat in that episode stays for review, and a low score stays behind Show uncertain passages. A jingle or outro shared by several episodes is still detected when it is musical.



## 2026.11.12

- Downloaded episodes can skip confirmed ad, sponsor, and jingle passages. The review is in the podcast settings, and a chapter title that looks like an ad is suggested on its own. Detecting those passages from the audio is not active yet.

## 2026.11.11

- Changelog fragments are gathered when a pull request is merged into develop. The develop to main merge publishes that version.

- A develop to main merge publishes notes that arrived after that version was already released, as the next version.


## 2026.11.10

- Importing a database no longer closes the app when podcast covers were about to be downloaded, or while a cover download was already running.
- Podcast and episode titles sit under the cover, and the artwork is no longer faded at the bottom.
- The download progress keeps every episode in the batch until the batch ends, and the count changes when an episode is added or removed. A failed download keeps the part already received and is shown in the count. An automatic download skipped on mobile data stays in that count.
- Download notifications show how many episodes are already saved out of the batch. The notification button shows how many are still left.
- Unfinished audio is dropped when a download is cancelled or its podcast is removed, and a replaced episode is fetched again instead of being mixed with the old file.
- Merging develop into main gathers the changelog fragments and publishes that version.
- A failed download keeps the audio already received and continues from there on the next attempt.
- Failed downloads stay in Notifications and can be retried, all at once or one by one.
- A streamed episode that loses its connection while it is being cached, for example when the phone moves from Wi-Fi to mobile data, no longer closes the app. The partial file is not kept as a finished download.

## 2026.11.9

- Activity counts an episode on the day it was marked played, including when that mark did not move the playback position. A listen under a minute is shown in seconds. Busiest and calmest compare only days, months, or weekdays that have listening. A single listening level is not also called the calmest.
- The first download, the first refresh, and the first stream on mobile data each ask before they start. The dialog can allow it once, or remember the choice and turn on the matching network setting. Turning automatic downloads on, or changing their limit, asks the same question when downloads are set to Wi-Fi only and the phone is on mobile data. Cancel leaves the switch off. The new limit is kept. A later automatic run stays quiet and does not ask.
- First-time setup is three steps: an OPML import, then episode downloads, streaming, and refresh with the same Wi-Fi or mobile choice as in Settings, then Eco mode. The step that asked whether to stream or download is gone. Restore backup offers Back and Restore backup, so that step cannot finish without a backup. Turning Eco mode off returns pure black to the setting it had before Eco mode was turned on. An install that was already in Eco mode, with no saved previous value, keeps pure black.
- Listening language follows the phone until a choice is saved, and it updates when the phone language changes. On the listening-language page, System returns to that. Turning off All languages with no remembered pick uses the phone language, or English when that language is not in the catalog. Known languages use their own name, such as Deutsch or English. The country in a variant stays the catalog wording, as in Deutsch (Allemagne). A saved choice, including All languages, stays until it is changed. An install that never saved a listening language follows the phone on the next launch.
- Exporting the database writes the file in pieces, so a large library no longer stops the phone. Import copies the file the same way. The page states what the file holds: subscriptions, playlists, chapters, playback, and per-podcast settings. Audio files and app settings stay on the phone. A downloaded episode stays when its file is still on the phone. Turning automatic export on writes a backup immediately. The folder can be changed without turning the option off. A failed automatic backup is listed in notifications. Automatic files are named PodavioAuto, with the date and time, and only those files are trimmed to the five most recent. A manual export keeps the PodavioBackup name, also with the time, so two exports on the same day do not share a name. OPML import messages follow the interface language. The HTML export of subscriptions has its own title.

## 2026.11.8

- Library statistics open on Activity. A card shows the total listening time and, when tapped, the months that have listening. With no daily streak, a banner invites a first listen. Daily and weekly streaks follow. This week is a dot per day, Monday through Sunday. This year is a bar per month. Each card names its busiest and quietest days or months. A heatmap fills the current half of the year. Below it, the six most listened categories and the most and least popular weekdays. An episode counts on the day it was last played, and only the first category of its podcast is counted.
- The six library cards use the application background, including pure black. Playlist is blue. Cache stays orange.
- On episode lists, a cached episode shows an orange folder. An episode in a playlist shows the playlist icon in that same blue.
- In Settings, under Miscellaneous, a GitHub row reads Contribute to the project and opens the project page.

## 2026.11.7

- Notifications open on their own page. Each notice is a card, with the list centered. A running download or refresh shows its progress on the card. A finished notice is dismissed by swiping it away. There is no close button. When the last notice goes away, the page goes back. Opening the page while it is already empty leaves it open and says there are no notifications.
- A group of downloads is one notice, in the system tray and on that page. One refresh that finds new episodes on several podcasts is one notice too, with one line per podcast and at most twelve lines. A sync failure is one notice, and the same text is on the page. The system tray still follows the notification switches. The page records a finished download batch even when those switches are off. Cancelling a batch leaves no result.
- Back closes the frontmost bottom sheet before leaving the page. A second sheet closes only the top one. A dialog sitting on a sheet closes first, and the sheet stays.
- A Wear OS watch can remote-control the phone. The watch shows the episode title and the podcast, play and pause, skip back, and skip forward, then Playlist, Unread, and Downloads. Choosing a row plays that episode on the phone. While audio plays, the watch face keeps an ongoing activity. The sound, the files, and the library stay on the phone. The GitHub release adds a separate watch package. A phone build without that option, including F-Droid, does not include the watch connection.

## 2026.11.6

- In the big player, cast, playback speed, and the sleep timer sit in the top bar, to the left of the menu. Speed and the sleep timer are no longer in the episode menu. Cast uses a cast icon, the timer a moon, and audio effects a sliders icon.
- The playback speed sheet has a switch, minus and plus around the value, and a slider from 0.4× to 7.0×. The step is 0.01, 0.05, 0.1, 0.25, or 0.5. Ok applies the speed. Cancel leaves it unchanged.
- The sleep timer sheet asks for a duration in minutes or hours, with shortcuts of 5, 15, 30, and 45 minutes. It can also stop at the end of the episode, or at the next chapter when the episode has chapters. Start begins the timer. Cancel leaves it unchanged.
- The playback speed, sleep timer, and audio effects sheets use the app colors, including when the player is tinted by the cover.
- The GitHub release adds a Debian package, `podavio-*-linux-amd64.deb`, for Debian, Ubuntu, and derivatives, and a Windows zip, `podavio-*-windows-x64.zip`, that runs without installing. The Windows installer and the Linux archive stay.

## 2026.11.5

- In the big player, a swipe that starts while the queue is scrolled only moves the list, including when the finger reaches the top. Closing the queue is a downward swipe that starts at the top of the list and follows the finger.
- Playing from a podcast page orders the queue from oldest to newest. Previous holds the older episodes and Up next the newer ones. Reversing the list on the podcast page no longer reverses that queue.
- The big player has an audio effects button between notes and audio output. The sheet sets amplification, a volume stabilizer, mono, and silence removal. Silence removal has an efficiency: Low, Medium, High, Very high, or Extreme. The choices are kept. On Android, amplification raises the level and silence removal skips quiet stretches. The efficiency steps, the volume stabilizer, and mono are stored and do not change the sound yet.
- Opening a library that already has a column or table the upgrade would add no longer fails. The upgrade skips what is already there.
- Publishing a release updates the download files. The version notes on podavio.com are read from this file on GitHub.

## 2026.11.4

- The update dialog compares the installed version with the latest GitHub release.
- Opening an existing library adds the missing automatic-download limit, so that check no longer fails.
- An empty screen scrolls when its message is taller than the window.
- Crashes are reported to Sentry, with the installed version on a release build. Only the opening of the app is traced. A local run reports nothing unless it was started with the Sentry address.
- Android requires Android 8. A release build uploads the Android code map and the Linux and Windows debug files, so a crash can be read back to the original source.

## 2026.11.3

- The GitHub release includes one Windows file, an .msi installer. Opening it installs Podavio for the current user and adds a Start menu shortcut.

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
