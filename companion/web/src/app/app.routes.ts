import { Routes } from '@angular/router';

import { CachePage } from './pages/cache-page.component';
import { ConnectPage } from './pages/connect-page.component';
import { DownloadsPage } from './pages/downloads-page.component';
import { EpisodesPage } from './pages/episodes-page.component';
import { FavoritesPage } from './pages/favorites-page.component';
import { HomePage } from './pages/home-page.component';
import { LibraryPage } from './pages/library-page.component';
import { PlaylistPage } from './pages/playlist-page.component';
import { PlaylistsPage } from './pages/playlists-page.component';
import { StatisticsPage } from './pages/statistics-page.component';
import { SubscriptionPage } from './pages/subscription-page.component';
import { SubscriptionsPage } from './pages/subscriptions-page.component';

export const routes: Routes = [
  { path: '', pathMatch: 'full', component: ConnectPage },
  { path: 'home', component: HomePage },
  { path: 'subscriptions', component: SubscriptionsPage },
  { path: 'subscriptions/:podcastId', component: SubscriptionPage },
  { path: 'library', component: LibraryPage },
  { path: 'library/favorites', component: FavoritesPage },
  { path: 'library/episodes', component: EpisodesPage },
  { path: 'library/downloads', component: DownloadsPage },
  { path: 'library/cache', component: CachePage },
  { path: 'library/playlists', component: PlaylistsPage },
  { path: 'library/playlists/:playlistId', component: PlaylistPage },
  { path: 'library/statistics', component: StatisticsPage },
  { path: '**', redirectTo: '' },
];
