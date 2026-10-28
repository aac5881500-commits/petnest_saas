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
 await assertFails(getDoc(doc(env.authenticatedContext('customer').firestore(),'shops/SHOP0018')));
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
test('expired access fails',async()=>{
 await manage('owner',{shopId:'SHOP0018',action:'save',searchCode:'CAT_HOME_2026'});
 await resolve('customer','CAT_HOME_2026');
 await admin.firestore().doc('shop_share_access/SHOP0018/users/customer').update({expiresAt:admin.firestore.Timestamp.fromMillis(0)});
 await assertFails(getDoc(doc(env.authenticatedContext('customer').firestore(),'shops/SHOP0018')));
});
