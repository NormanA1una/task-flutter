class Task {
  final String id;
  final String description;
  bool isCompleted;

  Task({
    required this.id,
    required this.description,
    this.isCompleted = false,
  });

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      description: map['description'] as String,
      isCompleted: map['isCompleted'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'isCompleted': isCompleted,
    };
  }
}
