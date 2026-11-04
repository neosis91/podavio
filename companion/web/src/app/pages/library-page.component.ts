import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { RouterLink } from '@angular/router';

import { PodavioSession } from '../session.service';

@Component({
  selector: 'app-library-page',
  imports: [MatButtonModule, MatIconModule, RouterLink],
  templateUrl: './library-page.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class LibraryPage {
  readonly session = inject(PodavioSession);
}
