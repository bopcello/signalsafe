import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/admin_user.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  StreamSubscription<User?>? _firebaseAuthSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;

  final _userController = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  Stream<AppUser?> get authStateChanges => _userController.stream;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isStudent => _currentUser != null && !_currentUser!.isAdmin;

  /// Initialize Auth Listener
  void initialize() {
    try {
      _firebaseAuthSub = _auth.authStateChanges().listen((firebaseUser) {
        if (firebaseUser == null) {
          _userDocSub?.cancel();
          _userDocSub = null;
          _currentUser = null;
          _userController.add(null);
        } else {
          _syncUserWithFirestore(firebaseUser);
        }
      });
    } catch (e) {
      debugPrint('[AuthService] Firebase Auth init warning: $e');
    }
  }

  /// Syncs user doc with Firestore in real-time
  /// By default creates document with `isAdmin: false` (Student)
  Future<void> _syncUserWithFirestore(User firebaseUser) async {
    final uid = firebaseUser.uid;
    final docRef = _firestore.collection('users').doc(uid);

    debugPrint('[AuthService] Syncing user to Firestore: $uid (${firebaseUser.email})');

    try {
      final doc = await docRef.get();
      if (!doc.exists) {
        // Initial user registration: DEFAULT isAdmin = false
        final newUser = AppUser(
          uid: uid,
          email: firebaseUser.email ?? 'student@campus.edu',
          displayName: (firebaseUser.displayName != null && firebaseUser.displayName!.isNotEmpty)
              ? firebaseUser.displayName!
              : (firebaseUser.email?.split('@').first ?? 'Campus User'),
          isAdmin: false,
          createdAt: DateTime.now(),
          photoUrl: firebaseUser.photoURL,
        );

        await docRef.set({
          'uid': uid,
          'email': newUser.email,
          'displayName': newUser.displayName,
          'isAdmin': false,
          'createdAt': DateTime.now().toIso8601String(),
          'photoUrl': newUser.photoUrl,
        }, SetOptions(merge: true));

        debugPrint('[AuthService] Successfully saved new user document to Firestore: users/$uid');
        _currentUser = newUser;
        _userController.add(_currentUser);
      } else {
        final data = doc.data() ?? {};
        // Make sure user fields are up to date without adding 'role'
        await docRef.set({
          'uid': uid,
          'email': firebaseUser.email ?? data['email'] ?? '',
          'displayName': (firebaseUser.displayName != null && firebaseUser.displayName!.isNotEmpty)
              ? firebaseUser.displayName!
              : (data['displayName'] ?? firebaseUser.email?.split('@').first ?? 'Campus User'),
          'photoUrl': firebaseUser.photoURL ?? data['photoUrl'],
        }, SetOptions(merge: true));

        _currentUser = AppUser.fromMap(uid, data);
        _userController.add(_currentUser);
        debugPrint('[AuthService] Loaded existing user document from Firestore: users/$uid (isAdmin=${_currentUser?.isAdmin})');
      }

      // Listen to real-time changes in Firestore:
      // When IT admin flips `isAdmin: true` in Firebase console, this immediately updates!
      _userDocSub?.cancel();
      _userDocSub = docRef.snapshots().listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          final data = snapshot.data()!;
          _currentUser = AppUser.fromMap(uid, data);
          _userController.add(_currentUser);
          debugPrint('[AuthService] Live DB update for $uid: isAdmin = ${_currentUser?.isAdmin}');
        }
      }, onError: (err) {
        debugPrint('[AuthService] Live DB listener error: $err');
      });
    } catch (e) {
      debugPrint('[AuthService] Firestore sync error: $e');
      _currentUser = AppUser(
        uid: uid,
        email: firebaseUser.email ?? 'student@campus.edu',
        displayName: firebaseUser.displayName ?? (firebaseUser.email?.split('@').first ?? 'Campus User'),
        isAdmin: false,
        createdAt: DateTime.now(),
        photoUrl: firebaseUser.photoURL,
      );
      _userController.add(_currentUser);
    }
  }

  /// Email & Password Sign In
  Future<AppUser> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    await _syncUserWithFirestore(user);
    return _currentUser!;
  }

  /// Email & Password Sign Up (Creates Student by default)
  Future<AppUser> signUpWithEmail(String email, String password, String displayName) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    if (displayName.isNotEmpty) {
      await user.updateDisplayName(displayName);
    }
    await _syncUserWithFirestore(user);
    return _currentUser!;
  }

  /// Google Sign In
  Future<AppUser?> signInWithGoogle() async {
    if (kIsWeb) {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
      if (userCredential.user != null) {
        await _syncUserWithFirestore(userCredential.user!);
        return _currentUser;
      }
    } else {
      // On desktop / mobile
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      try {
        final UserCredential userCredential = await _auth.signInWithProvider(googleProvider);
        if (userCredential.user != null) {
          await _syncUserWithFirestore(userCredential.user!);
          return _currentUser;
        }
      } catch (e) {
        debugPrint('[AuthService] signInWithProvider error: $e, trying GoogleSignIn package...');
        await GoogleSignIn.instance.initialize();
        final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate();
        final GoogleSignInAuthentication googleAuth = account.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = await _auth.signInWithCredential(credential);
        if (userCredential.user != null) {
          await _syncUserWithFirestore(userCredential.user!);
          return _currentUser;
        }
      }
    }
    return null;
  }

  /// Flip Admin Boolean in Database (`isAdmin`)
  /// The user requested: "i will flip only one boolean in database to make any user admin"
  /// This function writes `isAdmin: makeAdmin` directly to `users/{uid}` in Firestore
  Future<void> setAdminStatusInDatabase(String uid, bool makeAdmin) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'isAdmin': makeAdmin,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[AuthService] Successfully flipped isAdmin=$makeAdmin in Firestore for $uid');
    } catch (e) {
      debugPrint('[AuthService] Note: Firestore set notice (updating local state): $e');
    }

    // Update local state immediately as well
    if (_currentUser != null && _currentUser!.uid == uid) {
      _currentUser = _currentUser!.copyWith(isAdmin: makeAdmin);
      _userController.add(_currentUser);
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
      await _auth.signOut();
    } catch (_) {}
    _userDocSub?.cancel();
    _userDocSub = null;
    _currentUser = null;
    _userController.add(null);
  }

  void dispose() {
    _firebaseAuthSub?.cancel();
    _userDocSub?.cancel();
    _userController.close();
  }
}
