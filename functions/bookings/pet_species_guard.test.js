const test = require("node:test");
const assert = require("node:assert/strict");
const {petSpecies, assertSpecies, loadEligiblePets} = require("./pet_species_guard");
function db(data) {
  const ref = (path) => ({collection: (p) => ref(path + "/" + p), doc: (p) => ref(path + "/" + p),
    get: async () => ({exists: !!data[path], data: () => data[path]})});
  return {collection: (p) => ref(p)};
}
test("species uses explicit source over stale legacy fields and unknown is denied", () => {
  assert.equal(petSpecies({species:"dog",type:"cat"}), "dog");
  assert.equal(petSpecies({gender:"母貓"}), "cat");
  assert.throws(() => assertSpecies({type:"柴犬"}, ["cat"]));
  assert.throws(() => assertSpecies({species:"dog"}, ["cat"]));
  assert.throws(() => assertSpecies({species:"cat"}, ["dog"]));
});
test("booking hydrates authoritative vaccine/species and rejects dog in cat booking", async () => {
  const store = db({"user_profiles/u/pets/c": {name:"貓",species:"cat",vaccineTypes:"紀錄"},
    "user_profiles/u/pets/d": {name:"狗",species:"dog"}});
  const input = {userId:"u",shopId:"s",petIds:["c"]};
  const pets = await loadEligiblePets(store, input);
  assert.equal(pets[0].vaccineTypes, "紀錄");
  await assert.rejects(loadEligiblePets(store, {...input,petIds:["d"]}));
  await assert.rejects(loadEligiblePets(store, {...input,petIds:["missing"]}));
  await assert.rejects(loadEligiblePets(store, {...input,petIds:["c","c"]}));
  await assert.rejects(loadEligiblePets(store, {...input,petIds:["../c"]}));
});
test("shop manual pets can only be used by staff", async () => {
  const store = db({"shops/s/members/u/pets/c": {species:"cat",name:"手動貓"}});
  const input = {userId:"u",shopId:"s",petIds:["c"]};
  await assert.rejects(loadEligiblePets(store, input));
  assert.equal((await loadEligiblePets(store, {...input,staff:true}))[0].name, "手動貓");
});
