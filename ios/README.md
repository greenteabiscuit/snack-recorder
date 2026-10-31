# Snack Recorder for iOS

An additional native iOS app alongside the existing native Android app. Both versions remain in this repository: Android is in `app/` and iOS is in `ios/`. This is the first iOS implementation, not full feature parity.

## Run

Open `SnackRecorder.xcodeproj` in Xcode, select the SnackRecorder scheme and an iPhone simulator, and Run. Deployment target: iOS 17. For a physical phone, choose your signing team and a unique bundle identifier in Signing & Capabilities. The initial bundle ID is `com.greenteabiscuit.snackrecorder`.

The app requires device authentication. On a simulator, enable Face ID using Features > Face ID > Enrolled, then use Matching Face when prompted. Test rejection and cancellation too. On a physical device, Face ID, Touch ID, or the device passcode can unlock it. It locks when entering the background.

```sh
xcodebuild -project SnackRecorder.xcodeproj -scheme SnackRecorder \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
swift test
```

## Included

- Choose a day; add, edit, and delete snacks, makers, and individual other-snack entries.
- Local JSON persistence in Application Support/SnackRecorder/days.json.
- Gregorian local date keys, with no conversion to UTC days.
- Android-compatible CSV export through the system file exporter.
- Device authentication before records appear; lock on background.
- Storage load failures leave the original file in place and disable mutations.

## Data compatibility and transfer

The JSON codec uses Android's date-keyed dictionary of arrays, with `name`, `maker`, and `otherSnacks`. It also reads Android's older plain-string entries. This compatibility is tested; it does not constitute automatic data transfer or sync.

Android currently exports CSV, not a standalone JSON backup. Its CSV combines other snacks using `; `, so a snack name containing that separator cannot be reconstructed unambiguously. Before shipping a transfer flow, add a lossless JSON export to Android and an explicit, validated import/merge flow to iOS. Keep CSV export for compatibility. Do not replace existing iOS data silently.

The authentication gate protects access through the app UI. It is not a separate encrypted-vault implementation.

## Remaining work for parity and release

1. Lossless Android export and iOS import, including duplicate handling, preview, and backup.
2. Calendar grid with counts; month/year controls and monthly list including empty days.
3. All-time/yearly snack and maker rankings; frequency-based autocomplete.
4. Navigation gestures and animations, accessibility and localization review.
5. Lifecycle/privacy snapshot review and physical-device authentication checks.
6. App icon, signing, App Store metadata, and TestFlight validation.

No Android source or Gradle configuration is changed by this initial iOS addition.
