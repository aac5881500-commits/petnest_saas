const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {createRequire}=require('node:module');
const root=path.resolve(__dirname,'../..');
const req=createRequire(path.join(root,'test/firestore_rules/package.json'));
const {initializeTestEnvironment,assertFails,assertSucceeds}=req('@firebase/rules-unit-testing');
const {collection,doc,getDoc,getDocs,setDoc,updateDoc,deleteDoc,serverTimestamp}=req('firebase/firestore');
const baseline=process.env.OWNER_RULES_BASELINE==='1';
const rulesPath=process.env.OWNER_RULES_FILE||path.join(root,'firestore.rules');
let env;
const ref=(db,id='entry',shop='FINANCE_A',month='2026-10')=>doc(db,`shops/${shop}/owner_finance_months/${month}/entries/${id}`);
const payload=(kind='salary')=>({kind,name:kind==='salary'?'薪資測試員工':'測試項目',amount:32000,note:'emulator only',updatedAt:serverTimestamp()});
test.before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-owner-finance',firestore:{host:'127.0.0.1',port:8197,rules:fs.readFileSync(rulesPath,'utf8')}});
 await env.withSecurityRulesDisabled(async c=>{
  const db=c.firestore();
  await setDoc(doc(db,'shops/FINANCE_A'),{ownerUid:'uid-owner',isPublic:true});
  await setDoc(doc(db,'shops/FINANCE_B'),{ownerUid:'other-owner',isPublic:true});
  for(const [uid,role] of [['role-owner','owner'],['manager','manager'],['staff','staff']]) {
   await setDoc(doc(db,`shop_members/FINANCE_A_${uid}`),{shopId:'FINANCE_A',uid,role,permissions:['view_reports','view_money','manage_members'],permissionsV2:{reports:{view:true,export:true}}});
  }
  await setDoc(ref(db,'existing'),{kind:'salary',name:'existing',amount:30000,note:'',updatedAt:new Date()});
 });
});
test.after(async()=>{if(env)await env.cleanup();});
if(baseline) {
 test('deployed baseline rejects true owner private read and salary save',async()=>{
  const db=env.authenticatedContext('uid-owner').firestore();
  await assertFails(getDocs(collection(db,'shops/FINANCE_A/owner_finance_months/2026-10/entries')));
  await assertFails(setDoc(ref(db,'blocked-salary'),payload()));
 });
} else {
 test('shop ownerUid without member document can list and save all 3 categories',async()=>{
  const db=env.authenticatedContext('uid-owner').firestore();
  for(const kind of ['salary','income','expense']) await assertSucceeds(setDoc(ref(db,'uid-'+kind),payload(kind)));
  const snap=await assertSucceeds(getDocs(collection(db,'shops/FINANCE_A/owner_finance_months/2026-10/entries')));
  assert.ok(snap.docs.some(d=>d.id==='uid-salary'));
 });
 test('canonical owner role can create, edit, reload and delete monthly entry',async()=>{
  const db=env.authenticatedContext('role-owner').firestore();
  const r=ref(db,'role-salary');
  await assertSucceeds(setDoc(r,payload()));
  await assertSucceeds(updateDoc(r,{amount:35000,updatedAt:serverTimestamp()}));
  assert.equal((await assertSucceeds(getDoc(r))).data().amount,35000);
  await assertSucceeds(deleteDoc(r));
 });
 for(const uid of ['manager','staff','stranger','other-owner']) {
  test(uid+' cannot read or alter private financial records',async()=>{
   const db=env.authenticatedContext(uid).firestore();
   await assertFails(getDocs(collection(db,'shops/FINANCE_A/owner_finance_months/2026-10/entries')));
   await assertFails(getDoc(ref(db,'existing')));
   await assertFails(setDoc(ref(db,'intrusion-'+uid),payload()));
   await assertFails(updateDoc(ref(db,'existing'),{amount:1,updatedAt:serverTimestamp()}));
   await assertFails(deleteDoc(ref(db,'existing')));
  });
 }
 test('anonymous and owner of another shop are denied',async()=>{
  const anon=env.unauthenticatedContext().firestore();
  await assertFails(getDoc(ref(anon,'existing')));
  await assertFails(setDoc(ref(anon,'anonymous'),payload()));
  const db=env.authenticatedContext('uid-owner').firestore();
  await assertFails(setDoc(ref(db,'cross-shop','FINANCE_B'),payload()));
  await assertFails(getDocs(collection(db,'shops/FINANCE_B/owner_finance_months/2026-10/entries')));
 });
 test('validation rejects malformed amount, category, month, extra fields and forged timestamp',async()=>{
  const db=env.authenticatedContext('uid-owner').firestore();
  for(const patch of [{amount:0},{amount:-1},{amount:1.5},{amount:1000000000},{kind:'admin'},{name:''},{note:'x'.repeat(301)},{privateUid:'x'},{updatedAt:new Date(0)}]) {
   await assertFails(setDoc(ref(db,'invalid'),{...payload(),...patch}));
  }
  await assertFails(setDoc(ref(db,'month','FINANCE_A','2026-13'),payload()));
 });
}
