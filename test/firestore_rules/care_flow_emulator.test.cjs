const fs=require('node:fs');
const path=require('node:path');
const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,getDoc,updateDoc}=require('firebase/firestore');
if(!process.env.FIRESTORE_EMULATOR_HOST)throw new Error('Requires isolated Firestore emulator');
const admin=require('../../functions/node_modules/firebase-admin');
const projectId='demo-care-flow-20261110';
admin.initializeApp({projectId});
const db=admin.firestore();
const {recordBookingServiceTask}=require('../../functions/care/service_task_functions');
const {serviceTasks}=require('../../functions/care/service_tasks');
let env;
before(async()=>{
  env=await initializeTestEnvironment({projectId,firestore:{host:'127.0.0.1',port:8199,rules:fs.readFileSync(path.resolve(__dirname,'../../firestore.rules'),'utf8')}});
  await db.doc('shops/care-test').set({ownerUid:'owner'});
  await db.doc('shop_members/care-test_owner').set({shopId:'care-test',uid:'owner',role:'owner'});
  await db.doc('shop_members/care-test_worker').set({shopId:'care-test',uid:'worker',role:'staff',permissions:{manage_bookings:true}});
});
after(async()=>{if(env)await env.cleanup();await admin.app().delete();});
async function fixture(id){
  const booking={shopId:'care-test',userId:'customer',status:'checked_in',startDate:'2026-01-01',totalPrice:1800,
    pets:[{petId:'p1',name:'小布'}],addons:[{serviceId:'play',name:'陪玩',type:'daily_timed',selections:[{petId:'p1',dates:[{date:'2026-01-01',slotIds:['s1'],slotLabels:['09:30']}]}]}]};
  await db.doc(`bookings/${id}`).set(booking);
  const task=serviceTasks(booking)[0];
  const call=(uid='worker',patch={})=>recordBookingServiceTask.run({auth:{uid,token:{}},data:{bookingId:id,taskId:task.id,scheduledAt:task.scheduledAt,actualAt:task.scheduledAt,result:'done',...patch}});
  return {task,call};
}
test('two employees concurrently record the same service: one record and one customer notice',async()=>{
  const f=await fixture('care-race');
  const results=await Promise.allSettled([f.call('owner'),f.call('worker')]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  assert.equal(results.find(r=>r.status==='rejected').reason.code,'already-exists');
  const b=(await db.doc('bookings/care-race').get()).data();
  assert.equal(Object.keys(b.careServiceRecords).length,1);assert.equal(b.customerUnreadMessageCount,1);
  assert.equal((await db.collection('bookings/care-race/messages').get()).size,1);
  assert.equal(b.totalPrice,1800);
});
test('customer sees recorded service without report entitlement; strangers cannot read',async()=>{
  const f=await fixture('care-customer');await f.call();
  const snapshot=await assertSucceeds(getDoc(doc(env.authenticatedContext('customer').firestore(),'bookings/care-customer')));
  assert.equal(snapshot.data().careServiceRecords[f.task.id].result,'done');
  await assertFails(getDoc(doc(env.authenticatedContext('stranger').firestore(),'bookings/care-customer')));
});
test('neither customer nor owner can bypass callable and forge or overwrite care results',async()=>{
  const f=await fixture('care-protected');await f.call();
  for(const uid of ['customer','owner']){
    await assertFails(updateDoc(doc(env.authenticatedContext(uid).firestore(),'bookings/care-protected'),{careServiceRecords:{}}));
  }
  await assert.rejects(f.call('customer'),{code:'permission-denied'});
});
test('cancelled/settled orders and read-only inspection identities reject actual callable writes',async()=>{
  const f=await fixture('care-locked');
  await db.doc('bookings/care-locked').update({settlementLocked:true});
  await assert.rejects(f.call(),{code:'failed-precondition'});
  await assert.rejects(recordBookingServiceTask.run({auth:{uid:'owner',token:{petnestInspection:true}},data:{bookingId:'care-locked'}}),{code:'permission-denied'});
});
