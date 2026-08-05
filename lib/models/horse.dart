class Horse {
  const Horse({
    required this.id,
    required this.name,
    this.imagePath,
    this.breed,
    this.gender,
    this.color,
    this.chipId,
    this.birthDate,
    this.ownerName,
    this.stableLocation,
    this.healthStatus = 'جيدة',
    this.notes,
    this.ownershipType = 'إيواء',
    this.subscriberId,
  });

  final int id;
  final String name;
  final String? imagePath;
  final String? breed;
  final String? gender;
  final String? color;
  final String? chipId;
  final String? birthDate;
  final String? ownerName;
  final String? stableLocation;
  final String healthStatus;
  final String? notes;
  final String ownershipType;
  final int? subscriberId;

  factory Horse.fromMap(Map<String, Object?> map) => Horse(
    id: map['id'] as int,
    name: '${map['name'] ?? ''}',
    imagePath: map['image_path'] as String?,
    breed: map['breed'] as String?,
    gender: map['gender'] as String?,
    color: map['color'] as String?,
    chipId: map['chip_id'] as String?,
    birthDate: map['birth_date'] as String?,
    ownerName: map['owner_name'] as String?,
    stableLocation: map['stable_location'] as String?,
    healthStatus: '${map['health_status'] ?? 'جيدة'}',
    notes: map['notes'] as String?,
    ownershipType: '${map['ownership_type'] ?? 'إيواء'}',
    subscriberId: map['subscriber_id'] as int?,
  );
}
