const salt = new TextEncoder().encode('podavio-web-v1');
const info = new TextEncoder().encode('podavio-web-session');

export function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/g, '');
}

export function base64ToBytes(value: string): Uint8Array {
  const pad = value.length % 4 === 0 ? '' : '='.repeat(4 - (value.length % 4));
  const binary = atob(value.replaceAll('-', '+').replaceAll('_', '/') + pad);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

export function aad(role: string, conn: string, counter: number): Uint8Array {
  return new TextEncoder().encode(`${role}:${conn}:${counter}`);
}

export async function safetyNumber(pwaPub: Uint8Array, phonePub: Uint8Array): Promise<string> {
  const both = new Uint8Array(pwaPub.length + phonePub.length);
  both.set(pwaPub, 0);
  both.set(phonePub, pwaPub.length);
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', both));
  const hex = [...digest.slice(0, 10)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
    .toUpperCase();
  return hex.match(/.{4}/g)?.join(' ') ?? hex;
}

export async function createPwaKeys(): Promise<CryptoKeyPair> {
  return crypto.subtle.generateKey({ name: 'X25519' }, true, ['deriveBits']) as Promise<CryptoKeyPair>;
}

export async function exportRaw(key: CryptoKey): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.exportKey('raw', key));
}

export async function exportPrivate(key: CryptoKey): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.exportKey('pkcs8', key));
}

export async function importPrivate(raw: Uint8Array): Promise<CryptoKey> {
  return crypto.subtle.importKey('pkcs8', raw as BufferSource, { name: 'X25519' }, true, ['deriveBits']);
}

export async function deriveSessionKey(privateKey: CryptoKey, phonePub: Uint8Array): Promise<CryptoKey> {
  const remote = await crypto.subtle.importKey(
    'raw',
    phonePub as BufferSource,
    { name: 'X25519' },
    true,
    [],
  );
  const shared = await crypto.subtle.deriveBits(
    { name: 'X25519', public: remote },
    privateKey,
    256,
  );
  const hkdfKey = await crypto.subtle.importKey('raw', shared, 'HKDF', false, ['deriveKey']);
  return crypto.subtle.deriveKey(
    { name: 'HKDF', hash: 'SHA-256', salt: salt as BufferSource, info: info as BufferSource },
    hkdfKey,
    { name: 'AES-GCM', length: 256 },
    false,
    ['encrypt', 'decrypt'],
  );
}

export async function seal(
  key: CryptoKey,
  plain: Uint8Array,
  extra: Uint8Array,
): Promise<{ iv: string; ct: string }> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const cipher = new Uint8Array(
    await crypto.subtle.encrypt(
      { name: 'AES-GCM', iv: iv as BufferSource, additionalData: extra as BufferSource },
      key,
      plain as BufferSource,
    ),
  );
  return { iv: bytesToBase64(iv), ct: bytesToBase64(cipher) };
}

export async function open(
  key: CryptoKey,
  iv: string,
  ct: string,
  extra: Uint8Array,
): Promise<Uint8Array | null> {
  try {
    const clear = await crypto.subtle.decrypt(
      {
        name: 'AES-GCM',
        iv: base64ToBytes(iv) as BufferSource,
        additionalData: extra as BufferSource,
      },
      key,
      base64ToBytes(ct) as BufferSource,
    );
    return new Uint8Array(clear);
  } catch {
    return null;
  }
}
