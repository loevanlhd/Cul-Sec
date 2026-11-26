import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ⚠️ COLLE ICI TON ID CLIENT WEB (celui qui se termine par .apps.googleusercontent.com)
const String _webClientId = '59611614515-4ln5oncf6oic7murv3ungdagsobuin3r.apps.googleusercontent.com';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  User? get currentUser => _auth.currentUser;
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;
  String? get uid => _auth.currentUser?.uid;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await _googleSignIn.initialize(
        serverClientId: _webClientId,
      );
    } catch (e) {
      debugPrint('[Auth] Erreur d\'initialisation Google Sign-In : $e');
    }
  }

  Future<void> signInAnonymously() async {
    if (_auth.currentUser != null) return;
    try {
      await _auth.signInAnonymously();
    } catch (e) {
      debugPrint('[Auth] Erreur anonyme : $e');
    }
  }

  Future<UserCredential?> linkWithGoogle() async {
    try {
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthorizationClient authClient = googleUser.authorizationClient;
      final GoogleSignInClientAuthorization clientAuth =
          await authClient.authorizeScopes(<String>['email', 'profile']);
      
      final String accessToken = clientAuth.accessToken; 
      final String? idToken = googleUser.authentication.idToken;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final User? user = _auth.currentUser;
      if (user != null && user.isAnonymous) {
        try {
          return await user.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
            return await _auth.signInWithCredential(credential);
          }
          rethrow;
        }
      } else {
        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint('[Auth] Erreur de connexion Google : $e');
      return null;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) await _googleSignIn.signOut();
    await _auth.signOut();
  }
}