import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { RouterLink } from '@angular/router';

import { PodavioSession } from '../session.service';

@Component({
  selector: 'app-playlists-page',
  imports: [MatButtonModule, RouterLink],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <section class="library">
      <a mat-button class="back" routerLink="/library">{{ session.text('Library', 'Bibliothèque') }}</a>
      <h2>{{ session.text('Playlists', 'Playlists') }}</h2>
      @if (session.playlists().length === 0) {
        <p class="empty">{{ session.text('No playlists', 'Aucune playlist') }}</p>
      } @else {
        <ul class="library-list">
          @for (playlist of session.playlists(); track playlist.id) {
            <li>
              <a class="episode" [routerLink]="['/library/playlists', playlist.id]">
                <strong>{{ playlist.name }}</strong>
                <span>{{ playlist.episodeIds.length }}</span>
              </a>
            </li>
          }
        </ul>
      }
    </section>
  `,
})
export class PlaylistsPage {
  readonly session = inject(PodavioSession);
}
