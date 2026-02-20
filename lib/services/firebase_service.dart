import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/student.dart';
import '../models/attendance.dart';

class FirebaseService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Auth
  Future<UserCredential?> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint('Sign Up error: $e');
      return null;
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return null;
    }
  }
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      print('Firebase Auth error (falling back to mock): $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  // Students
  Future<void> registerStudent(Student student) async {
    try {
      // Explicitly serialize to ensure 'embedding' is stored as a List<double>
      final mapData = {
        'id': student.id,
        'name': student.name,
        'rollNumber': student.rollNumber,
        'embedding': student.embedding,
        'createdAt': student.createdAt.toIso8601String(),
      };
      
      debugPrint('FIREBASE: Saving Student ${student.name}');
      debugPrint('FIREBASE: Embedding Length: ${student.embedding.length}');
      debugPrint('FIREBASE: Embedding Type: ${student.embedding.runtimeType}');

      await _db.collection('students').doc(student.id).set(mapData);
    } catch (e) {
      debugPrint('Firestore Error during registration: $e');
    }
  }

  Future<void> deleteStudent(String studentId) async {
    try {
      await _db.collection('students').doc(studentId).delete();
    } catch (e) {
      debugPrint('Firestore Error: Could not delete student $studentId. $e');
    }
  }

  Future<List<Student>> getStudents() async {
    try {
      var snapshot = await _db.collection('students').get();
      return snapshot.docs.map((doc) => Student.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Firestore Error (Mock Mode): Returning empty list. $e');
      return [];
    }
  }

  // Attendance
  Future<void> markAttendance(Attendance attendance) async {
    try {
      // Check if attendance already marked for today
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      var existing = await _db.collection('attendance')
          .where('studentId', isEqualTo: attendance.studentId)
          .where('dateTime', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('dateTime', isLessThanOrEqualTo: endOfDay.toIso8601String())
          .get();

      if (existing.docs.isEmpty) {
        await _db.collection('attendance').add(attendance.toMap());
      }
    } catch (e) {
      debugPrint('Firestore Error (Mock Mode): Attendance marking skipped. $e');
    }
  }

  Future<List<Attendance>> getAttendanceLogs() async {
    try {
      var snapshot = await _db.collection('attendance').orderBy('dateTime', descending: true).get();
      return snapshot.docs.map((doc) => Attendance.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Firestore Error (Mock Mode): Returning empty logs. $e');
      return [];
    }
  }
}
