class Attendance {
  final String id;
  final String studentId;
  final String studentName;
  final DateTime dateTime;
  final String status;

  Attendance({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.dateTime,
    this.status = 'Present',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'dateTime': dateTime.toIso8601String(),
      'status': status,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      dateTime: DateTime.parse(map['dateTime'] ?? DateTime.now().toIso8601String()),
      status: map['status'] ?? 'Present',
    );
  }
}
