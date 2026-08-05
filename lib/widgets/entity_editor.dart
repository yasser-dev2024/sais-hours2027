import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/entity_config.dart';
import '../database/database_service.dart';
import '../services/file_service.dart';

class EntityEditorDialog extends StatefulWidget {
  const EntityEditorDialog({
    super.key,
    required this.config,
    this.record,
    this.forcedValues = const {},
  });

  final EntityConfig config;
  final Map<String, Object?>? record;
  final Map<String, Object?> forcedValues;

  static Future<bool> show(
    BuildContext context, {
    required EntityConfig config,
    Map<String, Object?>? record,
    Map<String, Object?> forcedValues = const {},
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => EntityEditorDialog(
            config: config,
            record: record,
            forcedValues: forcedValues,
          ),
        ) ??
        false;
  }

  @override
  State<EntityEditorDialog> createState() => _EntityEditorDialogState();
}

class _EntityEditorDialogState extends State<EntityEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _booleans = <String, bool>{};
  final _foreign = <String, int?>{};
  final _dynamicChoices = <String, List<String>>{};
  List<Map<String, Object?>> _horses = const [];
  List<Map<String, Object?>> _subscribers = const [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final record = widget.record ?? const <String, Object?>{};
    final today = DateTime.now().toIso8601String().substring(0, 10);
    for (final field in widget.config.fields) {
      final raw =
          record[field.key] ??
          field.defaultValue ??
          (field.required && field.kind == FieldKind.date ? today : '');
      if (field.kind == FieldKind.boolean) {
        _booleans[field.key] = raw == true || raw == 1 || raw == '1';
      } else if (field.kind == FieldKind.horse ||
          field.kind == FieldKind.subscriber) {
        _foreign[field.key] = raw is int ? raw : int.tryParse('$raw');
      } else {
        _controllers[field.key] = TextEditingController(text: raw.toString());
      }
    }
    _loadReferences();
  }

  Future<void> _loadReferences() async {
    final needsHorses = widget.config.fields.any(
      (field) => field.kind == FieldKind.horse,
    );
    final needsSubscribers = widget.config.fields.any(
      (field) => field.kind == FieldKind.subscriber,
    );
    final horses = needsHorses
        ? await DatabaseService.instance.rows('horses', orderBy: 'name')
        : const <Map<String, Object?>>[];
    final subscribers = needsSubscribers
        ? await DatabaseService.instance.rows('subscribers', orderBy: 'name')
        : const <Map<String, Object?>>[];
    if (widget.config.table == 'daily_bookings') {
      final raw = await DatabaseService.instance.getSetting('custom_services');
      if (raw?.isNotEmpty == true) {
        try {
          final decoded = jsonDecode(raw!);
          if (decoded is List) {
            _dynamicChoices['service_type'] = decoded
                .map((value) => '$value'.trim())
                .where((value) => value.isNotEmpty)
                .toSet()
                .toList();
          }
        } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      _horses = horses;
      _subscribers = subscribers;
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleFields = widget.config.fields
        .where((field) => !widget.forcedValues.containsKey(field.key))
        .toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.secondary.withValues(
                      alpha: .2,
                    ),
                    child: Icon(
                      widget.config.icon,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.record == null
                          ? 'إضافة ${widget.config.singular}'
                          : 'تعديل ${widget.config.singular}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                    tooltip: 'إغلاق',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: visibleFields.length + (_error == null ? 0 : 1),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (_error != null && index == 0) {
                      return MaterialBanner(
                        content: Text(_error!),
                        leading: const Icon(Icons.error_outline),
                        actions: [
                          TextButton(
                            onPressed: () => setState(() => _error = null),
                            child: const Text('إخفاء'),
                          ),
                        ],
                      );
                    }
                    final field =
                        visibleFields[index - (_error == null ? 0 : 1)];
                    return _buildField(field);
                  },
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: const Text('حفظ'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(EntityField field) {
    switch (field.kind) {
      case FieldKind.choice:
        final controller = _controllers[field.key]!;
        final values = <String>{
          ...field.options,
          ...?_dynamicChoices[field.key],
        }.toList();
        if (controller.text.isNotEmpty && !values.contains(controller.text)) {
          values.add(controller.text);
        }
        return DropdownButtonFormField<String>(
          value: controller.text.isEmpty ? null : controller.text,
          isExpanded: true,
          decoration: InputDecoration(labelText: field.label),
          items: values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(_choiceLabel(value)),
                ),
              )
              .toList(),
          onChanged: (value) => _onChoiceChanged(field.key, value ?? ''),
          validator: (value) =>
              field.required && (value == null || value.isEmpty)
              ? 'هذا الحقل مطلوب'
              : null,
        );
      case FieldKind.boolean:
        return SwitchListTile.adaptive(
          value: _booleans[field.key] ?? false,
          onChanged: (value) => setState(() => _booleans[field.key] = value),
          title: Text(field.label),
          tileColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: .035),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        );
      case FieldKind.horse:
      case FieldKind.subscriber:
        final rows = field.kind == FieldKind.horse ? _horses : _subscribers;
        return DropdownButtonFormField<int?>(
          value: _foreign[field.key],
          isExpanded: true,
          decoration: InputDecoration(labelText: field.label),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('بدون ربط')),
            ...rows.map(
              (row) => DropdownMenuItem<int?>(
                value: row['id'] as int,
                child: Text('${row['name']}'),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _foreign[field.key] = value),
          validator: (_) => field.required && _foreign[field.key] == null
              ? 'هذا الحقل مطلوب'
              : null,
        );
      case FieldKind.image:
        final controller = _controllers[field.key]!;
        final file = controller.text.isEmpty ? null : File(controller.text);
        final hasImage = file != null && file.existsSync();
        return InputDecorator(
          decoration: InputDecoration(labelText: field.label),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasImage) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    file,
                    height: 170,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 90,
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _pickFile(field, camera: true),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('التقاط بالكاميرا'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickFile(field),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('اختيار من المعرض'),
                  ),
                  if (controller.text.isNotEmpty)
                    IconButton.outlined(
                      tooltip: 'إزالة الصورة',
                      onPressed: () => setState(() => controller.clear()),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              if (!hasImage)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('لم تُضف صورة بعد'),
                ),
            ],
          ),
        );
      case FieldKind.document:
        final controller = _controllers[field.key]!;
        return InkWell(
          onTap: () => _pickFile(field),
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: field.label,
              suffixIcon: const Icon(Icons.attach_file),
            ),
            child: Text(
              controller.text.isEmpty
                  ? 'اضغط لاختيار ملف'
                  : controller.text.split(RegExp(r'[/\\]')).last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      default:
        final dateLike =
            field.kind == FieldKind.date || field.kind == FieldKind.time;
        return TextFormField(
          controller: _controllers[field.key],
          readOnly: dateLike,
          onTap: dateLike ? () => _pickDateTime(field) : null,
          keyboardType:
              field.kind == FieldKind.number || field.kind == FieldKind.integer
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          minLines: field.kind == FieldKind.longText ? 3 : 1,
          maxLines: field.kind == FieldKind.longText ? 6 : 1,
          decoration: InputDecoration(
            labelText: field.label,
            suffixIcon: field.kind == FieldKind.date
                ? const Icon(Icons.calendar_today)
                : field.kind == FieldKind.time
                ? const Icon(Icons.schedule)
                : null,
          ),
          onChanged:
              widget.config.table == 'daily_bookings' &&
                  field.key == 'duration_minutes'
              ? (_) => _applyBookingPrice()
              : null,
          validator: (value) {
            if (field.required && (value == null || value.trim().isEmpty))
              return 'هذا الحقل مطلوب';
            if ((field.kind == FieldKind.number ||
                    field.kind == FieldKind.integer) &&
                value?.isNotEmpty == true &&
                num.tryParse(value!) == null)
              return 'قيمة رقمية غير صحيحة';
            return null;
          },
        );
    }
  }

  void _onChoiceChanged(String key, String value) {
    _controllers[key]!.text = value;
    if (widget.config.table == 'daily_bookings' && key == 'service_type') {
      _applyBookingPrice();
    }
  }

  Future<void> _applyBookingPrice() async {
    final service = _controllers['service_type']?.text.trim() ?? '';
    final duration = int.tryParse(_controllers['duration_minutes']?.text ?? '');
    if (service.isEmpty || duration == null) return;
    final serviceKey = switch (service) {
      'تدريب' => 'training',
      'ركوب' => 'riding',
      'رماية' => 'shooting',
      _ => service,
    };
    final price = await DatabaseService.instance.getSetting(
      'price_${serviceKey}_$duration',
    );
    if (price != null && mounted) {
      setState(() => _controllers['price']?.text = price);
    }
  }

  Future<void> _pickDateTime(EntityField field) async {
    final controller = _controllers[field.key]!;
    if (field.kind == FieldKind.date) {
      final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
      final value = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (value != null)
        controller.text = value.toIso8601String().substring(0, 10);
    } else {
      final parts = controller.text.split(':');
      final initial = parts.length >= 2
          ? TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 9,
              minute: int.tryParse(parts[1]) ?? 0,
            )
          : TimeOfDay.now();
      final value = await showTimePicker(
        context: context,
        initialTime: initial,
      );
      if (value != null)
        controller.text =
            '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickFile(EntityField field, {bool camera = false}) async {
    try {
      final value = field.kind == FieldKind.image
          ? await FileService.instance.pickImage(
              camera: camera,
              folder: widget.config.table,
            )
          : await FileService.instance.pickDocument(
              folder: '${widget.config.table}_documents',
            );
      if (value != null && mounted)
        setState(() => _controllers[field.key]!.text = value);
    } catch (exception) {
      if (mounted) setState(() => _error = '$exception');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final values = <String, Object?>{...widget.forcedValues};
    for (final field in widget.config.fields) {
      if (widget.forcedValues.containsKey(field.key)) continue;
      switch (field.kind) {
        case FieldKind.boolean:
          values[field.key] = (_booleans[field.key] ?? false) ? 1 : 0;
          break;
        case FieldKind.horse:
        case FieldKind.subscriber:
          values[field.key] = _foreign[field.key];
          break;
        default:
          final text = _controllers[field.key]?.text.trim() ?? '';
          values[field.key] = text.isEmpty ? null : text;
          break;
      }
    }
    try {
      await DatabaseService.instance.saveRecord(
        widget.config.table,
        values,
        id: widget.record?['id'] as int?,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = exception.toString().replaceFirst('FormatException: ', '');
        });
    }
  }

  static String _choiceLabel(String value) => switch (value) {
    'income' => 'وارد',
    'expense' => 'مصروف',
    'owner' => 'صاحب الخيل',
    'stable' => 'الإسطبل',
    _ => value,
  };
}
