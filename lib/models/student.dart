class Student {
  final String id;
  final String name;
  final String rollNumber;
  final List<double> embedding;
  final DateTime createdAt;

  Student({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.embedding,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rollNumber': rollNumber,
      'embedding': embedding,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      rollNumber: map['rollNumber'] ?? '',
      embedding: (map['embedding'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
