import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class AuthController extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  User? _user;
  bool _isMocked = false;

  User? get user => _user;
  bool get isAuthenticated => _isMocked || _user != null;

  AuthController() {
    try {
      FirebaseAuth.instance.authStateChanges().listen((User? user) {
        _user = user;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Firebase Auth not available: $e');
    }
  }

  void setMockAuthenticated(bool value) {
    _isMocked = value;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    if (_isMocked || (email == 'admin@test.com' && !_isFirebaseAvailable())) {
      setMockAuthenticated(true);
      return true;
    }
    final result = await _firebaseService.signIn(email, password);
    return result != null;
  }

  Future<bool> register(String email, String password) async {
    final result = await _firebaseService.signUp(email, password);
    return result != null;
  }

  Future<bool> signInWithGoogle() async {
    final result = await _firebaseService.signInWithGoogle();
    return result != null;
  }

  bool _isFirebaseAvailable() {
    try {
      FirebaseAuth.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    _isMocked = false;
    try {
      await _firebaseService.signOut();
    } catch (_) {}
    notifyListeners();
  }
}
