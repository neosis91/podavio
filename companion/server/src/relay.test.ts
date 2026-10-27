import assert from 'node:assert/strict';
import test from 'node:test';

import { RelayHub, type Outbound } from './relay';

function capture(): { peer: Outbound; messages: unknown[] } {
  const messages: unknown[] = [];
  return { peer: { send: (json) => messages.push(json) }, messages };
}

test('joining the second peer tells both sides the connection id', () => {
  const hub = new RelayHub();
  const browser = capture();
  const phone = capture();
  hub.join('session', 'browser', 'browser-conn', browser.peer);
  assert.equal(browser.messages.length, 0);
  hub.join('session', 'phone', 'phone-conn', phone.peer);
  assert.deepEqual(browser.messages, [
    { type: 'peer', role: 'phone', conn: 'phone-conn' },
  ]);
  assert.deepEqual(phone.messages, [
    { type: 'peer', role: 'browser', conn: 'browser-conn' },
  ]);
});

test('hello and blob are forwarded without extra fields', () => {
  const hub = new RelayHub();
  const browser = capture();
  const phone = capture();
  hub.join('session', 'browser', 'b', browser.peer);
  hub.join('session', 'phone', 'p', phone.peer);
  browser.messages.length = 0;
  hub.forward('session', 'phone', {
    type: 'hello',
    pub: 'phone-pub',
    iv: 'iv',
    ct: 'cipher',
    secret: 'nope',
  });
  hub.forward('session', 'browser', {
    type: 'blob',
    n: 1,
    iv: 'iv2',
    ct: 'progress',
  });
  assert.deepEqual(browser.messages[0], {
    type: 'hello',
    pub: 'phone-pub',
    iv: 'iv',
    ct: 'cipher',
  });
  assert.deepEqual(phone.messages.at(-1), {
    type: 'blob',
    n: 1,
    iv: 'iv2',
    ct: 'progress',
  });
});

test('a replaced socket stops receiving and the room closes', () => {
  const hub = new RelayHub();
  const browser = capture();
  const phone = capture();
  hub.join('session', 'browser', 'b', browser.peer);
  hub.join('session', 'phone', 'p', phone.peer);
  hub.leave('session', 'phone', phone.peer);
  assert.deepEqual(browser.messages.at(-1), { type: 'bye', role: 'phone' });
  const before = phone.messages.length;
  hub.forward('session', 'browser', { type: 'blob', n: 1, iv: 'iv', ct: 'x' });
  assert.equal(phone.messages.length, before);
});
