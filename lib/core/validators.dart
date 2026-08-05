import 'dart:io';

import 'package:path/path.dart' as p;

import 'constants.dart';

abstract final class AppValidators {
  static final _controlChars = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static final _phoneChars = RegExp(r'[^0-9+]');

  static String text(Object? value, {int max = 500}) {
    final clean = (value ?? '').toString().trim().replaceAll(_controlChars, '');
    return clean.length <= max ? clean : clean.substring(0, max);
  }

  static String name(Object? value) => text(value, max: 100);
  static String notes(Object? value) => text(value, max: 2000);

  static String phone(Object? value) {
    final clean = text(value, max: 30).replaceAll(_phoneChars, '');
    return clean.length <= 20 ? clean : clean.substring(0, 20);
  }

  static bool validDate(Object? value) {
    if (value == null || value.toString().isEmpty) return true;
    final parsed = DateTime.tryParse(value.toString());
    return parsed != null && parsed.year >= 1900 && parsed.year <= 2100;
  }

  static double amount(Object? value, {bool allowZero = true}) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed == null || parsed.isNaN || parsed.isInfinite) {
      throw const FormatException('يرجى إدخال مبلغ صحيح');
    }
    if (parsed < 0 || (!allowZero && parsed == 0) || parsed > 99999999) {
      throw const FormatException('المبلغ خارج النطاق المسموح');
    }
    return parsed;
  }

  static int integer(Object? value, {int min = 0, int max = 1000000}) {
    final parsed = value is int ? value : int.tryParse('$value');
    if (parsed == null || parsed < min || parsed > max) {
      throw const FormatException('القيمة الرقمية غير صحيحة');
    }
    return parsed;
  }

  static bool safePath(String value) =>
      value.isNotEmpty &&
      !value.contains('\x00') &&
      !p.split(value).contains('..');

  static Future<void> validateFile(
    File file, {
    Set<String> allowed = AppConstants.allowedDocuments,
  }) async {
    final path = file.path;
    if (!safePath(path) || !allowed.contains(p.extension(path).toLowerCase())) {
      throw const FormatException('نوع الملف غير مدعوم');
    }
    final length = await file.length();
    if (length <= 0 || length > AppConstants.maxFileBytes) {
      throw const FormatException(
        'حجم الملف غير مسموح (الحد الأقصى 10 ميجابايت)',
      );
    }
    final bytes = await file
        .openRead(0, length < 16 ? length : 16)
        .fold<List<int>>(<int>[], (all, part) => all..addAll(part));
    final ext = p.extension(path).toLowerCase();
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    final isPdf =
        bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
    if ((ext == '.png' && !isPng) ||
        ((ext == '.jpg' || ext == '.jpeg') && !isJpeg) ||
        (ext == '.pdf' && !isPdf)) {
      throw const FormatException('محتوى الملف لا يطابق امتداده');
    }
  }
}
