"use strict";
const test = require("node:test");
const path = require("node:path");
const fs = require("node:fs");
const {createRequire} = require("node:module");
const req = createRequire(path.resolve(__dirname,"../../test/firestore_rules/package.json"));
const {initializeTestEnvironment,assertSucceeds,assertFails} = req("@firebase/rules-unit-testing");
const {doc,setDoc,deleteDoc} = req("firebase/firestore");
const {ref,uploadBytes,getBytes,deleteObject} = req("firebase/storage");
let env;
const ROOT="7FNrECQeqAca9Vu8lBBzTSdcJcg1";
const files=["shop_chat/s1/customer/image.jpg","shop_chat/s2/customer/image.jpg",
  "pets/customer/avatar.jpg","pets/unrelated/avatar.jpg","booking_images/b1/photo.jpg","booking_images/b2/photo.jpg"];
test.before(async()=>{
  env=await initializeTestEnvironment({projectId:"demo-inspection-readonly",
    firestore:{host:"127.0.0.1",port:8299,rules:fs.readFileSync(path.resolve(__dirname,"../../firestore.rules"),"utf8")},
    storage:{host:"127.0.0.1",port:8399,rules:fs.readFileSync(path.resolve(__dirname,"../../storage.rules"),"utf8")}});
  await env.withSecurityRulesDisabled(async ctx=>{
    await setDoc(doc(ctx.firestore(),"platform_inspection_sessions/parent"),{uid:ROOT,verification:"email_code_v1",touchedAt:Date.now()});
    await setDoc(doc(ctx.firestore(),"platform_inspection_previews/grant"),{
      uid:"preview",rootUid:ROOT,active:true,expiresAt:Date.now()+3600000,parentSession:"parent",shopId:"s1",
      allowedUserUids:["customer"],allowedBookingIds:["b1"],allowedRequestIds:[]});
    for(const file of files) await uploadBytes(ref(ctx.storage(),file),new Uint8Array([1,2,3]),{contentType:"image/jpeg"});
  });
});
test.after(async()=>{if(env)await env.cleanup();});
const storage=()=>env.authenticatedContext("preview",{petnestInspection:true,inspectionGrant:"grant"}).storage();
test("selected shop attachments and linked user and booking photos are readable",async()=>{
  for(const file of [files[0],files[2],files[4]]) await assertSucceeds(getBytes(ref(storage(),file)));
});
test("other shop, unrelated user and unrelated booking attachments are denied",async()=>{
  for(const file of [files[1],files[3],files[5]]) await assertFails(getBytes(ref(storage(),file)));
});
test("inspection cannot upload, replace or delete files",async()=>{
  await assertFails(uploadBytes(ref(storage(),files[0]),new Uint8Array([9]),{contentType:"image/jpeg"}));
  await assertFails(uploadBytes(ref(storage(),"shop_chat/s1/customer/new.jpg"),new Uint8Array([9]),{contentType:"image/jpeg"}));
  await assertFails(deleteObject(ref(storage(),files[0])));
});
test("removing root session revokes private attachment reads",async()=>{
  await env.withSecurityRulesDisabled(async ctx=>deleteDoc(doc(ctx.firestore(),"platform_inspection_sessions/parent")));
  await assertFails(getBytes(ref(storage(),files[0])));
});
