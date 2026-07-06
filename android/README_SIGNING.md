# توقيع التطبيق (Signing) لنشره على Google Play

هذا المشروع مُعد حالياً بحيث يُبنى **release** باستخدام مفتاح debug
الافتراضي، لغرض واحد فقط: تجربة `flutter build apk --release` مباشرة
بدون أي إعداد إضافي.

**مفتاح debug لا يصلح إطلاقاً لنشر التطبيق على Google Play.** قبل النشر،
اتبع الخطوات التالية:

## 1. إنشاء مفتاح توقيع خاص بك

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

سيطلب منك كلمة مرور وبعض المعلومات — احتفظ بالملف الناتج وبكلمة المرور
في مكان آمن جداً؛ فقدانه يعني عدم القدرة على تحديث التطبيق مستقبلاً على
نفس الحزمة (applicationId) في Google Play.

## 2. إنشاء ملف `android/key.properties`

```properties
storePassword=<كلمة مرور الـ keystore>
keyPassword=<كلمة مرور المفتاح>
keyAlias=upload
storeFile=/المسار/الكامل/إلى/upload-keystore.jks
```

**لا تضف هذا الملف لأي نظام تحكم بالنسخ (git) أبداً.**

## 3. تعديل `android/app/build.gradle`

أضف قبل `android {`:

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

وداخل `android { ... }` أضف:

```groovy
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
```

ثم غيّر داخل `buildTypes { release { ... } }`:

```groovy
signingConfig signingConfigs.release   // بدل signingConfigs.debug
```

بعدها `flutter build apk --release` سينتج ملفاً موقّعاً بمفتاحك الخاص
وجاهزاً للرفع على Google Play.
