# Complete Flutter multi-platform release workflow for 2024-2025

A simultaneous Flutter app release across Android, iOS, Windows, and Web requires **8-12 weeks** of preparation, with subscription monetization adding complexity due to platform-specific billing systems. RevenueCat provides the most unified cross-platform solution, though Windows Microsoft Store requires a workaround since Flutter's in_app_purchase plugin doesn't support it. The critical path involves completing Google Play's **14-day mandatory testing** for new accounts, Apple's **$99/year program enrollment** (1-4 weeks for organizations), and building separate CI/CD pipelines for each platform.

## CI/CD pipeline architecture for simultaneous builds

**Codemagic is the recommended CI/CD platform** for Flutter multi-platform deployment in 2024-2025, offering native Flutter support, automatic iOS code signing, and dedicated Windows build machines. GitHub Actions provides a cost-effective alternative with 2,000 free minutes/month for public repositories.

The ideal pipeline runs platform builds in parallel after shared test/analyze steps:

```yaml
# codemagic.yaml - Multi-Platform Release
workflows:
  multi-platform-release:
    name: Multi-Platform Release
    max_build_duration: 120
    instance_type: mac_mini_m2
    environment:
      groups: [app_store_credentials, google_play_credentials]
      flutter: stable
    triggering:
      events: [tag]
      tag_patterns:
        - pattern: 'v*'
    scripts:
      - name: Get dependencies and test
        script: |
          flutter pub get
          flutter analyze
          flutter test --coverage
      - name: Build Android AAB
        script: flutter build appbundle --release --obfuscate --split-debug-info=./symbols
      - name: Build iOS IPA
        script: flutter build ipa --release --obfuscate --split-debug-info=./symbols
      - name: Build Web
        script: flutter build web --release
    artifacts:
      - build/**/outputs/**/*.aab
      - build/ios/ipa/*.ipa
      - build/web/**
    publishing:
      google_play:
        credentials: $GCLOUD_SERVICE_ACCOUNT_CREDENTIALS
        track: internal
      app_store_connect:
        api_key: $APP_STORE_CONNECT_PRIVATE_KEY
```

**Windows requires a separate workflow** on a Windows instance since macOS cannot build Windows executables:

```yaml
  windows-release:
    instance_type: windows_x2
    scripts:
      - flutter build windows --release --obfuscate --split-debug-info=./symbols
      - flutter pub run msix:create --store
```

**Code signing requirements differ significantly by platform.** Android uses Play App Signing (Google manages the certificate, you hold an upload key). iOS requires an Apple Developer Program membership ($99/year) with distribution certificates and provisioning profiles—Codemagic automates this entirely. Windows MSIX apps submitted to Microsoft Store are signed automatically by Microsoft for free. Web requires only standard HTTPS via your hosting provider.

## Subscription implementation across all platforms

**RevenueCat serves as the unified subscription management layer** for iOS, Android, and Web, costing nothing until you exceed $2,500 monthly tracked revenue, then 1% of MTR. For a €1.99/year subscription, you'd need approximately **1,256 active subscribers** before paying RevenueCat fees.

The SDK initialization handles platform detection automatically:

```dart
import 'package:purchases_flutter/purchases_flutter.dart';

Future<void> initRevenueCat() async {
  await Purchases.setLogLevel(LogLevel.debug);
  
  PurchasesConfiguration config;
  if (Platform.isIOS || Platform.isMacOS) {
    config = PurchasesConfiguration('appl_YOUR_API_KEY');
  } else if (Platform.isAndroid) {
    config = PurchasesConfiguration('goog_YOUR_API_KEY');
  } else if (kIsWeb) {
    config = PurchasesConfiguration('rcb_YOUR_WEB_API_KEY');
  }
  await Purchases.configure(config);
}

// Check subscription status
CustomerInfo info = await Purchases.getCustomerInfo();
bool isPremium = info.entitlements.active.containsKey('premium_access');
```

**Windows presents a challenge**: Flutter's `in_app_purchase` plugin doesn't support the Windows platform as of December 2024. The recommended workaround is **redirecting Windows users to a web-based Stripe checkout**, then validating the license server-side. Alternatively, implement native Windows IAP via method channels using WinRT APIs, though this requires significant C++ work.

**Net revenue calculation for €1.99/year:**
- Gross: €1.99
- After Apple/Google 15% (first year) or 30% cut: **€1.69 or €1.39**
- After RevenueCat 1% (if applicable): ~€0.02
- **Net per subscription: €1.37-1.67/year**

For web payments, RevenueCat now offers native Flutter Web support (beta) with integrated Stripe checkout, providing unified subscription management. Configure products in RevenueCat dashboard, connect your Stripe account, and use identical SDK methods as mobile.

## Free trial strategy and abuse prevention

**Platform-native trials outperform custom implementations** and avoid Apple rejection risks. Configure trials directly in App Store Connect (as Introductory Offers) and Google Play Console (as Offers within subscription base plans)—RevenueCat automatically fetches and applies them.

**Optimal trial length is 7-14 days** based on RevenueCat's aggregated data. Trials under 4 days convert 30% worse than longer trials, while 30-day trials show highest acquisition but similar conversion rates to 14-day trials. Match trial length to your app's "time-to-value"—how long users need to experience core functionality.

Trial conversion rates vary dramatically by model:
- **Opt-out trials** (credit card required upfront): ~50% conversion
- **Opt-in trials** (no card): ~25% conversion
- Industry benchmarks: Netflix achieves 93%, Amazon Prime 73%

**User account-based trial tracking is the most reliable anti-abuse measure** across platforms. Require email authentication, store trial status server-side, and use RevenueCat's automatic cross-platform sync. Device fingerprinting faces regulatory challenges (GDPR requires consent) and technical limitations (Apple's IDFA restrictions, browser spoofing).

For checking trial eligibility on iOS:
```dart
final eligibility = await Purchases.checkTrialOrIntroductoryPriceEligibility(['product_id']);
if (eligibility['product_id']?.status == IntroEligibilityStatus.introEligibilityStatusEligible) {
  // Show trial offer
}
```

On Android, Google Play filters ineligible offers server-side—if an offer appears in `subscriptionOptions`, the user is eligible.

## App store setup timeline and requirements

| Store | Registration Fee | Review Timeline | Critical Requirements |
|-------|-----------------|-----------------|----------------------|
| **Google Play** | $25 one-time | 2-7 days | 20 testers × 14 days (new personal accounts), API 34 target |
| **Apple App Store** | $99/year | 24-48 hours | Privacy manifests (May 2024), subscription disclosure rules |
| **Microsoft Store** | Free (individual) | Hours to 3 days | WACK certification, MSIX packaging |

**Google Play's new testing requirement** for personal developer accounts (created after November 2023) mandates 20 opt-in testers for at least 14 days before production release. Plan for this in your timeline.

**Apple's privacy requirements have tightened**: Privacy Manifests became mandatory May 1, 2024 for apps using common third-party SDKs. Subscription apps must prominently display price, renewal terms, and cancellation instructions before purchase per Guideline 3.1.2.

**Required assets per platform:**

| Asset | Google Play | Apple App Store | Microsoft Store |
|-------|-------------|-----------------|-----------------|
| **Icon** | 512×512 PNG | 1024×1024 PNG (no alpha) | 300×300 PNG |
| **Screenshots** | 2-8, max 3840px dimension | 1 iPhone (6.9"), 1 iPad (13") | 1-10, 1920×1080 recommended |
| **Feature graphic** | 1024×500 (required for video) | N/A | 1920×1080 hero art |
| **Description** | 4,000 chars | 4,000 chars | 10,000 chars |
| **Title** | 50 chars | 30 chars | 256 chars |

All platforms require a **privacy policy URL** and **terms of service** for subscription apps. GDPR compliance for EU users mandates explicit consent for data collection, right to deletion, and data portability.

## Release build optimization commands

Execute release builds with obfuscation to reduce size (~10%) and protect code:

```bash
# Android App Bundle (required for Play Store)
flutter build appbundle --release --obfuscate --split-debug-info=./symbols

# iOS IPA
flutter build ipa --release --obfuscate --split-debug-info=./symbols

# Windows MSIX for Microsoft Store
flutter build windows --release --obfuscate --split-debug-info=./symbols
flutter pub run msix:create --store

# Web with source maps for debugging
flutter build web --release --source-maps
```

**Keep the symbols directory secure**—it's required to symbolicate crash reports from obfuscated builds.

Enable ProGuard/R8 in `android/app/build.gradle` for additional Android optimization:
```groovy
buildTypes {
    release {
        minifyEnabled true
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
    }
}
```

**Expected app sizes for a typical portfolio app:**
- Android APK: 25-35 MB (Flutter baseline is ~4-5 MB)
- iOS IPA: 40-60 MB (Flutter baseline is ~30 MB due to bundled engine)
- Web (compressed): 5-15 MB (CanvasKit adds ~2 MB)

Analyze build size with `flutter build appbundle --analyze-size --target-platform=android-arm64`.

## Crash reporting and analytics configuration

**Firebase Crashlytics provides the most integrated Flutter experience:**

```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Capture Flutter framework errors
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  
  // Capture async errors outside Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  
  runApp(MyApp());
}
```

For obfuscated builds, upload symbols to deobfuscate stack traces:

```yaml
# Sentry configuration in pubspec.yaml
sentry:
  upload_debug_symbols: true
  upload_source_maps: true
  project: your-project
  org: your-org
```

**Privacy-compliant analytics alternatives** to Firebase Analytics include PostHog (self-hostable, GDPR-compliant), Aptabase (privacy-first, open source), and TelemetryDeck (privacy-focused). iOS apps require a `PrivacyInfo.xcprivacy` manifest since May 2024.

## Testing strategy and beta program setup

**Testing pyramid for Flutter:**
- **Many unit tests**: Fast, low maintenance
- **Moderate widget tests**: Comprehensive UI coverage
- **Selective integration tests**: Critical user flows only
- **Golden tests**: Visual regression for key screens

**Beta testing platform limits:**

| Program | Internal Testers | External Testers | Review Required |
|---------|-----------------|------------------|-----------------|
| **Google Play Internal** | 100 | - | No |
| **Google Play Closed** | - | 400,000 | Yes (~24 hours) |
| **TestFlight Internal** | 100 | - | No |
| **TestFlight External** | - | 10,000 | Yes (first build) |
| **Microsoft Package Flight** | - | 10,000 | Yes |

**Minimum device testing matrix:**
- **Android**: 1 flagship (Pixel 8/Galaxy S24), 1 mid-range (Galaxy A series), 1 budget (Moto G)
- **iOS**: 1 latest iPhone (15/16), 1 older model (11/12)
- **Web**: Chrome, Firefox, Safari, Edge

**Firebase Test Lab** offers free testing: 5 tests/day on physical devices, 10/day on virtual. Run integration tests with:
```bash
gcloud firebase test android run \
  --type instrumentation \
  --app build/app/outputs/flutter-apk/app-debug.apk \
  --test build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
```

## Complete release timeline estimate

| Phase | Duration | Key Activities |
|-------|----------|----------------|
| **Setup** | Week 1-2 | Developer accounts (Apple takes 1-4 weeks for orgs), RevenueCat configuration, privacy policy creation |
| **Development** | Week 3-6 | Subscription UI, trial flows, platform-specific configs, crash reporting integration |
| **Internal Testing** | Week 7-8 | Google Play internal track, TestFlight internal, Windows package flight |
| **Closed Beta** | Week 9-10 | Google Play closed testing (14 days required for new accounts), TestFlight external |
| **Optimization** | Week 11 | Performance profiling, crash analysis, beta feedback fixes |
| **Production Release** | Week 12 | Staged rollout (10%→50%→100%), store listing finalization |

**Critical blockers to address early:**
1. Apple Developer Program enrollment (organization verification takes 1-4 weeks)
2. Google Play 14-day closed testing requirement (for new personal accounts)
3. Windows IAP workaround decision (web checkout vs native implementation)
4. Privacy manifest creation for iOS (May 2024 requirement)

The Windows platform will likely require the most custom work due to lack of native Flutter subscription support—consider launching Windows with web-based payments initially, then adding native Microsoft Store billing later if demand warrants the development investment.