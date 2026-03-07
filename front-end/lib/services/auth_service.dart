import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lokseva/services/api_service.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final ApiService _apiService = ApiService();

  /// Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Complete sign-in flow: Firebase Auth + Backend Sync
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Step 1: Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw AuthException('Sign-in cancelled by user');
      }

      // Step 2: Get Google Auth credentials
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 3: Sign in to Firebase
      final UserCredential userCredential =
      await _firebaseAuth.signInWithCredential(credential);

      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw AuthException('Firebase sign-in failed');
      }

      // Step 4: Sync with Backend (POST to /api/user/profile)
      // This creates user if new, or fetches existing profile
      final UserProfileResponse backendProfile = await _apiService.saveUserProfile(
        email: firebaseUser.email!,
        name: firebaseUser.displayName ?? 'User',
        profilePic: firebaseUser.photoURL,
      );

      // Step 5: Determine if new user (profile incomplete)
      final bool isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      return AuthResult(
        firebaseUser: firebaseUser,
        userProfile: backendProfile,
        isNewUser: isNewUser,
      );

    } on FirebaseAuthException catch (e) {
      throw AuthException('Firebase error: ${e.message}');
    } on ApiException catch (e) {
      // If backend fails, still allow user in but flag it
      throw AuthException('Backend sync failed: ${e.message}');
    } catch (e) {
      throw AuthException('Sign-in failed: $e');
    }
  }

  /// Sign out from both Firebase and Google
  Future<void> signOut() async {
    await Future.wait([
      _firebaseAuth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  Future<void> createOrUpdateProfile({required email, required name, required profilePic, int? age, required String phone, required String address, required String medicalHistory}) async {}
}

// =============================================================================
// AUTH MODELS
// =============================================================================

class AuthResult {
  final User firebaseUser;
  final UserProfileResponse userProfile;
  final bool isNewUser;

  AuthResult({
    required this.firebaseUser,
    required this.userProfile,
    required this.isNewUser,
  });
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}