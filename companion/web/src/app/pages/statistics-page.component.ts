import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { RouterLink } from '@angular/router';

import { PodavioSession } from '../session.service';

@Component({
  selector: 'app-statistics-page',
  imports: [MatButtonModule, MatCardModule, RouterLink],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <section class="library">
      <a mat-button class="back" routerLink="/library">{{ session.text('Library', 'Bibliothèque') }}</a>
      <h2>{{ session.text('Statistics', 'Statistiques') }}</h2>
      <ul class="stats">
        <li mat-card>
          <strong>{{ session.statCount('podcasts') }}</strong>
          <span>{{ session.text('Subscriptions', 'Abonnements') }}</span>
        </li>
        <li mat-card>
          <strong>{{ session.statCount('episodes') }}</strong>
          <span>{{ session.text('Episodes', 'Épisodes') }}</span>
        </li>
        <li mat-card>
          <strong>{{ session.statCount('favorites') }}</strong>
          <span>{{ session.text('Favorites', 'Favoris') }}</span>
        </li>
        <li mat-card>
          <strong>{{ session.statCount('downloads') }}</strong>
          <span>{{ session.text('Downloads', 'Téléchargements') }}</span>
        </li>
        <li mat-card>
          <strong>{{ session.statCount('playlists') }}</strong>
          <span>{{ session.text('Playlists', 'Playlists') }}</span>
        </li>
      </ul>
    </section>
  `,
})
export class StatisticsPage {
  readonly session = inject(PodavioSession);
}
