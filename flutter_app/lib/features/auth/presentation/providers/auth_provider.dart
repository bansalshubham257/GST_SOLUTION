// lib/features/auth/presentation/providers/auth_provider.dart

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/entities/user_entity.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_constants.dart';

// ─── Auth State ────────────────────────────────────────────────────────────────

class AuthState {
  final bool isLoggedIn;
  final bool isBusinessSetupDone;
  final UserEntity? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.isBusinessSetupDone = false,
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    bool? isBusinessSetupDone,
    UserEntity? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isBusinessSetupDone: isBusinessSetupDone ?? this.isBusinessSetupDone,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Auth State Provider ───────────────────────────────────────────────────────

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthState> {
  late final FirebaseAuth _firebaseAuth;
  late final ApiClient _apiClient;
  bool _firebaseAvailable = false;

  @override
  Future<AuthState> build() async {
    _apiClient = ref.read(apiClientProvider);

    // Try Firebase
    try {
      _firebaseAuth = FirebaseAuth.instance;
      _firebaseAvailable = true;
    } catch (_) {
      _firebaseAvailable = false;
    }

    // 1. Try Firebase user session restoration
    if (_firebaseAvailable) {
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        try {
          final response = await _apiClient.get(ApiConstants.me);
          final userData = response.data as Map<String, dynamic>;
          final userEntity = _parseUserEntity(userData);

          return AuthState(
            isLoggedIn: true,
            isBusinessSetupDone: LocalStorage.isBusinessSetupDone(),
            user: userEntity,
          );
        } catch (_) {
          final localDone = LocalStorage.isBusinessSetupDone();
          return AuthState(
            isLoggedIn: true,
            isBusinessSetupDone: localDone,
            user: UserEntity(
              id: firebaseUser.uid,
              name: firebaseUser.displayName,
              email: firebaseUser.email,
              phone: firebaseUser.phoneNumber,
              photoUrl: firebaseUser.photoURL,
              isBusinessSetupDone: localDone,
              createdAt: DateTime.now(),
            ),
          );
        }
      }
    }

    // 2. Try stored token (custom JWT from db-login)
    final storedToken = await SecureStorage.read(AppConstants.tokenKey);
    if (storedToken != null) {
      try {
        final response = await _apiClient.get(ApiConstants.me);
        final userData = response.data as Map<String, dynamic>;
        final userEntity = _parseUserEntity(userData);

        return AuthState(
          isLoggedIn: true,
          isBusinessSetupDone: LocalStorage.isBusinessSetupDone(),
          user: userEntity,
        );
      } catch (_) {
        await SecureStorage.deleteAll();
      }
    }

    return const AuthState(isLoggedIn: false);
  }

  // ─── Custom Username/Password Login ─────────────────────────────────────────

  Future<void> loginWithUsername({
    required String username,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final response = await _apiClient.post(
        ApiConstants.dbLogin,
        data: {'username': username, 'password': password},
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final userData = data['user'] as Map<String, dynamic>;
      final userEntity = _parseUserEntity(userData);

      await SecureStorage.write(AppConstants.tokenKey, token);
      await SecureStorage.write(AppConstants.userIdKey, userEntity.id);
      if (userEntity.businessId != null) {
        await SecureStorage.write(AppConstants.businessIdKey, userEntity.businessId!);
      }

      state = AsyncData(AuthState(
        isLoggedIn: true,
        isBusinessSetupDone: LocalStorage.isBusinessSetupDone(),
        user: userEntity,
      ));
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?.toString() ?? 'Login failed. Check your credentials.';
      state = AsyncError(msg, StackTrace.current);
    } catch (e) {
      state = AsyncError('Login failed: ${e.toString()}', StackTrace.current);
    }
  }

  // ─── Demo / Try Mode ───────────────────────────────────────────────────────

  Future<void> tryDemo() async {
    state = const AsyncLoading();
    try {
      final response = await _apiClient.post(ApiConstants.dbDemoLogin);

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final userData = data['user'] as Map<String, dynamic>;
      final userEntity = _parseUserEntity(userData);

      await SecureStorage.write(AppConstants.tokenKey, token);
      await SecureStorage.write(AppConstants.userIdKey, userEntity.id);
      if (userEntity.businessId != null) {
        await SecureStorage.write(AppConstants.businessIdKey, userEntity.businessId!);
      }

      state = AsyncData(AuthState(
        isLoggedIn: true,
        isBusinessSetupDone: LocalStorage.isBusinessSetupDone(),
        user: userEntity,
      ));
    } catch (e) {
      // Fallback: offline demo if backend unreachable
      final demoUser = UserEntity(
        id: 'demo-user-001',
        name: 'Demo User',
        plan: 'free',
        maxStaff: 2,
        maxServices: 2,
        maxSales: 2,
        isBusinessSetupDone: true,
        businessId: 'demo-business-001',
        createdAt: DateTime(2024, 1, 1),
      );
      state = AsyncData(AuthState(
        isLoggedIn: true,
        isBusinessSetupDone: true,
        user: demoUser,
      ));
    }
  }

  // ─── Phone OTP Login ────────────────────────────────────────────────────────

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
  }) async {
    if (!_firebaseAvailable) {
      onError('Firebase not configured.');
      return;
    }
    state = const AsyncLoading();
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          state = AsyncError(e.message ?? 'OTP failed', StackTrace.current);
          onError(e.message ?? 'OTP verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          state = const AsyncData(AuthState(isLoading: false));
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      state = AsyncError(e.toString(), StackTrace.current);
      onError('Firebase not configured. Please set up Firebase.');
    }
  }

  Future<void> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    state = const AsyncLoading();
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      await _signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      state = AsyncError(e.message ?? 'OTP verification failed', StackTrace.current);
    }
  }

  // ─── Google Login ───────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        state = const AsyncData(AuthState(isLoading: false));
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _signInWithCredential(credential);
    } catch (e) {
      state = AsyncError(e.toString(), StackTrace.current);
    }
  }

  // ─── Email Login ────────────────────────────────────────────────────────────

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (!_firebaseAvailable) return;
    state = const AsyncLoading();
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _syncUserWithBackend();
    } on FirebaseAuthException catch (e) {
      state = AsyncError(_getFirebaseErrorMessage(e), StackTrace.current);
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    if (!_firebaseAvailable) return;
    state = const AsyncLoading();
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      await _syncUserWithBackend();
    } on FirebaseAuthException catch (e) {
      state = AsyncError(_getFirebaseErrorMessage(e), StackTrace.current);
    }
  }

  // ─── Demo Login (legacy, kept for compat) ──────────────────────────────────

  Future<void> demoLogin() async {
    await tryDemo();
  }

  // ─── Sign Out ────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    if (_firebaseAvailable) {
      try {
        await _firebaseAuth.signOut();
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
    await SecureStorage.deleteAll();
    state = const AsyncData(AuthState(isLoggedIn: false));
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Future<void> _signInWithCredential(AuthCredential credential) async {
    final result = await _firebaseAuth.signInWithCredential(credential);
    final token = await result.user?.getIdToken();
    if (token != null) {
      await SecureStorage.write(AppConstants.tokenKey, token);
    }
    await _syncUserWithBackend();
  }

  Future<void> _syncUserWithBackend() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    try {
      final response = await _apiClient.post(ApiConstants.login, data: {
        'uid': user.uid,
        'email': user.email,
        'phone': user.phoneNumber,
        'name': user.displayName,
        'photoUrl': user.photoURL,
      });

      final userData = response.data as Map<String, dynamic>;
      final userEntity = _parseUserEntity(userData['user'] ?? userData);

      await SecureStorage.write(AppConstants.userIdKey, userEntity.id);
      if (userEntity.businessId != null) {
        await SecureStorage.write(AppConstants.businessIdKey, userEntity.businessId!);
      }

      state = AsyncData(AuthState(
        isLoggedIn: true,
        isBusinessSetupDone: LocalStorage.isBusinessSetupDone(),
        user: userEntity,
      ));
    } catch (e) {
      final userEntity = UserEntity(
        id: user.uid,
        name: user.displayName,
        email: user.email,
        phone: user.phoneNumber,
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
      );
      state = AsyncData(AuthState(
        isLoggedIn: true,
        isBusinessSetupDone: false,
        user: userEntity,
      ));
    }
  }

  UserEntity _parseUserEntity(Map<String, dynamic> data) {
    return UserEntity(
      id: data['id']?.toString() ?? data['uid'] ?? '',
      name: data['name'],
      email: data['email'],
      phone: data['phone'],
      photoUrl: data['photoUrl'] ?? data['photo_url'],
      isBusinessSetupDone: data['isBusinessSetupDone'] ?? data['business_setup_done'] ?? false,
      businessId: data['businessId']?.toString() ?? data['business_id']?.toString(),
      plan: data['plan']?.toString() ?? 'free',
      maxStaff: data['maxStaff'] != null ? int.tryParse(data['maxStaff'].toString()) ?? 999 : 999,
      maxServices: data['maxServices'] != null ? int.tryParse(data['maxServices'].toString()) ?? 999 : 999,
      maxSales: data['maxSales'] != null ? int.tryParse(data['maxSales'].toString()) ?? 999 : 999,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found': return 'No account found with this email';
      case 'wrong-password': return 'Incorrect password';
      case 'email-already-in-use': return 'Email already registered';
      case 'invalid-email': return 'Invalid email address';
      case 'weak-password': return 'Password must be at least 6 characters';
      case 'too-many-requests': return 'Too many attempts. Please try again later';
      default: return e.message ?? 'Authentication failed';
    }
  }
}

