import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/validators.dart';
import '../database/database_service.dart';

class BackupInfo {
  const BackupInfo(this.file, this.sha256);
  final File file;
  final String sha256;
}

class BackupService {
  BackupService._();
  static final instance = BackupService._();

  Future<Directory> get _backupDirectory async {
    final dir = Directory(
      p.join(DatabaseService.instance.appDirectory.path, 'backups'),
    );
    await dir.create(recursive: true);
    return dir;
  }

  Future<BackupInfo> createBackup() async {
    await DatabaseService.instance.checkpoint();
    final directory = await _backupDirectory;
    final now = DateTime.now();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}_${_three(now.millisecond)}';
    final target = File(p.join(directory.path, 'horses_backup_$stamp.db'));
    await File(DatabaseService.instance.databasePath).copy(target.path);
    final integrity = await DatabaseService.instance.integrityCheck(
      target.path,
    );
    if (integrity.toLowerCase() != 'ok') {
      await target.delete();
      throw const FormatException('فشل فحص سلامة النسخة الاحتياطية');
    }
    return BackupInfo(target, await fingerprint(target));
  }

  Future<List<FileSystemEntity>> listBackups() async {
    final dir = await _backupDirectory;
    final files = await dir
        .list()
        .where((item) => item is File && item.path.endsWith('.db'))
        .toList();
    files.sort(
      (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
    );
    return files;
  }

  Future<String?> exportBackup() async {
    final backup = await createBackup();
    return FilePicker.saveFile(
      dialogTitle: 'حفظ نسخة سايس الخيل الاحتياطية',
      fileName: p.basename(backup.file.path),
      type: FileType.custom,
      allowedExtensions: const ['db'],
      bytes: await backup.file.readAsBytes(),
    );
  }

  Future<File?> pickBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['db'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    return path == null ? null : File(path);
  }

  Future<BackupInfo> restore(File candidate) async {
    if (!AppValidators.safePath(candidate.path) ||
        p.extension(candidate.path).toLowerCase() != '.db') {
      throw const FormatException('ملف النسخة الاحتياطية غير صحيح');
    }
    if (!await candidate.exists() || await candidate.length() < 1024) {
      throw const FormatException('ملف النسخة الاحتياطية فارغ أو تالف');
    }
    late final String integrity;
    try {
      integrity = await DatabaseService.instance.integrityCheck(candidate.path);
    } catch (_) {
      throw const FormatException(
        'تم رفض النسخة: الملف ليس قاعدة SQLite سليمة',
      );
    }
    if (integrity.toLowerCase() != 'ok') {
      throw const FormatException('تم رفض النسخة: فحص سلامة SQLite فشل');
    }
    final required = {'horses', 'subscribers', 'expenses', 'settings'};
    final checkDb = await _openReadOnly(candidate.path);
    try {
      final rows = await checkDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final names = rows.map((row) => '${row['name']}').toSet();
      if (!names.containsAll(required)) {
        throw const FormatException('تم رفض النسخة: جداول أساسية مفقودة');
      }
    } finally {
      await checkDb.close();
    }

    final safety = await createBackup();
    final databasePath = DatabaseService.instance.databasePath;
    await DatabaseService.instance.close();
    try {
      await candidate.copy(databasePath);
      await DatabaseService.instance.initialize();
      if ((await DatabaseService.instance.integrityCheck()).toLowerCase() !=
          'ok') {
        throw const FormatException('فشل فحص القاعدة بعد الاستعادة');
      }
    } catch (_) {
      await DatabaseService.instance.close();
      await safety.file.copy(databasePath);
      await DatabaseService.instance.initialize();
      rethrow;
    }
    return safety;
  }

  Future<Database> _openReadOnly(String path) async {
    return openDatabase(path, readOnly: true, singleInstance: false);
  }

  Future<String> fingerprint(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
  static String _three(int value) => value.toString().padLeft(3, '0');
}
