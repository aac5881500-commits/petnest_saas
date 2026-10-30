import 'package:firebase_auth/firebase_auth.dart';

/// Anonymous identities authorize storefront visits, not membership features.
bool isRegisteredMember(User? user) => user != null && !user.isAnonymous;
