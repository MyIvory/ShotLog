class Shot {
  final int? id;
  final int sessionId;
  final int shotNumber;
  final DateTime detectedAt;
  final String clipPath;
  final int shotOffsetMs;
  final String? thumbnailPath;

  const Shot({
    this.id,
    required this.sessionId,
    required this.shotNumber,
    required this.detectedAt,
    required this.clipPath,
    required this.shotOffsetMs,
    this.thumbnailPath,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'session_id': sessionId,
        'shot_number': shotNumber,
        'detected_at': detectedAt.toIso8601String(),
        'clip_path': clipPath,
        'shot_offset_ms': shotOffsetMs,
        'thumbnail_path': thumbnailPath,
      };

  factory Shot.fromMap(Map<String, dynamic> m) => Shot(
        id: m['id'] as int?,
        sessionId: m['session_id'] as int,
        shotNumber: m['shot_number'] as int,
        detectedAt: DateTime.parse(m['detected_at'] as String),
        clipPath: m['clip_path'] as String,
        shotOffsetMs: m['shot_offset_ms'] as int,
        thumbnailPath: m['thumbnail_path'] as String?,
      );

  Shot copyWith({
    int? id,
    String? thumbnailPath,
  }) =>
      Shot(
        id: id ?? this.id,
        sessionId: sessionId,
        shotNumber: shotNumber,
        detectedAt: detectedAt,
        clipPath: clipPath,
        shotOffsetMs: shotOffsetMs,
        thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      );
}
