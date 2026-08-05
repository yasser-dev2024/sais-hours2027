import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:horse_club_mobile/core/validators.dart';

void main() {
  group('التحقق من المدخلات', () {
    test('ينظف النص وأرقام الجوال', () {
      expect(AppValidators.text('  خيل\u0000 أصيل  '), 'خيل أصيل');
      expect(AppValidators.phone(' +966 50-123-4567 '), '+966501234567');
    });

    test('يرفض المبالغ غير الصالحة', () {
      expect(() => AppValidators.amount('-1'), throwsFormatException);
      expect(() => AppValidators.amount('abc'), throwsFormatException);
      expect(AppValidators.amount('125.5'), 125.5);
    });

    test('يتحقق من تاريخ ISO', () {
      expect(AppValidators.validDate('2026-08-03'), isTrue);
      expect(AppValidators.validDate('03/08/2026'), isFalse);
    });

    test('يرفض ملفًا لا يطابق امتداده', () async {
      final directory = await Directory.systemTemp.createTemp(
        'horseclub_test_',
      );
      final file = File('${directory.path}${Platform.pathSeparator}fake.png');
      await file.writeAsString('not an image');
      await expectLater(
        AppValidators.validateFile(file),
        throwsFormatException,
      );
      await directory.delete(recursive: true);
    });
  });
}
