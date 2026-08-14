# سايس الخيل — Android وصفحة التحميل

كود التطبيق الأصلي موجود في `lib` وأصوله في `assets`. أُعيد إنشاء منصة Android فقط، مع صفحة تحميل مستقلة داخل `docs`.

## إنشاء النسخة الرسمية

من جذر مشروع Flutter شغّل:

```powershell
.\build_android_and_web.ps1
```

يتوقف السكربت فورًا عند فشل التنظيف أو الحزم أو التحليل أو بناء Release أو التوقيع أو فحص APK. وعند النجاح ينتج:

- `build/app/outputs/flutter-apk/app-release.apk`
- `docs/downloads/HorseClub.apk`

النسختان متطابقتان في الحجم وSHA-256. صفحة `docs/index.html` تستخدم رابطًا نسبيًا واحدًا إلى APK، وتتحقق من استجابة الخادم قبل بدء التحميل.

تعليمات التوقيع المحلي في `SIGNING-INSTRUCTIONS.txt`، وتعليمات نشر GitHub Pages من `/docs` في `GITHUB-PAGES-SETUP.md`.

لا ترفع `android/key.properties` أو أي ملف `JKS/keystore` إلى GitHub.
