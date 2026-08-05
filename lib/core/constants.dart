import 'package:flutter/material.dart';

abstract final class AppConstants {
  static const appName = 'سايس الخيل';
  static const packageId = 'com.abuammar.horseclub.mobile2026';
  static const version = '2.1.1';
  static const databaseName = 'horses.db';
  static const databaseVersion = 5;

  static const navy = Color(0xFF10233F);
  static const navyLight = Color(0xFF1C3C64);
  static const gold = Color(0xFFC9A56A);
  static const ivory = Color(0xFFF8F5EE);
  static const danger = Color(0xFFC94141);
  static const success = Color(0xFF21845A);

  static const allowedImages = {'.png', '.jpg', '.jpeg', '.webp'};
  static const allowedDocuments = {'.pdf', '.png', '.jpg', '.jpeg'};
  static const maxFileBytes = 10 * 1024 * 1024;

  static const appointmentTypes = [
    'تطعيم',
    'فحص',
    'علاج',
    'تحذية',
    'دواء',
    'متابعة',
    'أخرى',
  ];
  static const healthTypes = [
    'تطعيم',
    'علاج',
    'إصابة',
    'عملية',
    'فحص',
    'حساسية',
    'دواء',
  ];
  static const expenseCategories = [
    'علف',
    'تبن وعلف خشن',
    'أدوية وعلاج',
    'بيطري',
    'تحذية',
    'تطعيم',
    'علاج',
    'إصابة',
    'عملية',
    'فحص',
    'حساسية',
    'دواء',
    'صيانة',
    'إصلاحات',
    'رواتب',
    'كهرباء ومياه',
    'إيجار',
    'تأمين',
    'فواتير',
    'نقل',
    'تدريب',
    'معدات وأدوات',
    'نثريات',
    'رسوم تدريب',
    'رسوم سباق',
    'رسوم تسجيل',
    'تصوير وتوثيق',
    'خدمات متنوعة',
    'غرامات',
    'أخرى',
  ];
  static const transactionCategories = [
    'اشتراك',
    'تغذية',
    'علاج',
    'إيواء',
    'تدريب',
    'نقل',
    'أدوات',
    'إيجار/حجز',
    'تحذية',
    'تطعيم',
    'أعلاف',
    'بيطري',
    'مستلزمات',
    'إصابة',
    'عملية',
    'فحص',
    'حساسية',
    'دواء',
    'علف',
    'صيانة',
    'رواتب',
    'كهرباء ومياه',
    'إيجار',
    'تأمين',
    'فواتير',
    'نثريات',
    'اشتراك شهري',
    'دفعة إيواء',
    'دفعة تدريب',
    'بيع خيل',
    'إيجار مرافق',
    'خدمات',
    'مدفوعات أخرى',
    'أخرى',
  ];
}
