import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      // Firebase özel hata mesajlarını loglayın
      print("Firebase Auth Error: ${e.message}");
      return null;
    } catch (e) {
      print("General Error: $e");
      return null;
    }
  }
}