class Friend {
  final String id;
  final String name;

  Friend({
    required this.id,
    required this.name,
  });

  Friend copyWith({
    String? id,
    String? name,
  }) {
    return Friend(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Friend.fromMap(Map<String, dynamic> map) {
    return Friend(
      id: map['id'] as String,
      name: map['name'] as String,
    );
  }
}
