import { ChangeDetectionStrategy, Component, inject, input } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';

import { LibraryEpisode, PodavioSession } from './session.service';

@Component({
  selector: 'app-episode-list',
  imports: [MatButtonModule, MatIconModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (episodes().length === 0) {
      <p class="empty">{{ empty() || session.text('Nothing here', 'Rien ici') }}</p>
    } @else {
      <ul class="library-list">
        @for (episode of episodes(); track episode.id) {
          <li class="episode-line">
            <button
              type="button"
              class="episode"
              [class.current]="session.playing()?.id === episode.id"
              (click)="session.play(episode, false)"
            >
              <strong>{{ episode.title }}</strong>
              <span>{{ dated() ? episode.podcastTitle + ' · ' + session.formatWhen(episode.publishedAt) : episode.podcastTitle }}</span>
            </button>
            <button
              mat-icon-button
              type="button"
              class="row-more"
              [attr.aria-label]="session.text('Actions', 'Actions')"
              (click)="session.openActions(episode)"
            >
              <mat-icon>more_vert</mat-icon>
            </button>
          </li>
        }
      </ul>
    }
  `,
})
export class EpisodeList {
  readonly session = inject(PodavioSession);
  readonly episodes = input.required<LibraryEpisode[]>();
  readonly dated = input(false);
  readonly empty = input('');
}
