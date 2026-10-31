import { ChangeDetectionStrategy, Component } from '@angular/core';
import { Routes } from '@angular/router';

@Component({
  selector: 'app-route-slot',
  template: '',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class RouteSlot {}

export const routes: Routes = [
  { path: '', pathMatch: 'full', component: RouteSlot },
  { path: 'home', component: RouteSlot },
  { path: 'subscriptions', component: RouteSlot },
  { path: 'subscriptions/:podcastId', component: RouteSlot },
  { path: 'library', component: RouteSlot },
  { path: 'library/favorites', component: RouteSlot },
  { path: 'library/episodes', component: RouteSlot },
  { path: 'library/downloads', component: RouteSlot },
  { path: 'library/playlists', component: RouteSlot },
  { path: 'library/playlists/:playlistId', component: RouteSlot },
  { path: 'library/statistics', component: RouteSlot },
  { path: '**', redirectTo: '' },
];
