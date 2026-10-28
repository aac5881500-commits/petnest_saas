const {HttpsError} = require("firebase-functions/v2/https");

function normalizeSpecies(value) {
  const text = String(value || "").trim().toLowerCase();
  if (["cat", "貓", "貓咪", "貓貓"].includes(text)) return "cat";
  if (["dog", "狗", "狗狗", "犬"].includes(text)) return "dog";
  return "";
}
function petSpecies(pet) {
  return normalizeSpecies(pet.species) || normalizeSpecies(pet.type) ||
    (["公貓", "母貓"].includes(pet.gender) ? "cat" :
      ["公狗", "母狗"].includes(pet.gender) ? "dog" : "");
}
function assertSpecies(pet, accepted) {
  const species = petSpecies(pet);
  if (!accepted.includes(species)) {
    throw new HttpsError("failed-precondition",
        "寵物種類不符合此服務，請確認貓咪／狗狗資料後重新選擇");
  }
  return species;
}
async function loadEligiblePets(db, {userId, shopId, petIds, accepted = ["cat"], staff = false, transaction}) {
  if (!Array.isArray(petIds) || !petIds.length || petIds.length > 10 ||
      new Set(petIds).size !== petIds.length) {
    throw new HttpsError("invalid-argument", "請選擇有效寵物");
  }
  const read = (ref) => transaction ? transaction.get(ref) : ref.get();
  const pets = [];
  for (const id of petIds) {
    if (typeof id !== "string" || !id || id.includes("/")) {
      throw new HttpsError("invalid-argument", "寵物編號無效");
    }
    let snap = await read(db.collection("user_profiles").doc(userId).collection("pets").doc(id));
    if (!snap.exists && staff) {
      snap = await read(db.collection("shops").doc(shopId).collection("members").doc(userId).collection("pets").doc(id));
    }
    if (!snap.exists) throw new HttpsError("failed-precondition", "找不到寵物，請重新選擇");
    const pet = snap.data() || {};
    const species = assertSpecies(pet, accepted);
    // Keep the snapshot independent of client-submitted species and vaccines.
    const out = {...pet, petId: id, species, type: species};
    delete out.customFormAnswersByShop;
    delete out.createdAt;
    delete out.updatedAt;
    pets.push(out);
  }
  return pets;
}
module.exports = {normalizeSpecies, petSpecies, assertSpecies, loadEligiblePets};
