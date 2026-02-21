import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/attendance.dart';

class ExportService {
  static Future<String?> exportToCSV(List<Attendance> records) async {
    try {
      // 1. Permission Handling
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt <= 28) {
          // Android 9 and below
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
            if (!status.isGranted) return "PERMISSION_DENIED";
          }
        } else if (androidInfo.version.sdkInt <= 32) {
          // Android 10, 11, 12
          var status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
            // Android 10+ might still work without "granted" if using scoped storage but user requested public folder
          }
        }
        // Note: Android 13+ uses Photos/Video/Audio permissions, 
        // but for writing to Downloads, we often don't need broad storage permission 
        // if using MediaStore, but user specifically asked for File class and /storage/emulated/0/Download.
      }

      // 2. Prepare Data
      List<List<dynamic>> rows = [];
      rows.add(['ID', 'Student ID', 'Student Name', 'Date & Time', 'Subject', 'Branch', 'Time Slot', 'Status']);

      for (var record in records) {
        rows.add([
          record.id,
          record.studentId,
          record.studentName,
          record.dateTime.toIso8601String(),
          record.subject,
          record.branch,
          record.timeSlot,
          record.status,
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      
      // 3. Define Public Download Path
      String path = "";
      if (Platform.isAndroid) {
        final Directory downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        path = "${downloadDir.path}/attendance_${DateTime.now().millisecondsSinceEpoch}.csv";
      } else {
        // Fallback for non-android/testing
        path = "attendance_${DateTime.now().millisecondsSinceEpoch}.csv";
      }

      final file = File(path);
      await file.writeAsString(csvData);
      debugPrint('CSV Exported to: $path');
      return path;
    } catch (e) {
      debugPrint('Export error: $e');
      return null;
    }
  }
}
