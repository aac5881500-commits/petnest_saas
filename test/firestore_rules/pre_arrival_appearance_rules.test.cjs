const fs = require('node:fs');
const {test,before,after} = require('node:test');
const {initializeTestEnvironment,assertSucceeds,assertFails} = require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,deleteField} = require('firebase/firestore');
let env;
const base = {shopId:'APPEARANCE',serviceType:'accommodation',style:'packing',enabled:true,title:'入住前準備',blocks:[],inheritAccommodation:false,updatedBy:'owner'};
const appearance = {colorMode:'custom',fontFamily:'NotoSansTC',fontScale:1.2,accentColor:0xff446688,textColor:0xff222222,backgroundColor:0xfff4f6f8,cardColor:null};
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-pre-arrival-appearance',firestore:{rules:fs.readFileSync(require('node:path').resolve(__dirname,'../../firestore.rules'),'utf8')}});
  await env.withSecurityRulesDisabled(async c => setDoc(doc(c.firestore(),'shop_members/APPEARANCE_owner'),{role:'owner'}));
});
after(async () => {if(env)await env.cleanup();});
test('owner saves font/theme/custom appearance and reads back complete map',async () => {
  const target=doc(env.authenticatedContext('owner').firestore(),'shops/APPEARANCE/pre_arrival_guides/accommodation');
  for(const colorMode of ['style','theme','custom'])await assertSucceeds(setDoc(target,{...base,appearance:{...appearance,colorMode}}));
  const saved=(await getDoc(target)).data();
  require('node:assert/strict').equal(saved.appearance.fontFamily,'NotoSansTC');
});
test('restore original appearance deletes saved overrides with merge and retains blocks',async () => {
  const target=doc(env.authenticatedContext('owner').firestore(),'shops/APPEARANCE/pre_arrival_guides/accommodation');
  await assertSucceeds(setDoc(target,{...base,appearance}));
  await assertSucceeds(setDoc(target,{...base,appearance:deleteField()},{merge:true}));
  require('node:assert/strict').equal((await getDoc(target)).data().appearance,undefined);
});
test('invalid fonts, modes, scales, colors and unknown fields are rejected',async () => {
  const target=doc(env.authenticatedContext('owner').firestore(),'shops/APPEARANCE/pre_arrival_guides/accommodation');
  for(const invalid of [{fontFamily:'unknown'},{colorMode:'bad'},{fontScale:9},{fontScale:'1.2'},{accentColor:-1},{textColor:'red'},{extra:true}])await assertFails(setDoc(target,{...base,appearance:{...appearance,...invalid}}));
});
test('customer cannot update appearance and legacy guides still save',async () => {
  const owner=doc(env.authenticatedContext('owner').firestore(),'shops/APPEARANCE/pre_arrival_guides/accommodation');
  await assertSucceeds(setDoc(owner,base));
  const customer=doc(env.authenticatedContext('customer').firestore(),'shops/APPEARANCE/pre_arrival_guides/accommodation');
  await assertFails(setDoc(customer,{...base,updatedBy:'customer',appearance}));
});
