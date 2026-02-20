import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/attendance.dart';

class ExportService {
  static Future<String?> exportToCSV(List<Attendance> records) async {
    try {
      List<List<dynamic>> rows = [];
      
      // Header
      rows.add(['ID', 'Student ID', 'Student Name', 'Date & Time', 'Status']);

      // Data
      for (var record in records) {
        rows.add([
          record.id,
          record.studentId,
          record.studentName,
          record.dateTime.toIso8601String(),
          record.status,
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      
      final directory = await getExternalStorageDirectory();
      final path = "${directory!.path}/attendance_${DateTime.now().millisecondsSinceEpoch}.csv";
      final file = File(path);
      
      await file.writeAsString(csvData);
      return path;
    } catch (e) {
      print('Export error: $e');
      return null;
    }
  }
}
