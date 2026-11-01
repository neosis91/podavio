import {
  ChangeDetectionStrategy,
  Component,
  ElementRef,
  effect,
  inject,
  viewChild,
} from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';

import { ConnectPage } from './pages/connect-page.component';
import { PodavioSession } from './session.service';

@Component({
  selector: 'app-root',
  imports: [
    RouterOutlet,
    RouterLink,
    RouterLinkActive,
    MatButtonModule,
    MatIconModule,
    MatFormFieldModule,
    MatInputModule,
    ConnectPage,
  ],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AppComponent {
  readonly session = inject(PodavioSession);
  private readonly audio = viewChild<ElementRef<HTMLAudioElement>>('audio');

  constructor() {
    effect(() => this.session.attachAudio(this.audio()?.nativeElement ?? null));
  }
}
