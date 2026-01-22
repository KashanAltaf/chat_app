import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? gUser = await GoogleSignIn().signIn();

    if (gUser == null) {
      throw Exception('Sign in cancelled by user');
    }

    final GoogleSignInAuthentication gAuth = await gUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    // 1️⃣ Sign in first
    final UserCredential userCredential =
    await _auth.signInWithCredential(credential);

    final User user = userCredential.user!;

    // 2️⃣ Store user in Firestore (only once)
    final userRef = _firestore.collection('users').doc(user.uid);

    final doc = await userRef.get();

    if (!doc.exists) {
      await userRef.set({
        'uid': user.uid,
        'email': user.email,
        'name': user.displayName,
        'photoUrl': user.photoURL,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'typingTo': '',
        'provider': 'google',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return userCredential;
  }
}
