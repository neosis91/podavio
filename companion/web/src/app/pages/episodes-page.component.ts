import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { RouterLink } from '@angular/router';

import { EpisodeList } from '../episode-list.component';
import { PodavioSession } from '../session.service';

@Component({
  selector: 'app-episodes-page',
  imports: [MatButtonModule, RouterLink, EpisodeList],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <section class="library">
      <a mat-button class="back" routerLink="/library">{{ session.text('Library', 'Bibliothèque') }}</a>
      <h2>{{ session.text('Episodes', 'Épisodes') }}</h2>
      <app-episode-list [episodes]="session.libraryEpisodes()" [dated]="true" />
    </section>
  `,
})
export class EpisodesPage {
  readonly session = inject(PodavioSession);
}
