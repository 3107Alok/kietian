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
      debugPrint('FIREBASE: Fetching all students...');
      var snapshot = await _db.collection('students').get();
      debugPrint('FIREBASE: Found ${snapshot.docs.length} enrolled students');
      return snapshot.docs.map((doc) => Student.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('FIREBASE ERROR (getStudents): $e');
      return [];
    }
  }

  // Attendance
  Future<void> markAttendance(Attendance attendance) async {
    try {
      debugPrint('FIREBASE: Marking attendance for ${attendance.studentName} in ${attendance.subject}');
      
      // Deterministic ID: attendance_studentId_yyyyMMdd_timeSlot
      final dateStr = attendance.dateTime.toIso8601String().split('T')[0].replaceAll('-', '');
      final slotStr = attendance.timeSlot.replaceAll(' ', '').replaceAll(':', '').replaceAll('-', '_');
      final docId = 'att_${attendance.studentId}_${dateStr}_$slotStr';

      final docRef = _db.collection('attendance').doc(docId);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        await docRef.set(attendance.toMap());
        debugPrint('FIREBASE: Attendance SAVED successfully with ID: $docId');
      } else {
        debugPrint('FIREBASE: Attendance ALREADY EXISTS for this slot: $docId');
        throw Exception('Attendance already marked for this time slot');
      }
    } catch (e) {
      debugPrint('FIREBASE ERROR (markAttendance): $e');
      rethrow; // Ensure the controller knows it failed/was duplicate
    }
  }

  Future<List<Attendance>> getAttendanceLogs() async {
    try {
      debugPrint('FIREBASE: Fetching attendance logs...');
      // Removing .orderBy to bypass potential missing index issues during debugging
      var snapshot = await _db.collection('attendance').get();
      debugPrint('FIREBASE: Found ${snapshot.docs.length} raw records');
      
      List<Attendance> logs = snapshot.docs.map((doc) {
        try {
          final data = doc.data();
          debugPrint('FIREBASE: Parsing Record IDs: ${doc.id} - data: $data');
          return Attendance.fromMap(data);
        } catch (e) {
          debugPrint('FIREBASE ERROR: Parsing record ${doc.id} failed: $e');
          return null;
        }
      }).whereType<Attendance>().toList();

      // Sort in-memory instead
      logs.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      
      debugPrint('FIREBASE: Successfully parsed ${logs.length} logs');
      return logs;
    } catch (e) {
      debugPrint('FIREBASE ERROR (getAttendanceLogs): $e');
      return [];
    }
  }

  Future<int> getTodayAttendanceCount() async {
    try {
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      var snapshot = await _db.collection('attendance')
          .where('dateTime', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('dateTime', isLessThanOrEqualTo: endOfDay.toIso8601String())
          .get();
      
      // Get unique student IDs present today
      final uniqueStudents = snapshot.docs.map((doc) => doc.data()['studentId'] as String).toSet();
      debugPrint('FIREBASE: Today unique students count: ${uniqueStudents.length}');
      return uniqueStudents.length;
    } catch (e) {
      debugPrint('FIREBASE ERROR (getTodayAttendanceCount): $e');
      return 0;
    }
  }
}
