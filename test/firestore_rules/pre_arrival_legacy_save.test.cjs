const fs=require('node:fs');
const path=require('node:path');
const {test,before,after}=require('node:test');
const assert=require('node:assert/strict');
const {initializeTestEnvironment,assertSucceeds,assertFails}=require('@firebase/rules-unit-testing');
const {doc,setDoc,getDoc,deleteField}=require('firebase/firestore');
const root=path.resolve(__dirname,'../..');
const fixture=JSON.parse(fs.readFileSync(root+'/build/pre_arrival_storage_fixture.json','utf8'));
const rulesSource=process.env.PREARRIVAL_RULES_SOURCE || root+'/firestore.rules';
let env;
before(async()=>{
 env=await initializeTestEnvironment({projectId:'demo-pre-arrival-save',firestore:{host:'127.0.0.1',port:8197,rules:fs.readFileSync(rulesSource,'utf8')}});
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'shop_members/SAVE_owner'),{role:'owner'}));
});
after(async()=>{if(env)await env.cleanup();});
const payload=data=>({...data,style:deleteField(),appearance:deleteField()});
test('actual Dart payload saves all styles and customized appearance under loaded rules',async()=>{
 const target=doc(env.authenticatedContext('owner').firestore(),'shops/SAVE/pre_arrival_guides/accommodation');
 for(const style of ['classic','packing','timeline','minimal']) {
  await assertSucceeds(setDoc(target,payload(fixture[style]),{merge:true}));
  const data=(await getDoc(target)).data();
  assert.equal(data.style,undefined);assert.equal(data.appearance,undefined);
  const metadata=data.blocks.find(b=>b.id==='__petnest_pre_arrival_presentation_v1');
  assert.equal(metadata.presentation.style,style);assert.equal(metadata.presentation.appearance.fontFamily,'NotoSerifTC');
 }
});
test('migrates a top-level settings document and restores original style without stale settings',async()=>{
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'shops/SAVE/pre_arrival_guides/accommodation'),{...fixture.packing,style:'packing',appearance:{fontFamily:'NotoSerifTC'}}));
 const target=doc(env.authenticatedContext('owner').firestore(),'shops/SAVE/pre_arrival_guides/accommodation');
 await assertSucceeds(setDoc(target,payload(fixture.minimal),{merge:true}));
 await assertSucceeds(setDoc(target,payload(fixture.reset),{merge:true}));
 const data=(await getDoc(target)).data();
 assert.equal(data.style,undefined);assert.equal(data.appearance,undefined);
 assert.equal(data.blocks.some(b=>b.id==='__petnest_pre_arrival_presentation_v1'),false);
 assert.ok(data.blocks.some(b=>b.id==='catalog-cold-food'));
});
test('customer and anonymous writes still fail; enabled customer reads remain valid',async()=>{
 const location='shops/SAVE/pre_arrival_guides/accommodation';
 await assertFails(setDoc(doc(env.authenticatedContext('customer').firestore(),location),payload({...fixture.packing,updatedBy:'customer'}),{merge:true}));
 await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(),location),payload(fixture.packing),{merge:true}));
 await assertSucceeds(getDoc(doc(env.authenticatedContext('customer').firestore(),location)));
});
