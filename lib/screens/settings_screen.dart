import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../backup/backup_service.dart';
import '../core/constants.dart';
import '../core/validators.dart';
import '../database/database_service.dart';
import '../providers/app_provider.dart';
import '../services/file_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clubName = TextEditingController();
  final _reminder = TextEditingController();
  final _subscriptionAlert = TextEditingController();
  final _contract = TextEditingController();
  final _primary = TextEditingController();
  final _accent = TextEditingController();
  final _success = TextEditingController();
  final _warning = TextEditingController();
  final _danger = TextEditingController();
  final _newService = TextEditingController();
  final _prices = <String, TextEditingController>{};
  final _customServices = <String>[];
  bool _loading = true;
  bool _saving = false;
  String _logoPath = '';
  String _signaturePath = '';
  String _sealPath = '';
  List<FileSystemEntity> _backups = const [];

  static const _durations = [5, 10, 15, 30, 60];
  static const _baseServices = <String, String>{
    'تدريب': 'training',
    'ركوب': 'riding',
    'رماية': 'shooting',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clubName.dispose();
    _reminder.dispose();
    _subscriptionAlert.dispose();
    _contract.dispose();
    _primary.dispose();
    _accent.dispose();
    _success.dispose();
    _warning.dispose();
    _danger.dispose();
    _newService.dispose();
    for (final controller in _prices.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final values = await DatabaseService.instance.settings();
    _clubName.text = values['club_name'] ?? 'نادي الخيل';
    _reminder.text = values['reminder_days'] ?? '3';
    _subscriptionAlert.text = values['subscription_alert_days'] ?? '7';
    _contract.text = values['boarding_contract_text'] ?? '';
    _primary.text = values['primary_color'] ?? '#10233F';
    _accent.text = values['accent_color'] ?? '#C9A56A';
    _success.text = values['success_color'] ?? '#21845A';
    _warning.text = values['warning_color'] ?? '#D99B2B';
    _danger.text = values['danger_color'] ?? '#C94141';
    _logoPath = values['report_logo'] ?? '';
    _signaturePath = values['club_signature'] ?? '';
    _sealPath = values['club_seal'] ?? '';
    _customServices
      ..clear()
      ..addAll(_decodeServices(values['custom_services']));
    _syncPriceControllers(values);
    _backups = await BackupService.instance.listBackups();
    if (mounted) setState(() => _loading = false);
  }

  List<String> _decodeServices(String? source) {
    if (source == null || source.isEmpty) return [];
    try {
      final decoded = jsonDecode(source);
      if (decoded is List) {
        return decoded
            .map(AppValidators.name)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Map<String, String> get _services => {
    ..._baseServices,
    for (final service in _customServices) service: service,
  };

  void _syncPriceControllers(Map<String, String> values) {
    for (final entry in _services.entries) {
      for (final duration in _durations) {
        final key = 'price_${entry.value}_$duration';
        _prices.putIfAbsent(key, TextEditingController.new).text =
            values[key] ?? '0';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          _section(
            title: 'الهوية والإعدادات العامة',
            icon: Icons.tune,
            children: [
              const TextField(
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'اسم التطبيق',
                  prefixIcon: Icon(Icons.badge),
                  hintText: AppConstants.appName,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _clubName,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'اسم النادي',
                  helperText: 'يظهر في الفواتير والإيصالات والتقارير والعقود',
                  prefixIcon: Icon(Icons.home_work_outlined),
                ),
                validator: (value) => AppValidators.name(value).isEmpty
                    ? 'أدخل اسم النادي'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _integerField(
                      _reminder,
                      'التنبيه قبل الموعد (يوم)',
                      1,
                      30,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _integerField(
                      _subscriptionAlert,
                      'تنبيه الاشتراك (يوم)',
                      1,
                      60,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _section(
            title: 'الخدمات اليومية والأسعار',
            icon: Icons.price_change,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newService,
                      decoration: const InputDecoration(
                        labelText: 'اسم خدمة مخصصة',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'إضافة الخدمة',
                    onPressed: _addService,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              if (_customServices.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    children: _customServices
                        .map(
                          (service) => InputChip(
                            label: Text(service),
                            onDeleted: () => _removeService(service),
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 8),
              ..._services.entries.map(_priceCard),
            ],
          ),
          _section(
            title: 'هوية النادي في الفواتير والتقارير',
            icon: Icons.branding_watermark,
            children: [
              _imageSetting(
                title: 'شعار التقارير والفواتير',
                path: _logoPath,
                onChoose: () => _pickSettingImage('report_logo'),
                onRemove: () => _removeSettingImage('report_logo'),
              ),
              const Divider(height: 28),
              _imageSetting(
                title: 'توقيع النادي في الفواتير والتقارير',
                path: _signaturePath,
                onChoose: () => _pickSettingImage('club_signature'),
                onRemove: () => _removeSettingImage('club_signature'),
              ),
              const Divider(height: 28),
              _imageSetting(
                title: 'ختم المنشأة في عقود الإيواء',
                path: _sealPath,
                onChoose: () => _pickSettingImage('club_seal'),
                onRemove: () => _removeSettingImage('club_seal'),
              ),
            ],
          ),
          _section(
            title: 'الألوان',
            icon: Icons.palette_outlined,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _colorField(_primary, 'الأساسي'),
                  _colorField(_accent, 'الثانوي'),
                  _colorField(_success, 'النجاح'),
                  _colorField(_warning, 'التحذير'),
                  _colorField(_danger, 'الخطر'),
                ],
              ),
            ],
          ),
          _section(
            title: 'بنود عقد الإيواء',
            icon: Icons.description_outlined,
            children: [
              TextFormField(
                controller: _contract,
                minLines: 6,
                maxLines: 12,
                maxLength: 20000,
                decoration: const InputDecoration(
                  hintText: 'اكتب البنود التي تظهر للمالك قبل التوقيع...',
                ),
              ),
            ],
          ),
          _section(
            title: 'النسخ الاحتياطي والاستعادة',
            icon: Icons.security,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _createBackup,
                    icon: const Icon(Icons.backup),
                    label: const Text('إنشاء نسخة'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _exportBackup,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('تصدير نسخة'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _restoreBackup,
                    icon: const Icon(Icons.restore),
                    label: const Text('استعادة نسخة'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _backups.isEmpty
                    ? 'لا توجد نسخ داخلية حتى الآن.'
                    : 'آخر نسخة: ${p.basename(_backups.first.path)} — ${(_backups.first.statSync().size / 1024).toStringAsFixed(1)} ك.ب',
              ),
            ],
          ),
          _section(
            title: 'التطبيق والبيانات',
            icon: Icons.phone_android,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('الإشعارات وصوت الإنذار يعملان افتراضيًا'),
                subtitle: const Text(
                  'لا يوجد مفتاح تفعيل داخل التطبيق. يُطلب إذن Android مرة واحدة فقط عند أول تشغيل.',
                ),
                trailing: TextButton(
                  onPressed: openAppSettings,
                  child: const Text('إعدادات Android'),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_open),
                title: const Text('التطبيق مفتوح حاليًا بدون مفتاح تفعيل'),
                subtitle: const Text('يمكن استخدام جميع الأقسام مباشرة.'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline),
                title: Text(
                  '${AppConstants.appName} — الإصدار ${AppConstants.version}',
                ),
                subtitle: Text(AppConstants.packageId),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: const Text('حفظ جميع الإعدادات'),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _integerField(
    TextEditingController controller,
    String label,
    int min,
    int max,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        final parsed = int.tryParse(value ?? '');
        return parsed == null || parsed < min || parsed > max
            ? 'من $min إلى $max'
            : null;
      },
    );
  }

  Widget _colorField(TextEditingController controller, String label) {
    return SizedBox(
      width: 165,
      child: TextFormField(
        controller: controller,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.circle),
        ),
        validator: (value) => RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value ?? '')
            ? null
            : 'مثال: #10233F',
      ),
    );
  }

  Widget _priceCard(MapEntry<String, String> service) {
    return Card.filled(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              service.key,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _durations.map((duration) {
                final key = 'price_${service.value}_$duration';
                return SizedBox(
                  width: 116,
                  child: TextFormField(
                    controller: _prices[key],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: duration == 60 ? 'ساعة' : '$duration دقيقة',
                      suffixText: 'ر.س',
                    ),
                    validator: (value) {
                      final amount = num.tryParse(value ?? '');
                      return amount == null || amount < 0 || amount > 99999
                          ? 'قيمة غير صحيحة'
                          : null;
                    },
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageSetting({
    required String title,
    required String path,
    required VoidCallback onChoose,
    required VoidCallback onRemove,
  }) {
    final file = path.isEmpty ? null : File(path);
    return Row(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).colorScheme.secondary),
          ),
          alignment: Alignment.center,
          child: file != null && file.existsSync()
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    file,
                    width: 92,
                    height: 92,
                    fit: BoxFit.contain,
                  ),
                )
              : const Icon(Icons.image_not_supported_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onChoose,
                    icon: const Icon(Icons.image_search),
                    label: const Text('اختيار'),
                  ),
                  TextButton.icon(
                    onPressed: path.isEmpty ? null : onRemove,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('إزالة'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addService() {
    final name = AppValidators.name(_newService.text);
    if (name.isEmpty || _services.containsKey(name)) {
      _message('أدخل اسم خدمة جديدة غير مكررة.');
      return;
    }
    setState(() {
      _customServices.add(name);
      _newService.clear();
      _syncPriceControllers(const {});
    });
  }

  void _removeService(String service) {
    setState(() => _customServices.remove(service));
  }

  Future<void> _pickSettingImage(String key) async {
    final path = await FileService.instance.pickImage(folder: 'branding');
    if (path == null) return;
    await DatabaseService.instance.setSetting(key, path);
    if (!mounted) return;
    setState(() {
      if (key == 'report_logo') _logoPath = path;
      if (key == 'club_signature') _signaturePath = path;
      if (key == 'club_seal') _sealPath = path;
    });
  }

  Future<void> _removeSettingImage(String key) async {
    await DatabaseService.instance.setSetting(key, '');
    if (!mounted) return;
    setState(() {
      if (key == 'report_logo') _logoPath = '';
      if (key == 'club_signature') _signaturePath = '';
      if (key == 'club_seal') _sealPath = '';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final database = DatabaseService.instance;
    final values = <String, String>{
      'app_name': AppConstants.appName,
      'club_name': AppValidators.name(_clubName.text),
      'reminder_days': _reminder.text,
      'subscription_alert_days': _subscriptionAlert.text,
      'boarding_contract_text': AppValidators.text(_contract.text, max: 20000),
      'primary_color': _primary.text.toUpperCase(),
      'accent_color': _accent.text.toUpperCase(),
      'success_color': _success.text.toUpperCase(),
      'warning_color': _warning.text.toUpperCase(),
      'danger_color': _danger.text.toUpperCase(),
      'custom_services': jsonEncode(_customServices),
      for (final entry in _prices.entries)
        if (_services.values.any(
          (service) => entry.key.startsWith('price_${service}_'),
        ))
          entry.key: '${num.parse(entry.value.text)}',
    };
    for (final entry in values.entries) {
      await database.setSetting(entry.key, entry.value);
    }
    if (mounted) {
      await context.read<AppProvider>().refresh();
      setState(() => _saving = false);
      _message('تم حفظ إعدادات سايس الخيل بنجاح.');
    }
  }

  Future<void> _createBackup() async {
    try {
      final info = await BackupService.instance.createBackup();
      _backups = await BackupService.instance.listBackups();
      if (mounted) setState(() {});
      _message('تم إنشاء نسخة سليمة. البصمة: ${info.sha256.substring(0, 12)}…');
    } catch (error) {
      _message('تعذر إنشاء النسخة: $error');
    }
  }

  Future<void> _exportBackup() async {
    try {
      final path = await BackupService.instance.exportBackup();
      _message(path == null ? 'أُلغي التصدير.' : 'تم تصدير النسخة بنجاح.');
    } catch (error) {
      _message('تعذر تصدير النسخة: $error');
    }
  }

  Future<void> _restoreBackup() async {
    final file = await BackupService.instance.pickBackup();
    if (file == null || !mounted) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('تأكيد استعادة البيانات'),
        content: const Text(
          'سيُفحص الملف وتُنشأ نسخة أمان من البيانات الحالية قبل الاستعادة. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await BackupService.instance.restore(file);
      if (mounted) await context.read<AppProvider>().refresh();
      await _load();
      _message('تمت الاستعادة بعد اجتياز فحص سلامة قاعدة البيانات.');
    } catch (error) {
      _message('رُفضت الاستعادة: $error');
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}
