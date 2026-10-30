const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {createRequire} = require('node:module');
const root = require('node:path').resolve(__dirname, '../..');
const req = createRequire(root + '/test/firestore_rules/package.json');
const {initializeTestEnvironment, assertFails, assertSucceeds} = req('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,getDocs,query,collection,where,updateDoc,Timestamp} = req('firebase/firestore');
const admin = require(root + '/functions/node_modules/firebase-admin');
process.env.GCLOUD_PROJECT = 'demo-private-sharing';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8188';
admin.initializeApp({projectId:'demo-private-sharing'});
const sharing = require(root + '/functions/shops/shop_sharing');
let env;
const call = (uid,data,ip='127.0.0.1') => ({auth:{uid},data,rawRequest:{ip}});
const manage = (uid,data) => sharing.manageShopSharing.run(call(uid,data));
const resolve = (uid,code) => sharing.resolveShopSharing.run(call(uid,{code}));
test.before(async()=>{
 env = await initializeTestEnvironment({projectId:'demo-private-sharing',firestore:{host:'127.0.0.1',port:8188,rules:fs.readFileSync(root+'/firestore.rules','utf8')}});
});
test.after(async()=>{if(env)await env.cleanup();await admin.app().delete();});
test.beforeEach(async()=>{
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async c=>{
  for(const id of ['SHOP0018','SHOP0019']) await setDoc(doc(c.firestore(),'shops/'+id),{ownerUid:'owner',isPublic:false});
  await setDoc(doc(c.firestore(),'shops/PUBLIC'),{ownerUid:'owner',isPublic:true});
  await setDoc(doc(c.firestore(),'shops/SHOP0018/room_types/suite'),{name:'suite'});
  await setDoc(doc(c.firestore(),'shop_members/SHOP0018_editor'),{shopId:'SHOP0018',uid:'editor',role:'staff',permissions:{edit_business_info:true}});
 });
});
test('codes reject predictable platform identifiers; ownership and staff permissions enforced',async()=>{
 for(const code of ['SHOP0018','short','a/bcdefgh']) assert.equal(sharing.policy.validCode(code),false);
 await assert.rejects(manage('stranger',{shopId:'SHOP0018',action:'save',searchCode:'CAT_HOME_2026'}),{code:'permission-denied'});
 await assert.rejects(manage('owner',{shopId:'SHOP0018',action:'save',searchCode:'SHOP0018'}),{code:'invalid-argument'});
 const settings=await manage('editor',{shopId:'SHOP0018',action:'save',searchCode:'cat_home_2026'});
 assert.equal(settings.searchCode,'CAT_HOME_2026'); assert.match(settings.qrToken,/^[a-f0-9]{48}$/);
});
test('private shops deny guesses, lists, subcollections and secret access; valid QR grants access',async()=>{
 const db=env.authenticatedContext('customer').firestore();
 await assertFails(getDoc(doc(db,'shops/SHOP0018')));
 await assertFails(getDocs(collection(db,'shops')));
 await assertFails(getDoc(doc(db,'shops/SHOP0018/room_types/suite')));
 await assertSucceeds(getDocs(query(collection(db,'shops'),where('isPublic','==',true))));
 await assertSucceeds(getDoc(doc(env.authenticatedContext('owner').firestore(),'shops/SHOP0018')));
 const s=await manage('owner',{shopId:'SHOP0018',action:'save',searchCode:'CAT_HOME_2026'});
 await assertFails(getDoc(doc(db,'shop_sharing/SHOP0018')));
 await assertFails(setDoc(doc(db,'shop_share_access/SHOP0018/users/customer'),{version:1,expiresAt:Timestamp.fromMillis(Date.now()+10000)}));
 await assert.rejects(resolve('customer','SHOP0018'),{code:'not-found'});
 assert.equal((await resolve('customer',s.qrToken)).shopId,'SHOP0018');
 await assertSucceeds(getDoc(doc(db,'shops/SHOP0018')));
 await assertSucceeds(getDoc(doc(db,'shops/SHOP0018/room_types/suite')));
 await assertFails(getDoc(doc(db,'shops/SHOP0019')));
});
test('code uniqueness, rotation, replacement, disable and re-enable invalidate old entry',async()=>{
 const data={shopId:'SHOP0018',action:'save',searchCode:'CAT_HOME_2026'};
 const a=await manage('owner',data);
 await assert.rejects(manage('owner',{...data,shopId:'SHOP0019'}),{code:'already-exists'});
 await resolve('customer',a.qrToken);
 const b=await manage('owner',{shopId:'SHOP0018',action:'rotate'});
 assert.notEqual(a.qrToken,b.qrToken);
 await assert.rejects(resolve('customer',a.qrToken),{code:'not-found'});
 await assertSucceeds(getDoc(doc(env.authenticatedContext('customer').firestore(),'shops/SHOP0018')));
 await resolve('customer','cat_home_2026');
 await manage('owner',{...data,searchCode:'NEW_HOME_2026'});
 await assert.rejects(resolve('customer','CAT_HOME_2026'),{code:'not-found'});
 await manage('owner',{shopId:'SHOP0018',action:'disable'});
 await assert.rejects(resolve('customer',b.qrToken),{code:'not-found'});
 const c=await manage('owner',{...data,searchCode:''});
 assert.notEqual(c.qrToken,b.qrToken);
 await assert.rejects(resolve('customer',b.qrToken),{code:'not-found'});
});
test('failed guesses are throttled per account',async()=>{
 for(let i=0;i<15;i++) await assert.rejects(resolve('guesser','NOT_FOUND_2026'),{code:'not-found'});
 await assert.rejects(resolve('guesser','NOT_FOUND_2026'),{code:'resource-exhausted'});
});
test('admitted customer remains after former access expiration',async()=>{
 await manage('owner',{shopId:'SHOP0018',action:'save',searchCode:'CAT_HOME_2026'});
 await resolve('customer','CAT_HOME_2026');
 await admin.firestore().doc('shop_share_access/SHOP0018/users/customer').update({expiresAt:admin.firestore.Timestamp.fromMillis(0)});
 await assertSucceeds(getDoc(doc(env.authenticatedContext('customer').firestore(),'shops/SHOP0018')));
});

test('owner membership sync can still query owned shops',async()=>{
 const db=env.authenticatedContext('owner').firestore();
 await assertSucceeds(getDocs(query(collection(db,'shops'),where('ownerUid','==','owner'))));
});

const binding = (uid,data={}) => sharing.customerShopBinding.run(call(uid,data));
test('code changes and closing new entry do not eject existing customer',async()=>{
 await manage('owner',{shopId:'SHOP0018',action:'save',searchCode:'CAT_HOME_2026'});
 await resolve('customer','CAT_HOME_2026');
 await manage('owner',{shopId:'SHOP0018',action:'save',searchCode:'NEW_HOME_2026'});
 assert.equal((await binding('customer')).shopId,'SHOP0018');
 await manage('owner',{shopId:'SHOP0018',action:'disable'});
 await assertSucceeds(getDoc(doc(env.authenticatedContext('customer').firestore(),'shops/SHOP0018')));
 await assert.rejects(resolve('new-customer','CAT_HOME_2026'),{code:'not-found'});
 await assert.rejects(resolve('new-customer','NEW_HOME_2026'),{code:'not-found'});
});
test('explicit successful entry switches binding; failed guesses keep old binding',async()=>{
 await manage('owner',{shopId:'SHOP0018',action:'save',searchCode:'CAT_HOME_2026'});
 await manage('owner',{shopId:'SHOP0019',action:'save',searchCode:'OTHER_HOME_2026'});
 await resolve('customer','CAT_HOME_2026');
 await assert.rejects(resolve('customer','WRONG_CODE_2026'),{code:'not-found'});
 assert.equal((await binding('customer')).shopId,'SHOP0018');
 await resolve('customer','OTHER_HOME_2026');
 assert.equal((await binding('customer')).shopId,'SHOP0019');
 const db=env.authenticatedContext('customer').firestore();
 await assertFails(getDoc(doc(db,'shops/SHOP0018')));
 await assertSucceeds(getDoc(doc(db,'shops/SHOP0019')));
});
test('legacy admission recovers after expiry and rotation; cannot forge a shop binding',async()=>{
 await admin.firestore().doc('shop_share_access/SHOP0018/users/legacy').set({version:1,expiresAt:admin.firestore.Timestamp.fromMillis(0)});
 assert.equal((await binding('legacy',{legacyShopId:'SHOP0018'})).shopId,'SHOP0018');
 assert.equal((await binding('stranger',{legacyShopId:'SHOP0018'})).shopId,null);
 const db=env.authenticatedContext('stranger').firestore();
 await assertFails(setDoc(doc(db,'shop_customer_bindings/stranger'),{shopId:'SHOP0018'}));
 await assertFails(getDoc(doc(db,'shops/SHOP0018')));
 await assert.rejects(binding('stranger',{action:'selectPublic',shopId:'SHOP0018'}),{code:'permission-denied'});
});
test('choosing a public shop explicitly updates binding and rejects stale private cache',async()=>{
 await manage('owner',{shopId:'SHOP0018',action:'save',searchCode:'CAT_HOME_2026'});
 await resolve('customer','CAT_HOME_2026');
 await binding('customer',{action:'selectPublic',shopId:'PUBLIC'});
 assert.equal((await binding('customer',{legacyShopId:'SHOP0018'})).shopId,'PUBLIC');
 await assertFails(getDoc(doc(env.authenticatedContext('customer').firestore(),'shops/SHOP0018')));
});

test('concurrent same code is atomically unique and loser keeps original settings',async()=>{
 const a=await manage('owner',{shopId:'SHOP0018',action:'save',searchCode:'FIRST_HOME_2026'});
 const b=await manage('owner',{shopId:'SHOP0019',action:'save',searchCode:'SECOND_HOME_2026'});
 const results=await Promise.allSettled([
  manage('owner',{shopId:'SHOP0018',action:'save',searchCode:'SAME_CODE_2026'}),
  manage('owner',{shopId:'SHOP0019',action:'save',searchCode:'same_code_2026'}),
 ]);
 assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
 const rejected=results.find(r=>r.status==='rejected');assert.equal(rejected.reason.code,'already-exists');
 const winner=results[0].status==='fulfilled'?'SHOP0018':'SHOP0019';
 const loser=winner==='SHOP0018'?'SHOP0019':'SHOP0018';
 const unchanged=await manage('owner',{shopId:loser});
 assert.equal(unchanged.searchCode,loser==='SHOP0018'?a.searchCode:b.searchCode);
 assert.equal(unchanged.qrToken,loser==='SHOP0018'?a.qrToken:b.qrToken);
 assert.equal((await resolve('customer','same_code_2026')).shopId,winner);
});
test('anonymous visitor cannot write platform member consent or cached acceptance',async()=>{
 const guest=env.authenticatedContext('guest',{firebase:{sign_in_provider:'anonymous'}}).firestore();
 const member=env.authenticatedContext('member',{firebase:{sign_in_provider:'password'}}).firestore();
 const record=(uid)=>({uid,policyId:'platform_user_policy',acceptedVersion:3});
 await assertFails(setDoc(doc(guest,'users/guest/platform_policy_acceptances/platform_user_policy'),record('guest')));
 await assertFails(setDoc(doc(guest,'users/guest'),{acceptedPlatformPolicyVersion:3}));
 await assertSucceeds(setDoc(doc(member,'users/member/platform_policy_acceptances/platform_user_policy'),record('member')));
 await assertSucceeds(setDoc(doc(member,'users/member'),{acceptedPlatformPolicyVersion:3}));
});
const transfer = (uid,provider,data) => sharing.transferCustomerShopBinding.run({
 auth:{uid,token:{firebase:{sign_in_provider:provider}}},data,rawRequest:{ip:'127.0.0.1'},
});
test('formal login carries only guest storefront binding with a single-use ticket',async()=>{
 await manage('owner',{shopId:'SHOP0018',action:'save',searchCode:'CAT_HOME_2026'});
 await resolve('guest','CAT_HOME_2026');
 await admin.firestore().doc('users/guest/platform_policy_acceptances/platform_user_policy').set({uid:'guest',policyId:'platform_user_policy',acceptedVersion:3});
 const {ticket}=await transfer('guest','anonymous',{action:'issue'});assert.match(ticket,/^[a-f0-9]{48}$/);
 await assert.rejects(transfer('guest','anonymous',{action:'claim',ticket}),{code:'permission-denied'});
 assert.equal((await transfer('member','password',{action:'claim',ticket})).shopId,'SHOP0018');
 assert.equal((await binding('member')).shopId,'SHOP0018');
 assert.equal((await admin.firestore().doc('users/member/platform_policy_acceptances/platform_user_policy').get()).exists,false);
 await assert.rejects(transfer('other','password',{action:'claim',ticket}),{code:'failed-precondition'});
});
test('forged, expired and changed-store login tickets cannot create a binding',async()=>{
 await assert.rejects(transfer('member','password',{action:'claim',ticket:'a'.repeat(48)}),{code:'failed-precondition'});
 await manage('owner',{shopId:'SHOP0018',action:'save',searchCode:'CAT_HOME_2026'});
 await resolve('guest','CAT_HOME_2026');
 const {ticket}=await transfer('guest','anonymous',{action:'issue'});
 const hash=require('node:crypto').createHash('sha256').update(ticket).digest('hex');
 await admin.firestore().doc('shop_binding_transfers/'+hash).update({expiresAt:admin.firestore.Timestamp.fromMillis(0)});
 await assert.rejects(transfer('member','password',{action:'claim',ticket}),{code:'failed-precondition'});
 const next=await transfer('guest','anonymous',{action:'issue'});
 await binding('guest',{action:'selectPublic',shopId:'PUBLIC'});
 await assert.rejects(transfer('member','password',{action:'claim',ticket:next.ticket}),{code:'failed-precondition'});
 assert.equal((await binding('member')).shopId,null);
});
