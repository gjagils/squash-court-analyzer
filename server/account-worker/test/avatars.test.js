import { env } from 'cloudflare:test';
import { describe, expect, it } from 'vitest';
import { call, newDevice, newPlayer } from './helpers.js';

/** A tiny "JPEG": the magic bytes and some filler, in base64 */
function jpeg(fill = 1, size = 400) {
  let binary = String.fromCharCode(0xff, 0xd8, 0xff, 0xe0);
  for (let i = 0; i < size; i++) binary += String.fromCharCode((i * fill) % 256);
  return btoa(binary);
}

let pathCounter = 0;
const sbnPath = () => `/league/avatar-test/player/${pathCounter++}`;

describe('avatars', () => {
  it('needs consent and a real JPEG of at most 300 KB', async () => {
    const { auth } = await newPlayer();
    expect((await call('PUT', '/api/v1/me/avatar', { auth, body: { image: jpeg() } })).status).toBe(400);
    expect((await call('PUT', '/api/v1/me/avatar', { auth, body: { image: btoa('not a jpeg at all, just some text that is long enough to pass the minimum size check of one hundred bytes'), consent: true } })).status).toBe(400);
    expect((await call('PUT', '/api/v1/me/avatar', { auth, body: { image: '%%%', consent: true } })).status).toBe(400);
    expect((await call('PUT', '/api/v1/me/avatar', { auth, body: { image: jpeg(1, 310 * 1024), consent: true } })).status).toBe(400);
    const ok = await call('PUT', '/api/v1/me/avatar', { auth, body: { image: jpeg(), consent: true } });
    expect(ok.status).toBe(200);
    expect(ok.json.version).toBeGreaterThan(0);
  });

  it('shows in Mijn account, can be fetched and deleted', async () => {
    const { auth } = await newPlayer();
    expect((await call('GET', '/api/v1/me', { auth })).json.avatarVersion).toBeNull();
    const put = await call('PUT', '/api/v1/me/avatar', { auth, body: { image: jpeg(3), consent: true } });
    expect((await call('GET', '/api/v1/me', { auth })).json.avatarVersion).toBe(put.json.version);
    const own = await call('GET', '/api/v1/me/avatar', { auth });
    expect(own.json.image).toBe(jpeg(3));
    expect((await call('DELETE', '/api/v1/me/avatar', { auth })).status).toBe(204);
    expect((await call('GET', '/api/v1/me/avatar', { auth })).status).toBe(404);
    expect((await call('GET', '/api/v1/me', { auth })).json.avatarVersion).toBeNull();
  });

  it('a phone with a device key finds it by SBN player, others do not', async () => {
    const path = sbnPath();
    const { auth } = await newPlayer({ sbnPath: path });
    await call('PUT', '/api/v1/me/avatar', { auth, body: { image: jpeg(5), consent: true } });
    const other = sbnPath();
    expect((await call('GET', `/api/v1/avatars?sbn=${encodeURIComponent(path)}`)).status).toBe(401);
    const device = await newDevice();
    const list = await call('GET', `/api/v1/avatars?sbn=${encodeURIComponent(path)}&sbn=${encodeURIComponent(other)}`, { auth: device });
    expect(list.status).toBe(200);
    expect(list.json.avatars).toHaveLength(1);
    expect(list.json.avatars[0].sbnPath).toBe(path);
    const image = await call('GET', `/api/v1/avatars/image?sbn=${encodeURIComponent(path)}`, { auth: device });
    expect(image.json.image).toBe(jpeg(5));
    expect((await call('GET', `/api/v1/avatars/image?sbn=${encodeURIComponent(other)}`, { auth: device })).status).toBe(404);
  });

  it('a report is kept once per phone; a new photo starts clean; it goes with the account', async () => {
    const path = sbnPath();
    const { auth, player } = await newPlayer({ sbnPath: path });
    await call('PUT', '/api/v1/me/avatar', { auth, body: { image: jpeg(7), consent: true } });
    const device = await newDevice();
    expect((await call('POST', '/api/v1/avatars/report', { auth: device, body: { sbnPath: path } })).status).toBe(202);
    await call('POST', '/api/v1/avatars/report', { auth: device, body: { sbnPath: path } });
    const count = () => env.DB.prepare('SELECT COUNT(*) AS n FROM avatar_reports WHERE player_id = ?').bind(player.playerId).first();
    expect((await count()).n).toBe(1);
    // An unknown player gets the same answer
    expect((await call('POST', '/api/v1/avatars/report', { auth: device, body: { sbnPath: sbnPath() } })).status).toBe(202);
    await call('PUT', '/api/v1/me/avatar', { auth, body: { image: jpeg(9), consent: true } });
    expect((await count()).n).toBe(0);
    await call('DELETE', '/api/v1/me', { auth });
    const left = await env.DB.prepare('SELECT COUNT(*) AS n FROM avatars WHERE player_id = ?').bind(player.playerId).first();
    expect(left.n).toBe(0);
  });
});
