import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../services/firebase_service.dart';
import '../services/ml_service.dart';

class RecognitionController extends ChangeNotifier {
  final MLService _mlService = MLService();
  final FirebaseService _firebaseService = FirebaseService();

  List<Student> _students = [];
  List<Student> get students => _students;

  int _todayAttendanceCount = 0;
  int get todayAttendanceCount => _todayAttendanceCount;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  // Local debouncing set to prevent race conditions/multiple marks in short frames
  final Set<String> _recentlyMarkedStudents = {};

  Future<void> initialize() async {
    await _mlService.initialize();
    await fetchStudents();
    await fetchTodayCount();
  }

  Future<void> fetchStudents() async {
    _students = await _firebaseService.getStudents();
    notifyListeners();
  }

  Future<void> fetchTodayCount() async {
    _todayAttendanceCount = await _firebaseService.getTodayAttendanceCount();
    notifyListeners();
  }

  Future<void> deleteStudent(String studentId) async {
    await _firebaseService.deleteStudent(studentId);
    await fetchStudents();
  }

  Future<String?> registerStudent(String name, String rollNumber, File imageFile) async {
    _isBusy = true;
    notifyListeners();

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _mlService.detectFaces(inputImage);

      if (faces.isEmpty) return "No face detected in photo";
      if (faces.length > 1) return "Multiple faces detected";

      // getEmbedding now throws descriptive exceptions instead of returning []
      final List<double> embedding = await _mlService.getEmbedding(imageFile, faces.first);
      
      final student = Student(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        rollNumber: rollNumber,
        embedding: embedding,
        createdAt: DateTime.now(),
      );

      await _firebaseService.registerStudent(student);
      await fetchStudents();
      return null; // Success
    } catch (e) {
      debugPrint('CONTROLLER REG ERROR: $e');
      return e.toString().replaceAll('Exception: ', ''); // Clean for UI display
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<String?> markAttendance(File imageFile, String subject, String branch, String timeSlot) async {
    _isBusy = true;
    notifyListeners();

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final faces = await _mlService.detectFaces(inputImage);

      if (faces.isEmpty) return "No face detected in scan";

      final List<double> embedding = await _mlService.getEmbedding(imageFile, faces.first);
      
      Student? matchedStudent;
      double maxSimilarity = 0.0;

      for (var student in _students) {
        if (embedding.length != student.embedding.length) continue;

        double similarity = _mlService.compareEmbeddings(embedding, student.embedding);
        if (similarity > 0.60 && similarity > maxSimilarity) {
          maxSimilarity = similarity;
          matchedStudent = student;
        }
      }

      if (matchedStudent != null) {
        if (_recentlyMarkedStudents.contains(matchedStudent.id)) {
          return "Already marked in this session";
        }

        final attendance = Attendance(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          studentId: matchedStudent.id,
          studentName: matchedStudent.name,
          dateTime: DateTime.now(),
          subject: subject,
          branch: branch,
          timeSlot: timeSlot,
        );
        
        await _firebaseService.markAttendance(attendance);
        
        // Debounce: Temporarily track to prevent duplicate frames from triggering
        final studentId = matchedStudent.id;
        _recentlyMarkedStudents.add(studentId);
        Future.delayed(const Duration(seconds: 10), () {
          _recentlyMarkedStudents.remove(studentId);
        });

        await fetchTodayCount();
        return "Identity Verified: ${matchedStudent.name} (${(maxSimilarity * 100).toStringAsFixed(0)}%)";
      } else {
        return "Not Recognized (Max Score: ${maxSimilarity.toStringAsFixed(2)})";
      }
    } catch (e) {
      debugPrint('CONTROLLER ATTENDANCE ERROR: $e');
      if (e.toString().contains('already marked')) {
        return "Already marked for this time slot";
      }
      return e.toString().replaceAll('Exception: ', '');
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<List<Face>> detectFacesFromStream(CameraImage image, int sensorOrientation) async {
    final inputImage = _inputImageFromCameraImage(image, sensorOrientation);
    if (inputImage == null) return [];
    return await _mlService.detectFaces(inputImage);
  }

  InputImage? _inputImageFromCameraImage(CameraImage image, int sensorOrientation) {
    final bytes = _concatenatePlanes(image.planes);
    if (bytes == null) return null;

    final InputImageMetadata metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: _getRotation(sensorOrientation),
      format: _getFormat(image.format.group),
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Uint8List? _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  InputImageRotation _getRotation(int sensorOrientation) {
    switch (sensorOrientation) {
      case 0: return InputImageRotation.rotation0deg;
      case 90: return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default: return InputImageRotation.rotation0deg;
    }
  }

  InputImageFormat _getFormat(ImageFormatGroup format) {
    if (Platform.isAndroid) return InputImageFormat.nv21;
    if (Platform.isIOS) return InputImageFormat.bgra8888;
    return InputImageFormat.yuv420;
  }
}
