class Subscriber {
  const Subscriber({
    required this.id,
    required this.name,
    this.phone,
    this.subscriptionType,
    this.duration,
    this.amount = 0,
    this.startDate,
    this.endDate,
    this.status = 'نشط',
    this.paymentMethod,
    this.linkedOwner,
    this.notes,
    this.imagePath,
    this.horseId,
  });

  final int id;
  final String name;
  final String? phone;
  final String? subscriptionType;
  final String? duration;
  final double amount;
  final String? startDate;
  final String? endDate;
  final String status;
  final String? paymentMethod;
  final String? linkedOwner;
  final String? notes;
  final String? imagePath;
  final int? horseId;

  factory Subscriber.fromMap(Map<String, Object?> map) => Subscriber(
    id: map['id'] as int,
    name: '${map['name'] ?? ''}',
    phone: map['phone'] as String?,
    subscriptionType: map['subscription_type'] as String?,
    duration: map['duration'] as String?,
    amount: (map['amount'] as num?)?.toDouble() ?? 0,
    startDate: map['start_date'] as String?,
    endDate: map['end_date'] as String?,
    status: '${map['status'] ?? 'نشط'}',
    paymentMethod: map['payment_method'] as String?,
    linkedOwner: map['linked_owner'] as String?,
    notes: map['notes'] as String?,
    imagePath: map['image_path'] as String?,
    horseId: map['horse_id'] as int?,
  );
}
