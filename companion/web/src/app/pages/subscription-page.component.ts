import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';

import { PodavioSession } from '../session.service';

@Component({
  selector: 'app-subscription-page',
  imports: [MatButtonModule, MatIconModule],
  templateUrl: './subscription-page.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SubscriptionPage {
  readonly session = inject(PodavioSession);
}
