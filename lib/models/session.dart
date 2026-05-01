class Session {
  final int? id;
  final DateTime createdAt;
  final DateTime? endedAt;
  final int shotCount;
  final int? rifleId;
  final int? bulletId;
  final double? distanceM;
  final String? weather;
  final String? notes;

  const Session({
    this.id,
    required this.createdAt,
    this.endedAt,
    this.shotCount = 0,
    this.rifleId,
    this.bulletId,
    this.distanceM,
    this.weather,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'created_at': createdAt.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'shot_count': shotCount,
        'rifle_id': rifleId,
        'bullet_id': bulletId,
        'distance_m': distanceM,
        'weather': weather,
        'notes': notes,
      };

  factory Session.fromMap(Map<String, dynamic> m) => Session(
        id: m['id'] as int?,
        createdAt: DateTime.parse(m['created_at'] as String),
        endedAt: m['ended_at'] != null ? DateTime.parse(m['ended_at'] as String) : null,
        shotCount: m['shot_count'] as int? ?? 0,
        rifleId: m['rifle_id'] as int?,
        bulletId: m['bullet_id'] as int?,
        distanceM: m['distance_m'] as double?,
        weather: m['weather'] as String?,
        notes: m['notes'] as String?,
      );

  Session copyWith({
    int? id,
    DateTime? createdAt,
    DateTime? endedAt,
    bool clearEndedAt = false,
    int? shotCount,
    int? rifleId,
    int? bulletId,
    double? distanceM,
    String? weather,
    String? notes,
  }) =>
      Session(
        id: id ?? this.id,
        createdAt: createdAt ?? this.createdAt,
        endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
        shotCount: shotCount ?? this.shotCount,
        rifleId: rifleId ?? this.rifleId,
        bulletId: bulletId ?? this.bulletId,
        distanceM: distanceM ?? this.distanceM,
        weather: weather ?? this.weather,
        notes: notes ?? this.notes,
      );
}
