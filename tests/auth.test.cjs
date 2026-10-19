const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const code = fs.readFileSync('auth.js', 'utf8');
async function start({ user = null, search = '', callbackFails = false, configFails = false } = {}) {
  const elements = Object.fromEntries(['app','signedOut','identity','authMessage','signIn','signOut'].map(id => [id, {}]));
  let current = user, assigned, cleaned = false, settings, expired, removed = 0;
  class Manager {
    constructor(s) { settings = s; this.events = { addAccessTokenExpired(fn) { expired = fn; } }; }
    async getUser() { return current; }
    async removeUser() { current = null; removed++; }
    async clearStaleState() {}
    async signinRedirectCallback() { if (callbackFails) throw Error('bad state'); current = { expired: false, profile: { email: 'member@example.com' } }; }
    async signinRedirect() {}
  }
  const storage = {};
  const window = { oidc: {}, sessionStorage: storage, location: { search, assign(url) { assigned = url; } }, history: { replaceState() { cleaned = true; } } };
  await vm.runInNewContext(code, {
    window, oidc: { UserManager: Manager, WebStorageStateStore: class { constructor(s) { this.store = s.store; } } },
    document: { getElementById(id) { return elements[id]; }, title: 'Meeting Momentum' }, URL, URLSearchParams,
    fetch: async () => ({ ok: !configFails, json: async () => ({ authority: 'https://issuer.example', domain: 'https://auth.example', client_id: 'public', redirect_uri: 'https://app.example/' }) })
  });
  return { elements, settings, storage, expire: () => expired(), assigned: () => assigned, cleaned: () => cleaned, removed: () => removed };
}
test('signed-out screen and session-scoped authorization code settings', async () => {
  const s = await start();
  assert.equal(s.elements.app.hidden, true);
  assert.equal(s.elements.signIn.disabled, false);
  assert.equal(s.settings.response_type, 'code');
  assert.equal(s.settings.userStore.store, s.storage);
  assert.equal(s.settings.stateStore.store, s.storage);
});
test('reload restores a valid user and logout clears before redirect', async () => {
  const s = await start({ user: { expired: false, profile: { email: 'member@example.com' } } });
  assert.equal(s.elements.app.hidden, false);
  assert.match(s.elements.identity.textContent, /member@example.com/);
  const pending = s.elements.signOut.onclick();
  assert.equal(s.elements.app.hidden, true);
  await pending;
  assert.equal(s.removed(), 1);
  assert.equal(new URL(s.assigned()).pathname, '/logout');
  assert.equal(new URL(s.assigned()).searchParams.get('logout_uri'), 'https://app.example/');
});
test('callback failure clears session and removes callback parameters', async () => {
  const s = await start({ search: '?code=bad&state=unknown', callbackFails: true });
  assert.equal(s.elements.app.hidden, true);
  assert.equal(s.cleaned(), true);
  assert.match(s.elements.authMessage.textContent, /could not be verified/);
});
test('successful callback displays identity and cleans URL', async () => {
  const s = await start({ search: '?code=good&state=known' });
  assert.equal(s.elements.app.hidden, false);
  assert.equal(s.cleaned(), true);
});
test('expiry hides app and removes stored user', async () => {
  const s = await start({ user: { expired: false, profile: { email: 'member@example.com' } } });
  await s.expire();
  assert.equal(s.elements.app.hidden, true);
  assert.match(s.elements.authMessage.textContent, /expired/);
  assert.equal(s.removed(), 1);
});
test('expired user on reload stays signed out', async () => {
  const s = await start({ user: { expired: true, profile: {} } });
  assert.equal(s.elements.app.hidden, true);
  assert.equal(s.removed(), 1);
});
test('configuration outage fails closed', async () => {
  const s = await start({ configFails: true });
  assert.equal(s.elements.app.hidden, true);
  assert.equal(s.elements.signIn.disabled, true);
  assert.match(s.elements.authMessage.textContent, /unavailable/);
});
