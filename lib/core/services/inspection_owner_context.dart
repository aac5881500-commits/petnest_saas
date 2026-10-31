class InspectionOwnerContext {
  static bool active = false;
  static void Function()? onExit;
  static void Function(String)? onView;
  static String shopId = '';
  static String ownerUid = '';
  // Read lens only; SDK authentication and tokens remain the anonymous viewer.
  static String readUid(String actualUid) => active ? ownerUid : actualUid;
  static bool forShop(String id) => active && id == shopId;
  static void clear() {
    active = false;
    onExit = null;
    onView = null;
    shopId = '';
    ownerUid = '';
  }
}
