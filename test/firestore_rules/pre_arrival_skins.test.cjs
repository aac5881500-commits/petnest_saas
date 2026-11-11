const test = require('node:test');
const fs = require('node:fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc } = require('firebase/firestore');
let env;
test.before(async () => {
  env = await initializeTestEnvironment({projectId: 'demo-pre-arrival-skins', firestore: {host: '127.0.0.1', port: 8197, rules: fs.readFileSync(require('node:path').resolve(__dirname, '../../firestore.rules'), 'utf8')}});
  await env.withSecurityRulesDisabled(async c => { await setDoc(doc(c.firestore(), 'shop_members/SHOP_owner'), {role: 'owner'}); });
});
test.after(async () => { if (env) await env.cleanup(); });
const data = (style) => ({shopId: 'SHOP', serviceType: 'accommodation', enabled: true, title: '入住前準備', blocks: [], inheritAccommodation: false, updatedBy: 'owner', ...(style === undefined ? {} : {style})});
test('member can save all skins and legacy documents without style', async () => {
  const db = env.authenticatedContext('owner').firestore();
  for (const style of [undefined, 'classic', 'packing', 'timeline', 'minimal']) await assertSucceeds(setDoc(doc(db, 'shops/SHOP/pre_arrival_guides/accommodation'), data(style)));
});
test('invalid style, extra fields, wrong identity and customer writes are denied', async () => {
  const owner = doc(env.authenticatedContext('owner').firestore(), 'shops/SHOP/pre_arrival_guides/accommodation');
  for (const style of ['bad', null, 42]) await assertFails(setDoc(owner, data(style)));
  await assertFails(setDoc(owner, {...data('packing'), extra: true}));
  await assertFails(setDoc(owner, {...data('packing'), updatedBy: 'customer'}));
  await assertFails(setDoc(doc(env.authenticatedContext('customer').firestore(), 'shops/SHOP/pre_arrival_guides/accommodation'), {...data('timeline'), updatedBy: 'customer'}));
});
test('enabled guide remains readable to customer while draft is private', async () => {
  const owner = doc(env.authenticatedContext('owner').firestore(), 'shops/SHOP/pre_arrival_guides/accommodation');
  const customer = doc(env.authenticatedContext('customer').firestore(), 'shops/SHOP/pre_arrival_guides/accommodation');
  await assertSucceeds(setDoc(owner, data('minimal')));
  await assertSucceeds(getDoc(customer));
  await assertSucceeds(setDoc(owner, {...data('minimal'), enabled: false}));
  await assertFails(getDoc(customer));
});
