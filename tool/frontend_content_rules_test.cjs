// Run only against a Firestore emulator loaded with firestore.rules.
// FIRESTORE_EMULATOR_HOST=127.0.0.1:18085 node --test tool/frontend_content_rules_test.cjs
const assert = require('node:assert/strict');
const test = require('node:test');

const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  throw new Error('A local FIRESTORE_EMULATOR_HOST is required. Production is never used.');
}
const project = 'demo-petnest-content';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const shop = `content-${Date.now()}`;
function token(uid) {
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({alg: 'none', typ: 'JWT'})}.${encode({
    sub: uid, user_id: uid, aud: project,
    iss: `https://securetoken.google.com/${project}`,
    iat: Math.floor(Date.now() / 1000), exp: Math.floor(Date.now() / 1000) + 3600,
    firebase: {identities: {}, sign_in_provider: 'custom'},
  })}.`;
}
function fields(data) {
  return Object.fromEntries(Object.entries(data).map(([key, value]) => [key,
    typeof value === 'boolean' ? {booleanValue: value} :
    typeof value === 'string' ? {stringValue: value} : {mapValue: {fields: fields(value)}},
  ]));
}
async function request(method, path, data, actor) {
  const headers = {'Content-Type': 'application/json'};
  if (actor) headers.Authorization = `Bearer ${actor === 'owner' ? 'owner' : token(actor)}`;
  return fetch(`${base}/${path}`, {method, headers, body: data ? JSON.stringify(data) : undefined});
}
async function seed(path, data) {
  const response = await request('PATCH', path, {fields: fields(data)}, 'owner');
  assert.equal(response.status, 200, await response.text());
}
test('published content is public; drafts and writes require content permission', async t => {
  await seed(`shops/${shop}`, {ownerUid: 'shop-owner'});
  await seed(`shop_members/${shop}_editor`, {shopId: shop, role: 'staff', permissions: {manage_frontend_content: true}});
  await seed(`shop_members/${shop}_viewer`, {shopId: shop, role: 'staff', permissions: {manage_frontend_content: false}});
  for (const collection of ['announcements', 'faqs']) {
    const path = `shops/${shop}/${collection}`;
    await seed(`${path}/public`, {isPublished: true, title: 'published'});
    await seed(`${path}/draft`, {isPublished: false, title: 'draft'});
    await seed(`${path}/legacy`, {title: 'legacy draft'});
    await t.test(collection, async () => {
      for (const actor of [undefined, 'viewer', 'outsider']) {
        assert.equal((await request('GET', `${path}/public`, undefined, actor)).status, 200);
        assert.equal((await request('GET', `${path}/draft`, undefined, actor)).status, 403);
        assert.equal((await request('GET', `${path}/legacy`, undefined, actor)).status, 403);
        assert.equal((await request('PATCH', `${path}/draft`, {fields: fields({isPublished: true})}, actor)).status, 403);
        assert.equal((await request('DELETE', `${path}/public`, undefined, actor)).status, 403);
      }
      const query = {structuredQuery: {from: [{collectionId: collection}], where: {fieldFilter: {
        field: {fieldPath: 'isPublished'}, op: 'EQUAL', value: {booleanValue: true},
      }}}};
      assert.equal((await request('POST', `shops/${shop}:runQuery`, query)).status, 200);
      assert.equal((await request('POST', `shops/${shop}:runQuery`, {structuredQuery: {from: [{collectionId: collection}]}})).status, 403);
      for (const actor of ['editor', 'shop-owner']) {
        assert.equal((await request('GET', `${path}/draft`, undefined, actor)).status, 200);
        assert.equal((await request('PATCH', `${path}/${actor}-new`, {fields: fields({isPublished: false})}, actor)).status, 200);
        assert.equal((await request('DELETE', `${path}/${actor}-new`, undefined, actor)).status, 200);
      }
    });
  }
});
