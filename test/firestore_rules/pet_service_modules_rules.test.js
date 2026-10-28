const fs = require('fs');
const path = require('path');
const test = require('node:test');
const {initializeTestEnvironment,assertFails,assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,getDocs,query,collection,where,updateDoc,serverTimestamp,Timestamp} = require('firebase/firestore');
let env;
const base = 'shops/shopA';
const config = {
 enabled:true,notice:'請提前到店',days:[1,2,3,4,5,6,7],opens:600,closes:1080,advanceDays:60,
 services:{bath:{name:'洗澡',description:'基礎清潔',enabled:true,price:800,duration:60,maxWeight:10}},
 staff:{amy:{name:'美容師甲',description:'清潔美容',enabled:true,days:[1,2,3,4,5,6,7],opens:660,closes:900}},
};
function application(overrides={}) {
 const local=new Date(Date.now()+8*3600000+24*3600000);
 const date=local.toISOString().slice(0,10);
 return {module:'grooming',serviceId:'bath',serviceName:'洗澡',staffId:'amy',staffName:'美容師甲',
 date,time:'11:00',endDate:date,startsAt:Timestamp.fromDate(new Date(`${date}T11:00:00+08:00`)),
 endsAt:Timestamp.fromDate(new Date(`${date}T00:00:00+08:00`)),contactName:'王先生',phone:'0900000000',
 petName:'麻糬',petId:'cat1',species:'cat',petSnapshot:{petId:'cat1',name:'麻糬',vaccineTypes:'接種紀錄'},weight:6,details:'個性慢熟',noticeAccepted:true,userId:'customer',status:'pending',
 createdAt:serverTimestamp(),updatedAt:serverTimestamp(),...overrides};
}
const db=(uid)=>env.authenticatedContext(uid).firestore();
test.before(async()=>{env=await initializeTestEnvironment({projectId:'demo-petnest-pet-services',firestore:{rules:fs.readFileSync(path.resolve(__dirname,'../../firestore.rules'),'utf8')}});});
test.after(async()=>{if(env)await env.cleanup();});
test.beforeEach(async()=>{
 await env.clearFirestore();
 await env.withSecurityRulesDisabled(async ctx=>{
  const store=ctx.firestore();
  await setDoc(doc(store,'user_profiles/customer/pets/cat1'),{name:'麻糬',species:'cat',vaccineTypes:'接種紀錄'});
  await setDoc(doc(store,'user_profiles/customer/pets/dog1'),{name:'狗狗',species:'dog',vaccineTypes:'犬疫苗紀錄'});
  await setDoc(doc(store,base),{ownerUid:'owner',isPublic:true,plan:'pro',enabledModules:['dog_hotel','grooming','hospital']});
  await setDoc(doc(store,`${base}/service_modules/grooming`),config);
  await setDoc(doc(store,`${base}/service_modules/dog_hotel`),config);
  await setDoc(doc(store,`${base}/service_modules/hospital`),config);
  for(const [uid,permissions] of [['operator',{manage_bookings:true}],['configurer',{manage_booking_settings:true}],['viewer',{manage_chat:true}]]) {
   await setDoc(doc(store,`shop_members/shopA_${uid}`),{shopId:'shopA',uid,role:'staff',permissions});
  }
 });
});
test('public can read catalogue, only owner/configurer can edit',async()=>{
 await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(),`${base}/service_modules/grooming`)));
 await assertFails(setDoc(doc(db('operator'),`${base}/service_modules/grooming`),{...config,updatedAt:serverTimestamp()}));
 await assertSucceeds(setDoc(doc(db('configurer'),`${base}/service_modules/grooming`),{...config,updatedAt:serverTimestamp()}));
 await assertSucceeds(setDoc(doc(db('owner'),`${base}/service_modules/hospital`),{...config,updatedAt:serverTimestamp()}));
 await assertFails(setDoc(doc(db('owner'),`${base}/service_modules/grooming`),{...config,days:[],updatedAt:serverTimestamp()}));
});
test('customer creates a pending application and reads only their own records',async()=>{
 const a=doc(db('customer'),`${base}/service_requests/a`);
 await assertSucceeds(setDoc(a,application()));
 await assertSucceeds(getDoc(a));
 await assertFails(getDoc(doc(db('stranger'),`${base}/service_requests/a`)));
 await assertFails(getDoc(doc(db('viewer'),`${base}/service_requests/a`)));
 await assertSucceeds(getDoc(doc(db('operator'),`${base}/service_requests/a`)));
 await assertSucceeds(getDocs(query(collection(db('customer'),`${base}/service_requests`),where('module','==','grooming'),where('userId','==','customer'))));
});
test('rejects forging identity, status, service, staff, weight and extra private fields',async()=>{
 for(const override of [{userId:'other'},{status:'confirmed'},{serviceName:'偽造服務'},{staffName:'偽造人員'},{serviceId:'missing'},{staffId:'missing'},{weight:11},{weight:-1},{noticeAccepted:false},{secret:'extra'}]) {
  await assertFails(setDoc(doc(db('customer'),`${base}/service_requests/a`),application(override)));
 }
});
test('enforces server-side future time, staff schedule and matching displayed date/time',async()=>{
 const a=application();
 for(const override of [
  {startsAt:Timestamp.fromDate(new Date(Date.now()-3600000))},
  {startsAt:Timestamp.fromDate(new Date(`${a.date}T10:00:00+08:00`)),time:'10:00'},
  {startsAt:Timestamp.fromDate(new Date(`${a.date}T14:30:00+08:00`)),time:'14:30'},
  {time:'12:00'}, {date:'2099-01-01'},{endDate:'2099-01-01'},
 ]) await assertFails(setDoc(doc(db('customer'),`${base}/service_requests/a`),application(override)));
});
test('disabled module/configuration cannot receive applications',async()=>{
 await env.withSecurityRulesDisabled(async ctx=>updateDoc(doc(ctx.firestore(),`${base}/service_modules/grooming`),{enabled:false}));
 await assertFails(setDoc(doc(db('customer'),`${base}/service_requests/a`),application()));
 await env.withSecurityRulesDisabled(async ctx=>{
  await updateDoc(doc(ctx.firestore(),`${base}/service_modules/grooming`),{enabled:true});
  await updateDoc(doc(ctx.firestore(),base),{enabledModules:['dog_hotel']});
 });
 await assertFails(setDoc(doc(db('customer'),`${base}/service_requests/a`),application()));
});
test('dog applications permit manual assignment and a later pickup date',async()=>{
 const a=application();const end=new Date(new Date(`${a.date}T00:00:00+08:00`).getTime()+86400000);
 const endDate=new Date(end.getTime()+8*3600000).toISOString().slice(0,10);
 await assertSucceeds(setDoc(doc(db('customer'),`${base}/service_requests/dog`),application({module:'dog_hotel',petId:'dog1',petName:'狗狗',species:'dog',petSnapshot:{petId:'dog1',name:'狗狗',vaccineTypes:'犬疫苗紀錄'},staffId:'',staffName:'由店家安排',endDate,endsAt:Timestamp.fromDate(end)})));
 await assertFails(setDoc(doc(db('customer'),`${base}/service_requests/no-staff`),application({staffId:'',staffName:'由店家安排'})));
});
test('customer can cancel, operator advances status, terminal records stay immutable',async()=>{
 const customer=doc(db('customer'),`${base}/service_requests/a`);const operator=doc(db('operator'),`${base}/service_requests/a`);
 await assertSucceeds(setDoc(customer,application()));
 await assertFails(updateDoc(customer,{status:'confirmed',updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(operator,{status:'completed',updatedAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(operator,{status:'confirmed',updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(operator,{phone:'changed',updatedAt:serverTimestamp()}));
 await assertSucceeds(updateDoc(customer,{status:'cancelled',updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(operator,{status:'pending',updatedAt:serverTimestamp()}));
});
test('service records are private and append-only',async()=>{
 await setDoc(doc(db('customer'),`${base}/service_requests/a`),application());
 const ref=doc(db('operator'),`${base}/service_requests/a/records/note`);
 await assertSucceeds(setDoc(ref,{note:'已完成適應評估',authorId:'operator',createdAt:serverTimestamp()}));
 await assertSucceeds(getDoc(ref));
 await assertFails(getDoc(doc(db('customer'),`${base}/service_requests/a/records/note`)));
 await assertFails(getDoc(doc(db('configurer'),`${base}/service_requests/a/records/note`)));
 await assertFails(updateDoc(ref,{note:'changed'}));
});

test('advanced service categories, capacity and staff assignment use the existing schema',async()=>{
 const advanced={...config,
  services:{bath:{...config.services.bath,kind:'bath',animalType:'both',capacity:0}},
  staff:{amy:{...config.staff.amy,serviceIds:['bath']}}};
 await assertSucceeds(setDoc(doc(db('owner'),`${base}/service_modules/grooming`),{...advanced,updatedAt:serverTimestamp()}));
 await assertSucceeds(setDoc(doc(db('customer'),`${base}/service_requests/advanced`),application({details:'品種／體型／體重：米克斯 6kg\n期望造型：基礎整理'})));
});

test('rejects cat at dog hotel, forged species, missing pet and wrong owner', async()=>{
 for(const override of [{module:'dog_hotel',staffId:'',staffName:'由店家安排'}, {species:'dog'}, {petId:'missing'}, {petId:'dog1'}]) {
  await assertFails(setDoc(doc(db('customer'),`${base}/service_requests/species`),application(override)));
 }
});
test('grooming follows owner acceptedSpecies and validates vaccine snapshot', async()=>{
 await env.withSecurityRulesDisabled(async ctx=>updateDoc(doc(ctx.firestore(),`${base}/service_modules/grooming`),{acceptedSpecies:['dog']}));
 await assertFails(setDoc(doc(db('customer'),`${base}/service_requests/cat`),application()));
 const dog={petId:'dog1',petName:'狗狗',species:'dog',petSnapshot:{petId:'dog1',name:'狗狗',vaccineTypes:'犬疫苗紀錄'}};
 await assertSucceeds(setDoc(doc(db('customer'),`${base}/service_requests/dog`),application(dog)));
 await assertFails(setDoc(doc(db('customer'),`${base}/service_requests/forged-vaccine`),application({...dog,petSnapshot:{...dog.petSnapshot,vaccineTypes:'偽造'}})));
 await assertFails(setDoc(doc(db('owner'),`${base}/service_modules/grooming`),{...config,acceptedSpecies:[],updatedAt:serverTimestamp()}));
});

test('legacy direct booking creation checks authoritative pet species too', async()=>{
 const store=db('customer');
 const baseBooking={shopId:'shopA',userId:'customer',status:'pending',source:'customer'};
 await assertSucceeds(setDoc(doc(store,'bookings/cat'),{...baseBooking,petIds:['cat1']}));
 for(const ids of [['dog1'],['cat1','dog1'],['missing'],[]]) {
   await assertFails(setDoc(doc(store,'bookings/invalid'),{...baseBooking,petIds:ids,pets:[{species:'cat'}]}));
 }
});
