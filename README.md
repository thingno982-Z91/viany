# تطبيق البيان المالي (Flutter) — أندرويد فقط

تطبيق لإدارة البيانات المالية (بيان / مصروف)، بالألوان الأزرق/الأبيض
المائل للأزرق، مع دعم الوضع الداكن، وتوليد PDF حقيقي.

**هذا المشروع مخصص لمنصة أندرويد فقط.** لا توجد فيه أي ملفات أو إعدادات
لـ iOS أو Web أو Windows أو Linux أو macOS، وهذا مقصود.

## ⚠️ إخلاء مسؤولية صادق

هذا المشروع **لم يُبنَ فعلياً بأمر `flutter build apk`** لأن بيئة إعداده
لا تملك Flutter SDK ولا اتصال إنترنت. كل ملف Dart وكل ملف Android روجع
يدوياً وبعناية (تحقق من الاستيرادات، تطابق أسماء الحزم، تطابق المسارات
والمراجع)، لكن هذا لا يغني عن تشغيل compiler حقيقي. توقّع احتمال ظهور
مشاكل صغيرة عند أول تشغيل فعلي — هذا طبيعي في أي مشروع Flutter، والقسم
التالي يوضح بالضبط ما هو مؤكد وما هو غير مؤكد.

## ما هو مفقود فعلياً ولماذا (ولا يمكن إنشاؤه هنا)

1. **`android/gradle/wrapper/gradle-wrapper.jar`** — ملف ثنائي، لا يمكن
   كتابته كنص. عند تشغيل `flutter build apk` أو `flutter run` لأول مرة،
   Flutter tooling يتولى توليده تلقائياً إذا كان مفقوداً.
2. **`android/local.properties`** — الملف الموجود حالياً قالب فيه مسارات
   وهمية. **يجب** تعديله ليشير لمسار Flutter SDK وAndroid SDK الفعلي
   عندك. Android Studio يعدله تلقائياً عند فتح المشروع أول مرة عادة.

## خطوات التشغيل

```bash
cd finance_flutter

# يجلب كل الحزم المذكورة في pubspec.yaml
flutter pub get

# يفحص الكود بالكامل عن أخطاء/تحذيرات
flutter analyze

# البناء الفعلي
flutter build apk --release
```

ملف الـ APK الناتج سيكون في:
`build/app/outputs/flutter-apk/app-release.apk`

**مهم:** أول عملية تصدير PDF على أي جهاز تحتاج اتصال إنترنت لمرة واحدة
(لتحميل الخط العربي تلقائياً)؛ بعدها يعمل التصدير بدون إنترنت.

**إذا ظهرت أي أخطاء** عند `flutter analyze` أو `flutter build`، أرسل لي
نص الخطأ كاملاً وسأصلحه فوراً.

## للنشر على Google Play

راجع `android/README_SIGNING.md` لخطوات توقيع التطبيق بمفتاحك الخاص —
حالياً build الـ release يستخدم مفتاح debug الافتراضي، وهذا يصلح للتجربة
فقط وليس للنشر.

---

## آخر مراجعة: ما تم فحصه والتحقق منه يدوياً

### ملفات Android
- ✅ `AndroidManifest.xml`: راجعته وأزلت `<provider>` كان يتعارض مع
  الـ FileProvider الذي تُسجّله حزمة `printing` تلقائياً بنفسها (وجود
  الاثنين معاً يسبب خطأ دمج AndroidManifest عند البناء)
- ✅ `build.gradle` (جذر ومستوى التطبيق): AGP 8.1.1 + Kotlin 1.9.22 +
  Gradle 8.4 — مجموعة إصدارات متوافقة مع بعضها ومع Flutter الحديث
- ✅ `namespace` و`applicationId` و`package` في `MainActivity.kt`
  ومسار المجلدات — كلها متطابقة (`com.kushymh.finance_statement_app`)
- ✅ أيقونات التطبيق مولّدة من الشعار الفعلي بكل الكثافات المطلوبة
- ✅ ملف `README_SIGNING.md` مُنشأ (كان مُشاراً إليه من تعليق في
  `build.gradle` لكنه لم يكن موجوداً — تم إصلاحه)

### ملفات Dart
- ✅ كل الاستيرادات (imports) في كل ملف — تحققت يدوياً أن كل حزمة/ملف
  مستورد يُستخدم فعلياً في نفس الملف، ولا يوجد استيراد ميت
  (مثال: تحققت أن `flutter/services.dart` في `entry_form_sheet.dart`
  مستخدم فعلاً بسبب `FilteringTextInputFormatter`)
- ✅ إصلاح استخدام `dynamic` غير الآمن: كانت بعض الودجت تستقبل الألوان
  كـ `dynamic colors` (حل مؤقت للتحايل على أن `_Palette` كانت خاصة
  بملف واحد) — حوّلت `_Palette` إلى صنف عام باسم `AppPalette` وصححت كل
  الاستخدامات لتكون مكتوبة بنوع صريح (type-safe) بدل `dynamic`
- ✅ تسمية مضللة في `main.dart`: كانت هناك دالة باسم
  `runZonedGuardedApp` لا تستخدم فعلياً `runZonedGuarded` رغم أن التعليق
  يوحي بذلك — صححتها لتستخدم `runZonedGuarded` فعلياً لحماية حقيقية من
  استثناءات غير متزامنة
- ✅ جميع النماذج (`models.dart`) والخدمات والشاشات المُشار إليها من كل
  ملف موجودة فعلياً في المسارات الصحيحة (لا مراجع لملفات غير موجودة)
- ✅ منطق PDF: خط عربي حقيقي متصل الحروف عبر `PdfGoogleFonts` (من حزمة
  `printing`، وليس `google_fonts` كما كان بالخطأ في نسخة سابقة)، اتجاه
  RTL صحيح، التفاف النصوص الطويلة، صفحات متعددة تلقائياً، أعمدة بنسب
  ثابتة تمنع الخروج عن حدود الصفحة
- ✅ معالجة الأخطاء: تحليل JSON دفاعي (بيانات تالفة لا تُسقط كامل
  البيانات، فقط العنصر الفاسد يُتجاهل)، استثناءات مخصصة برسائل عربية
  واضحة لفشل الحفظ/التحميل/تصدير PDF، حماية من قيم `NaN`/`Infinity` في
  كل مكان تُعرض فيه الأرقام

## هيكل المشروع

```
lib/
  main.dart                     # نقطة البداية + runZonedGuarded لحماية حقيقية
  theme/app_theme.dart          # الألوان (فاتح/داكن) + AppPalette العام
  models/models.dart            # نماذج البيانات مع تحليل JSON دفاعي
  services/
    app_controller.dart         # إدارة الحالة لكامل التطبيق
    storage_service.dart        # التخزين المحلي عبر Hive
    format_service.dart         # تنسيق الأرقام (عربي/هندي) والتواريخ
    pdf_service.dart            # توليد PDF حقيقي (خط عربي + شعار)
  screens/
    onboarding_screen.dart      # شاشة تسمية البيان الأولى + الشعار
    home_screen.dart            # الشاشة الرئيسية
    settings_sheet.dart         # الإعدادات
  widgets/
    entry_form_sheet.dart       # نافذة إضافة/تعديل مدخل
    calendar_picker.dart        # التقويم الشهري

assets/images/logo.png          # شعار AHMED KUSHYMH

android/                        # مشروع Android كامل (أندرويد فقط)
  app/build.gradle
  app/src/main/AndroidManifest.xml
  app/src/main/kotlin/.../MainActivity.kt
  app/src/main/res/             # أيقونات + splash + themes (فاتح وداكن)
  README_SIGNING.md             # خطوات التوقيع للنشر على Google Play
```

## ملاحظات تقنية

- **الخط العربي في PDF**: `PdfGoogleFonts.notoNaskhArabicRegular/Bold`
  من حزمة `printing` — يُحمَّل وقت التشغيل ويُخزَّن محلياً بعد أول
  استخدام. يتطلب إنترنت مرة واحدة فقط لكل جهاز.
- **الحفظ المحلي**: Hive — ملفات محلية على الجهاز، تبقى بين مرات الفتح.
- **الحد الأدنى لإصدار أندرويد**: `minSdkVersion 21` (Android 5.0+).
- **معرّف التطبيق**: `com.kushymh.finance_statement_app` — غيّره في
  `android/app/build.gradle` (الموضعين: `namespace` و`applicationId`)
  إذا أردت نطاقاً مختلفاً قبل النشر.
