class Rifle {
  final int? id;
  final String name;
  final String? caliber;
  final String? notes;

  const Rifle({this.id, required this.name, this.caliber, this.notes});

  String get displayName => caliber != null ? '$name ($caliber)' : name;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'caliber': caliber,
        'notes': notes,
      };

  factory Rifle.fromMap(Map<String, dynamic> m) => Rifle(
        id: m['id'] as int?,
        name: m['name'] as String,
        caliber: m['caliber'] as String?,
        notes: m['notes'] as String?,
      );

  Rifle copyWith({int? id, String? name, String? caliber, String? notes}) => Rifle(
        id: id ?? this.id,
        name: name ?? this.name,
        caliber: caliber ?? this.caliber,
        notes: notes ?? this.notes,
      );
}
