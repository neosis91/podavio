import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { RouterLink } from '@angular/router';

import { PodavioSession } from '../session.service';

@Component({
  selector: 'app-subscriptions-page',
  imports: [RouterLink],
  templateUrl: './subscriptions-page.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class SubscriptionsPage {
  readonly session = inject(PodavioSession);
}
