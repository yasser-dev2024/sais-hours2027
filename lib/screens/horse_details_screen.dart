import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/entity_config.dart';
import '../database/database_service.dart';
import '../providers/app_provider.dart';
import '../services/file_service.dart';
import '../widgets/entity_editor.dart';
import '../widgets/entity_list.dart';

class HorseDetailsScreen extends StatefulWidget {
  const HorseDetailsScreen({
    super.key,
    required this.horse,
    this.initialTab = 0,
  });
  final Map<String, Object?> horse;
  final int initialTab;

  @override
  State<HorseDetailsScreen> createState() => _HorseDetailsScreenState();
}

class _HorseDetailsScreenState extends State<HorseDetailsScreen> {
  late Map<String, Object?> horse = widget.horse;

  @override
  Widget build(BuildContext context) {
    final id = horse['id'] as int;
    return DefaultTabController(
      length: 9,
      initialIndex: widget.initialTab.clamp(0, 8),
      child: Scaffold(
        appBar: AppBar(
          title: Text('${horse['name']}'),
          actions: [
            IconButton(
              tooltip: 'تعديل بيانات الخيل',
              onPressed: _editHorse,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'حذف الخيل',
              onPressed: _deleteHorse,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            if ('${horse['owner_name'] ?? ''}'.isNotEmpty)
              IconButton(
                tooltip: 'واتساب المالك',
                onPressed: () async {
                  final subscriber = await DatabaseService.instance.rows(
                    'subscribers',
                    where: 'horse_id=?',
                    whereArgs: [id],
                    limit: 1,
                  );
                  if (subscriber.isEmpty ||
                      '${subscriber.first['phone'] ?? ''}'.isEmpty) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لا يوجد رقم جوال مرتبط بالخيل'),
                        ),
                      );
                    return;
                  }
                  await FileService.instance.openWhatsApp(
                    '${subscriber.first['phone']}',
                  );
                },
                icon: const Icon(Icons.chat),
              ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.info_outline), text: 'المعلومات'),
              Tab(icon: Icon(Icons.health_and_safety), text: 'الصحة'),
              Tab(icon: Icon(Icons.medication), text: 'العلاج'),
              Tab(icon: Icon(Icons.home_work), text: 'الإيواء والغرفة'),
              Tab(icon: Icon(Icons.build), text: 'التحذية'),
              Tab(icon: Icon(Icons.fitness_center), text: 'اليومية والتمارين'),
              Tab(icon: Icon(Icons.timeline), text: 'الخط الزمني'),
              Tab(icon: Icon(Icons.event), text: 'المواعيد'),
              Tab(icon: Icon(Icons.receipt_long), text: 'المصروفات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _HorseInfo(horse: horse),
            EntityList(
              config: EntityConfigs.health,
              forcedValues: {'horse_id': id},
              where: 'horse_id=?',
              whereArgs: [id],
              compact: true,
            ),
            EntityList(
              config: EntityConfigs.treatment,
              forcedValues: {'horse_id': id},
              where: 'horse_id=?',
              whereArgs: [id],
              compact: true,
            ),
            EntityList(
              config: EntityConfigs.boardingPayment,
              forcedValues: {'horse_id': id},
              where: 'horse_id=?',
              whereArgs: [id],
              compact: true,
            ),
            EntityList(
              config: EntityConfigs.farrier,
              forcedValues: {'horse_id': id},
              where: 'horse_id=?',
              whereArgs: [id],
              compact: true,
            ),
            EntityList(
              config: EntityConfigs.dailyNote,
              forcedValues: {'horse_id': id},
              where: 'horse_id=?',
              whereArgs: [id],
              compact: true,
            ),
            _Timeline(horseId: id),
            EntityList(
              config: EntityConfigs.appointment,
              forcedValues: {'horse_id': id},
              where: 'horse_id=?',
              whereArgs: [id],
              compact: true,
            ),
            EntityList(
              config: EntityConfigs.expense,
              forcedValues: {'horse_id': id},
              where: 'horse_id=?',
              whereArgs: [id],
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editHorse() async {
    final changed = await EntityEditorDialog.show(
      context,
      config: EntityConfigs.horse,
      record: horse,
    );
    if (!changed || !mounted) return;
    await context.read<AppProvider>().dataChanged();
    final updated = await DatabaseService.instance.row(
      'horses',
      horse['id'] as int,
    );
    if (updated != null && mounted) setState(() => horse = updated);
  }

  Future<void> _deleteHorse() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        icon: const Icon(
          Icons.delete_forever_outlined,
          color: Colors.red,
          size: 42,
        ),
        title: const Text('حذف ملف الخيل'),
        content: Text(
          'سيتم حذف «${horse['name']}» وكل سجلاته المرتبطة. لا يمكن التراجع عن العملية.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await DatabaseService.instance.deleteRecord('horses', horse['id'] as int);
    if (!mounted) return;
    await context.read<AppProvider>().dataChanged();
    if (mounted) Navigator.pop(context, true);
  }
}

class _HorseInfo extends StatefulWidget {
  const _HorseInfo({required this.horse});
  final Map<String, Object?> horse;

  @override
  State<_HorseInfo> createState() => _HorseInfoState();
}

class _HorseInfoState extends State<_HorseInfo> {
  late String _imagePath;

  @override
  void initState() {
    super.initState();
    _imagePath = '${widget.horse['image_path'] ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final horse = widget.horse;
    final file = _imagePath.isEmpty ? null : File(_imagePath);
    final items = <String, Object?>{
      'الاسم': horse['name'],
      'السلالة': horse['breed'],
      'الجنس': horse['gender'],
      'اللون': horse['color'],
      'رقم الشريحة': horse['chip_id'],
      'تاريخ الميلاد': horse['birth_date'],
      'المالك': horse['owner_name'],
      'الإسطبل': horse['stable_location'],
      'الحالة الصحية': horse['health_status'],
      'نوع الملكية': horse['ownership_type'],
    };
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _previewImage,
                  child: Hero(
                    tag: 'horse-photo-${horse['id']}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        alignment: AlignmentDirectional.bottomEnd,
                        children: [
                          file != null && file.existsSync()
                              ? Image.file(
                                  file,
                                  height: 220,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Image.asset(
                                  'assets/images/horse_placeholder.jpg',
                                  height: 220,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                          Container(
                            margin: const EdgeInsets.all(10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: .55),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.zoom_in,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'اضغط للتكبير',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _changeImage(camera: true),
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('تصوير الخيل'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _changeImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('اختيار من المعرض'),
                    ),
                    if (_imagePath.isNotEmpty)
                      IconButton.outlined(
                        onPressed: _removeImage,
                        tooltip: 'إزالة الصورة',
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ...items.entries.map(
                  (entry) => ListTile(
                    dense: true,
                    title: Text(entry.key),
                    trailing: SizedBox(
                      width: MediaQuery.sizeOf(context).width * .48,
                      child: Text(
                        '${entry.value ?? '—'}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                if ('${horse['notes'] ?? ''}'.isNotEmpty)
                  ListTile(
                    title: const Text('ملاحظات'),
                    subtitle: Text('${horse['notes']}'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _changeImage({bool camera = false}) async {
    try {
      final path = await FileService.instance.pickImage(
        camera: camera,
        folder: 'horses',
      );
      if (path == null || !mounted) return;
      await DatabaseService.instance.saveRecord('horses', {
        'image_path': path,
      }, id: widget.horse['id'] as int);
      if (!mounted) return;
      setState(() => _imagePath = path);
      await context.read<AppProvider>().dataChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذّر إضافة الصورة: $error')));
    }
  }

  Future<void> _previewImage() => showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'إغلاق الصورة',
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (dialogContext, animation, secondaryAnimation) => SafeArea(
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: .8,
              maxScale: 5,
              child: Hero(
                tag: 'horse-photo-${widget.horse['id']}',
                child: _imagePath.isNotEmpty && File(_imagePath).existsSync()
                    ? Image.file(File(_imagePath), fit: BoxFit.contain)
                    : Image.asset(
                        'assets/images/horse_placeholder.jpg',
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 12,
            end: 12,
            child: IconButton.filled(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
              tooltip: 'إغلاق',
            ),
          ),
        ],
      ),
    ),
    transitionBuilder: (_, animation, __, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: animation, child: child),
    ),
  );

  Future<void> _removeImage() async {
    await DatabaseService.instance.saveRecord('horses', {
      'image_path': null,
    }, id: widget.horse['id'] as int);
    if (!mounted) return;
    setState(() => _imagePath = '');
    await context.read<AppProvider>().dataChanged();
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.horseId});
  final int horseId;
  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, Object?>>>(
    future: DatabaseService.instance.horseTimeline(horseId),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Center(child: CircularProgressIndicator());
      final rows = snapshot.data ?? const [];
      if (rows.isEmpty)
        return const Center(child: Text('لا توجد أحداث مسجلة بعد'));
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        itemBuilder: (_, index) {
          final row = rows[index];
          final imagePath = '${row['image_path'] ?? ''}';
          final hasImage = imagePath.isNotEmpty && File(imagePath).existsSync();
          return Card(
            child: ListTile(
              leading: hasImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(imagePath),
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                      ),
                    )
                  : CircleAvatar(child: Text('${index + 1}')),
              title: Text(
                '${row['title'] ?? row['type']}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${row['type']} • ${row['event_date'] ?? ''}\n${row['description'] ?? ''}',
              ),
              isThreeLine: true,
            ),
          );
        },
      );
    },
  );
}
