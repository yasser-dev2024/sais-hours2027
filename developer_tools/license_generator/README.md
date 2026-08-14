# License Generator

أداة مطوّر منفصلة لإنشاء تراخيص دائمة موقعة بـ Ed25519. لا تدخل الأداة أو
مفتاحها الخاص ضمن مشروع Flutter أو ملف APK.

## الإعداد مرة واحدة

```powershell
python -m pip install -r requirements.txt
python license_generator.py init-key
```

في Windows يُحمى المفتاح الخاص محليًا بواسطة DPAPI لحساب Windows الحالي،
ويُخزن خارج المشروع تحت `%LOCALAPPDATA%\HorseManagerLicenseGenerator`.
انسخ المفتاح العام الناتج فقط إلى `lib/license/license_config.dart` قبل بناء
نسخة العميل. احتفظ بنسخة احتياطية آمنة من المفتاح الخاص؛ فقدانه يعني عدم
إمكانية إنشاء مفاتيح متوافقة جديدة.

## إنشاء تفعيل دائم

انسخ Installation ID الظاهر في شاشة التفعيل ثم نفّذ:

```powershell
python license_generator.py generate --device-id "INSTALLATION-ID"
```

يمكن تحديد App ID صراحةً عند إدارة أكثر من تطبيق:

```powershell
python license_generator.py generate `
  --app-id "com.abuammar.horseclub.mobile2026" `
  --device-id "INSTALLATION-ID"
```

لا ترسل المفتاح الخاص للعميل؛ أرسل له النص الناتج فقط.
