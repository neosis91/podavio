import { ChangeDetectionStrategy, Component, inject } from '@angular/core';
import { MatToolbarModule } from '@angular/material/toolbar';
import { RouterLink } from '@angular/router';
import { QRCodeComponent } from 'dfx-qrcode';

import { PodavioSession } from '../session.service';

@Component({
  selector: 'app-connect-page',
  imports: [MatToolbarModule, RouterLink, QRCodeComponent],
  templateUrl: './connect-page.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ConnectPage {
  readonly session = inject(PodavioSession);
}
