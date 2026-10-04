// 載入專案 firestore.rules，由 Firestore Emulator 執行真正的 allow / deny。
const fs = require("fs");
const path = require("path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  deleteDoc,
  updateDoc,
  where,
} = require("firebase/firestore");

const rulesPath = path.resolve(__dirname, "../../firestore.rules");
const staffPermissions = {
  manage_members: false,
  manage_bookings: true,
};

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-petnest-rules",
    firestore: {
      rules: fs.readFileSync(rulesPath, "utf8"),
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "shops/shopA"), {ownerUid: "ownerA"});
    await setDoc(doc(db, "shops/shopB"), {ownerUid: "ownerB"});
    await setDoc(doc(db, "shop_members/shopA_staffA"), {
      shopId: "shopA",
      uid: "staffA",
      role: "staff",
      permissions: staffPermissions,
    });
    await setDoc(doc(db, "shop_members/shopA_staffView"), {
      shopId: "shopA",
      uid: "staffView",
      role: "staff",
      permissions: {manage_members: false, manage_bookings: false, manage_chat: false},
    });
    await setDoc(doc(db, "shop_members/shopA_roomStaff"), {
      shopId: "shopA",
      uid: "roomStaff",
      role: "staff",
      permissions: {manage_room_dashboard: true, manage_bookings: false},
    });
    await setDoc(doc(db, "shops/shopA/room_calendar/room1_2026-10-01"), {
      roomId: "room1",
      date: "2026-10-01",
      status: "booked",
      bookingId: "bookingA",
    });
    await setDoc(doc(db, "shops/shopB/room_calendar/room9_2026-10-01"), {
      roomId: "room9",
      date: "2026-10-01",
      status: "booked",
      bookingId: "bookingB",
    });
    await setDoc(doc(db, "shop_members/shopA_ownerA"), {
      shopId: "shopA",
      uid: "ownerA",
      role: "owner",
      permissions: {manage_members: true},
    });
    await setDoc(doc(db, "shop_members/shopB_ownerB"), {
      shopId: "shopB",
      uid: "ownerB",
      role: "owner",
      permissions: {manage_members: true},
    });
    await setDoc(doc(db, "platform_users/platformAdmin"), {
      enabled: true,
      role: "super_admin",
      permissions: ["all"],
    });
    await setDoc(doc(db, "platform_users/platformViewer"), {
      enabled: true,
      role: "platform_staff",
      permissions: ["view_shops"],
    });
    await setDoc(doc(db, "bookings/bookingA"), {
      userId: "customerA",
      shopId: "shopA",
      status: "pending",
    });
    await setDoc(doc(db, "bookings/bookingB"), {
      userId: "customerB",
      shopId: "shopB",
      status: "pending",
    });
    await setDoc(doc(db, "shop_member_invites/shopA_staff@pet.test"), {
      shopId: "shopA",
      emailKey: "staff@pet.test",
      role: "staff",
      status: "pending",
      permissions: staffPermissions,
    });
    await setDoc(doc(db, "shop_member_invites/shopB_other@pet.test"), {
      shopId: "shopB",
      emailKey: "other@pet.test",
      role: "staff",
      status: "pending",
      permissions: staffPermissions,
    });
  });
});

function dbAs(uid, email) {
  return testEnv.authenticatedContext(uid, email ? {email} : {}).firestore();
}

test("TEST 1 customer A reads own booking", async () => {
  const ref = doc(dbAs("customerA"), "bookings/bookingA");
  await assertSucceeds(getDoc(ref));
});

test("TEST 2 customer A cannot read booking B", async () => {
  const ref = doc(dbAs("customerA"), "bookings/bookingB");
  await assertFails(getDoc(ref));
});

test("TEST 3 customer A queries own userId", async () => {
  const q = query(
      collection(dbAs("customerA"), "bookings"),
      where("userId", "==", "customerA"),
  );
  await assertSucceeds(getDocs(q));
});

test("TEST 4 customer A cannot query all bookings", async () => {
  await assertFails(getDocs(collection(dbAs("customerA"), "bookings")));
});

test("TEST 5 shop A staff reads shop A booking", async () => {
  await assertSucceeds(getDoc(doc(dbAs("staffA"), "bookings/bookingA")));
});

test("TEST 6 shop A staff cannot read shop B booking", async () => {
  await assertFails(getDoc(doc(dbAs("staffA"), "bookings/bookingB")));
});

test("TEST 7 shop A owner reads shop A booking", async () => {
  await assertSucceeds(getDoc(doc(dbAs("ownerA"), "bookings/bookingA")));
});

test("TEST 8 shop A owner cannot read shop B booking", async () => {
  await assertFails(getDoc(doc(dbAs("ownerA"), "bookings/bookingB")));
});

test("TEST 9 platform admin reads across shops", async () => {
  await assertSucceeds(getDoc(doc(dbAs("platformAdmin"), "bookings/bookingB")));
});

test("TEST 10 signed-in member cannot query another shop", async () => {
  const q = query(
      collection(dbAs("customerA"), "bookings"),
      where("shopId", "==", "shopB"),
  );
  await assertFails(getDocs(q));
});

test("TEST 11 customer cannot set depositStatus", async () => {
  await assertFails(updateDoc(doc(dbAs("customerA"), "bookings/bookingA"), {
    depositStatus: "confirmed",
  }));
});

test("TEST 12 customer cannot set assignedRoomId", async () => {
  await assertFails(updateDoc(doc(dbAs("customerA"), "bookings/bookingA"), {
    assignedRoomId: "room-1",
  }));
});

test("TEST 13 customer can cancel a pending booking", async () => {
  await assertSucceeds(updateDoc(doc(dbAs("customerA"), "bookings/bookingA"), {
    status: "cancelled",
    cancelReason: "不去了",
    cancelBy: "customer",
    cancelledAt: new Date(),
    updatedAt: new Date(),
  }));
});

test("TEST 14 customer cannot move cancelled back to confirmed", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), "bookings/bookingA"), {
      status: "cancelled",
    });
  });
  await assertFails(updateDoc(doc(dbAs("customerA"), "bookings/bookingA"), {
    status: "confirmed",
  }));
});

test("TEST 15 staff invite creates staff membership", async () => {
  await assertSucceeds(setDoc(doc(dbAs("staffNew", "staff@pet.test"), "shop_members/shopA_staffNew"), {
    shopId: "shopA",
    uid: "staffNew",
    emailKey: "staff@pet.test",
    role: "staff",
    permissions: staffPermissions,
  }));
});

test("TEST 16 staff invite cannot create owner", async () => {
  await assertFails(setDoc(doc(dbAs("staffNew", "staff@pet.test"), "shop_members/shopA_staffNew"), {
    shopId: "shopA",
    uid: "staffNew",
    emailKey: "staff@pet.test",
    role: "owner",
    permissions: staffPermissions,
  }));
});

test("TEST 17 staff invite cannot add permissions", async () => {
  await assertFails(setDoc(doc(dbAs("staffNew", "staff@pet.test"), "shop_members/shopA_staffNew"), {
    shopId: "shopA",
    uid: "staffNew",
    emailKey: "staff@pet.test",
    role: "staff",
    permissions: {
      manage_members: true,
      manage_bookings: true,
    },
  }));
});

test("TEST 18 signed-in member cannot read someone else's invite", async () => {
  await assertFails(getDoc(doc(
      dbAs("stranger", "stranger@pet.test"),
      "shop_member_invites/shopA_staff@pet.test",
  )));
});

test("TEST 19 invitee can read their own invite", async () => {
  await assertSucceeds(getDoc(doc(
      dbAs("staffNew", "staff@pet.test"),
      "shop_member_invites/shopA_staff@pet.test",
  )));
});

test("TEST 20 shop A owner cannot read shop B invite", async () => {
  await assertFails(getDoc(doc(
      dbAs("ownerA"),
      "shop_member_invites/shopB_other@pet.test",
  )));
});

test("TEST 21 read-only staff reads shop A booking", async () => {
  await assertSucceeds(getDoc(doc(dbAs("staffView"), "bookings/bookingA")));
});

test("TEST 22 read-only staff cannot update shop A booking", async () => {
  await assertFails(updateDoc(doc(dbAs("staffView"), "bookings/bookingA"), {
    status: "confirmed",
    updatedAt: new Date(),
  }));
});

test("TEST 23 booking manager can confirm an operational status", async () => {
  await assertSucceeds(updateDoc(doc(dbAs("staffA"), "bookings/bookingA"), {
    status: "confirmed",
    updatedAt: new Date(),
  }));
});

test("TEST 24 shop A member cannot update shop B booking", async () => {
  await assertFails(updateDoc(doc(dbAs("staffA"), "bookings/bookingB"), {
    status: "confirmed",
    updatedAt: new Date(),
  }));
});

test("TEST 25 manager cannot change booking shopId", async () => {
  await assertFails(updateDoc(doc(dbAs("staffA"), "bookings/bookingA"), {
    shopId: "shopB",
  }));
});

test("TEST 26 manager cannot change booking userId", async () => {
  await assertFails(updateDoc(doc(dbAs("staffA"), "bookings/bookingA"), {
    userId: "customerB",
  }));
});

test("TEST 27 manager cannot set depositStatus to paid", async () => {
  await assertFails(updateDoc(doc(dbAs("staffA"), "bookings/bookingA"), {
    depositStatus: "paid",
  }));
});

test("TEST 28 manager cannot set paymentStatus to paid", async () => {
  await assertFails(updateDoc(doc(dbAs("staffA"), "bookings/bookingA"), {
    paymentStatus: "paid",
  }));
});

test("TEST 29 read-only staff cannot create source=admin booking", async () => {
  await assertFails(setDoc(doc(dbAs("staffView"), "bookings/adminByStaff"), {
    shopId: "shopA",
    userId: "customerA",
    status: "pending",
    source: "admin",
  }));
});

test("TEST 30 booking manager cannot client-create source=admin booking", async () => {
  await assertFails(setDoc(doc(dbAs("staffA"), "bookings/adminByManager"), {
    shopId: "shopA",
    userId: "customerA",
    status: "pending",
    source: "admin",
  }));
});

test("TEST 31 shop A manager cannot create shop B admin booking", async () => {
  await assertFails(setDoc(doc(dbAs("staffA"), "bookings/adminCrossShop"), {
    shopId: "shopB",
    userId: "customerB",
    status: "pending",
    source: "admin",
  }));
});

test("TEST 32 client cannot delete a booking", async () => {
  await assertFails(deleteDoc(doc(dbAs("staffA"), "bookings/bookingA")));
});

test("TEST 33 read without manage cannot update", async () => {
  await assertFails(updateDoc(doc(dbAs("staffView"), "bookings/bookingA"), {
    note: "只看不能改",
  }));
});

test("TEST 34 platform read-only can read but not update", async () => {
  await assertSucceeds(getDoc(doc(dbAs("platformViewer"), "bookings/bookingB")));
  await assertFails(updateDoc(doc(dbAs("platformViewer"), "bookings/bookingB"), {
    status: "confirmed",
    updatedAt: new Date(),
  }));
});

test("TEST 35 super admin can confirm a booking", async () => {
  await assertSucceeds(updateDoc(doc(dbAs("platformAdmin"), "bookings/bookingB"), {
    status: "confirmed",
    updatedAt: new Date(),
  }));
});

test("daycare capacity counter is not client writable", async () => {
  const counter = "shops/shopA/daycare_capacity/2026-10-04";
  const reservation = `${counter}/reservations/bookingA`;
  await assertFails(setDoc(doc(dbAs("customerA"), counter), {
    dateKey: "2026-10-04",
    reservedPets: 0,
  }));
  await assertFails(setDoc(doc(dbAs("ownerA"), counter), {
    dateKey: "2026-10-04",
    reservedPets: 1,
  }));
  await assertFails(setDoc(doc(dbAs("ownerA"), reservation), {pets: 1}));
  await assertFails(getDoc(doc(dbAs("customerA"), counter)));
  await assertFails(getDoc(doc(dbAs("ownerA"), counter)));
});

test("rules file loaded by the emulator", () => {
  assert.equal(fs.existsSync(rulesPath), true);
  const source = fs.readFileSync(rulesPath, "utf8");
  const block = source.match(
      /match \/room_calendar\/\{calendarId\} \{([\s\S]*?)\n\}/,
  );
  assert.ok(block);
  assert.equal(block[1].includes("allow read: if true"), false);
  assert.equal(block[1].includes("canReadRoomCalendar(shopId)"), true);
});

const roomCalendarA = "shops/shopA/room_calendar/room1_2026-10-01";
const roomCalendarB = "shops/shopB/room_calendar/room9_2026-10-01";

test("room calendar TEST 1 anonymous cannot read", async () => {
  await assertFails(getDoc(doc(
      testEnv.unauthenticatedContext().firestore(),
      roomCalendarA,
  )));
});

test("room calendar TEST 2 customer cannot read", async () => {
  await assertFails(getDoc(doc(dbAs("customerA"), roomCalendarA)));
});

test("room calendar TEST 3 owner can read own shop", async () => {
  await assertSucceeds(getDoc(doc(dbAs("ownerA"), roomCalendarA)));
});

test("room calendar TEST 4 housekeeping staff can read", async () => {
  await assertSucceeds(getDoc(doc(dbAs("roomStaff"), roomCalendarA)));
});

test("room calendar TEST 5 shop A staff cannot read shop B", async () => {
  await assertFails(getDoc(doc(dbAs("roomStaff"), roomCalendarB)));
  await assertFails(getDoc(doc(dbAs("ownerA"), roomCalendarB)));
});

test("room calendar TEST 6 customer cannot write", async () => {
  await assertFails(setDoc(doc(dbAs("customerA"), roomCalendarA), {
    status: "closed",
  }));
});

test("room calendar TEST 7 shop A staff cannot update shop B", async () => {
  await assertFails(updateDoc(doc(dbAs("roomStaff"), roomCalendarB), {
    status: "closed",
  }));
});

test("room calendar TEST 8 housekeeping staff can update own shop", async () => {
  await assertSucceeds(updateDoc(doc(dbAs("roomStaff"), roomCalendarA), {
    status: "closed",
  }));
});

test("room calendar TEST 9 staff without room permission cannot update", async () => {
  await assertFails(updateDoc(doc(dbAs("staffView"), roomCalendarA), {
    status: "closed",
  }));
});

test("room calendar TEST 10 staff without room permission cannot delete", async () => {
  await assertFails(deleteDoc(doc(dbAs("staffView"), roomCalendarA)));
  await assertFails(deleteDoc(doc(dbAs("customerA"), roomCalendarA)));
});
