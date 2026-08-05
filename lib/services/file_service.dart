import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/validators.dart';
import '../database/database_service.dart';

class FileService {
  FileService._();
  static final instance = FileService._();

  final _picker = ImagePicker();
  final _uuid = const Uuid();

  Future<String?> pickImage({
    bool camera = false,
    String folder = 'images',
  }) async {
    final picked = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 90,
    );
    if (picked == null) return null;
    return importFile(
      File(picked.path),
      folder: folder,
      allowed: AppConstants.allowedImages,
    );
  }

  Future<String?> pickDocument({String folder = 'documents'}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    return importFile(
      File(path),
      folder: folder,
      allowed: AppConstants.allowedDocuments,
    );
  }

  Future<String> importFile(
    File source, {
    required String folder,
    required Set<String> allowed,
  }) async {
    await AppValidators.validateFile(source, allowed: allowed);
    final safeFolder = AppValidators.text(
      folder,
      max: 40,
    ).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    if (safeFolder.isEmpty) throw const FormatException('مجلد الحفظ غير صحيح');
    final directory = Directory(
      p.join(DatabaseService.instance.appDirectory.path, safeFolder),
    );
    await directory.create(recursive: true);
    final extension = p.extension(source.path).toLowerCase();
    final target = File(p.join(directory.path, '${_uuid.v4()}$extension'));
    await source.copy(target.path);
    return target.path;
  }

  Future<void> shareFile(String path, {String? text}) async {
    final file = File(path);
    if (!await file.exists() || !AppValidators.safePath(path)) {
      throw const FileSystemException('الملف غير موجود');
    }
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: text),
    );
  }

  Future<void> shareText(String text) => SharePlus.instance
      .share(ShareParams(text: AppValidators.notes(text)))
      .then((_) {});

  Future<void> openWhatsApp(String phone, {String? message}) async {
    final clean = AppValidators.phone(phone).replaceFirst('+', '');
    if (clean.isEmpty) throw const FormatException('رقم الجوال غير صحيح');
    final uri = Uri.https(
      'wa.me',
      '/$clean',
      message?.isNotEmpty == true ? {'text': message} : null,
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw const FormatException('تعذر فتح واتساب');
    }
  }
}
