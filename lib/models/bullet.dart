class Bullet {
  final int? id;
  final String name;
  final double? weightGr;
  final String? caliber;
  final double? velocityMs;
  final String? notes;

  const Bullet({
    this.id,
    required this.name,
    this.weightGr,
    this.caliber,
    this.velocityMs,
    this.notes,
  });

  String get displayName {
    final parts = <String>[name];
    if (caliber != null) parts.add(caliber!);
    if (weightGr != null) parts.add('${weightGr!.toStringAsFixed(0)}gr');
    if (velocityMs != null) parts.add('${velocityMs!.toStringAsFixed(0)}м/с');
    return parts.join(' · ');
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'weight_gr': weightGr,
        'caliber': caliber,
        'velocity_ms': velocityMs,
        'notes': notes,
      };

  factory Bullet.fromMap(Map<String, dynamic> m) => Bullet(
        id: m['id'] as int?,
        name: m['name'] as String,
        weightGr: m['weight_gr'] as double?,
        caliber: m['caliber'] as String?,
        velocityMs: m['velocity_ms'] as double?,
        notes: m['notes'] as String?,
      );

  Bullet copyWith({
    int? id,
    String? name,
    double? weightGr,
    String? caliber,
    double? velocityMs,
    String? notes,
  }) =>
      Bullet(
        id: id ?? this.id,
        name: name ?? this.name,
        weightGr: weightGr ?? this.weightGr,
        caliber: caliber ?? this.caliber,
        velocityMs: velocityMs ?? this.velocityMs,
        notes: notes ?? this.notes,
      );
}
