class Attendance {
  final String id;
  final String studentId;
  final String studentName;
  final DateTime dateTime;
  final String status;
  final String subject;
  final String branch;
  final String timeSlot; // New field

  Attendance({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.dateTime,
    this.status = 'Present',
    required this.subject,
    required this.branch,
    required this.timeSlot, // New field
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studentId': studentId,
      'studentName': studentName,
      'dateTime': dateTime.toIso8601String(),
      'status': status,
      'subject': subject,
      'branch': branch,
      'timeSlot': timeSlot, // New field
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      dateTime: DateTime.parse(map['dateTime'] ?? DateTime.now().toIso8601String()),
      status: map['status'] ?? 'Present',
      subject: map['subject'] ?? '',
      branch: map['branch'] ?? '',
      timeSlot: map['timeSlot'] ?? '', // New field
    );
  }
}
