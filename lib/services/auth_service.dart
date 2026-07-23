import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Google Sign-In yapılandırması
  // scopes: 'email' alanı, kullanıcının e-posta adresine erişmek için gereklidir
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  /// Signs the user in using Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Google ile giriş penceresini aç
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Kullanıcı iptal ettiyse

      // 2. Google yetkilendirme detaylarını al
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Firebase için kimlik bilgilerini oluştur
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Firebase'e bu bilgilerle giriş yap
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("Google Sign-In Error: $e");
      return null;
    }
  }

  /// Registers a new user with email and password
  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      print("Registration Error: ${e.message}");
      return null;
    } catch (e) {
      print("Unexpected Error: $e");
      return null;
    }
  }

  /// Signs the user out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Returns the current user
  User? get currentUser => _auth.currentUser;
}