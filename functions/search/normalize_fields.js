// 檔案名稱：functions/search/normalize_fields.js
// 功能說明：訂單／會員搜尋正規化欄位，寫入時補上。

function digitsOnly(raw) {
  return String(raw || "").replace(/[^0-9]/g, "");
}

function bookingSearchFields(data) {
  const name = String(data.customerName || "").trim().toLowerCase();
  const phone = String(data.customerPhone || "");
  const code = String(data.bookingCode || data.bookingId || "")
      .trim().toLowerCase().replace(/\s+/g, "");
  const digits = digitsOnly(phone);
  const pets = Array.isArray(data.pets) ? data.pets : [];
  const petNames = [];
  for (const item of pets) {
    if (!item || typeof item !== "object") {
      continue;
    }
    const petName = String(item.name || "").trim().toLowerCase();
    if (!petName || petNames.includes(petName)) {
      continue;
    }
    petNames.push(petName);
    if (petNames.length >= 8) {
      break;
    }
  }
  return {
    customerNameNormalized: name,
    customerPhoneDigits: digits,
    customerPhoneLast4: digits.length >= 4 ? digits.slice(-4) : digits,
    customerPhoneLast5: digits.length >= 5 ? digits.slice(-5) : digits,
    bookingCodeNormalized: code,
    petNamesNormalized: petNames,
  };
}

function namePrefixes(name) {
  const normalized = String(name || "").trim().toLowerCase();
  const prefixes = [];
  const end = Math.min(normalized.length, 8);
  for (let i = 1; i <= end; i++) {
    prefixes.push(normalized.slice(0, i));
  }
  return prefixes;
}

function memberSearchFields(data) {
  const name = String(data.name || "");
  const phone = String(data.phone || "");
  const email = String(data.email || "").trim().toLowerCase();
  const digits = digitsOnly(phone);
  const tags = Array.isArray(data.tags) ? data.tags.map(String) : [];
  const status = String(data.status || "");
  const source = String(data.source || data.memberSource || "app").trim() ||
    "app";
  return {
    nameNormalized: name.trim().toLowerCase(),
    namePrefixes: namePrefixes(name),
    phoneDigits: digits,
    phoneLast4: digits.length >= 4 ? digits.slice(-4) : digits,
    phoneLast5: digits.length >= 5 ? digits.slice(-5) : digits,
    emailNormalized: email,
    isArchived: status === "archived",
    isMerged: status === "merged",
    isBlacklisted: data.blacklisted === true || data.isBlocked === true,
    isVip: tags.includes("vip"),
    memberSource: source,
  };
}

module.exports = {
  digitsOnly,
  bookingSearchFields,
  memberSearchFields,
};
