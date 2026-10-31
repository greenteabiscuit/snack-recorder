# Snack Recorder for iOS

The native SwiftUI version of Snack Recorder, developed alongside the Android app. Android stays in `app/`, iOS stays in `ios/`, and both use their own native build tools. Android implementation and Gradle files are unchanged.

## Run

Open `SnackRecorder.xcodeproj`, select the SnackRecorder scheme and an iPhone simulator, and Run. Requires iOS 17 or newer. For a physical device, select your signing team and a unique bundle ID in Signing & Capabilities. The initial bundle ID is `com.greenteabiscuit.snackrecorder`.

On the simulator, enable Face ID using Features > Face ID > Enrolled, then choose Matching Face when prompted. Real runs require Face ID, Touch ID, or the device passcode. The app locks on background and hides its content while inactive. Authentication failures leave records hidden. This is a device-authentication UI gate, not a separate encrypted vault.

## Feature coverage

| Android behavior | iOS implementation |
| --- | --- |
| Daily snack records with makers and other snacks | Day tab; add, edit, delete, and persistence |
| Calendar counts, selected day, today highlight | Calendar toolbar button opens a month grid |
| Month/year selection and previous/next controls | Month view and calendar, with current/past year menu |
| Monthly list including snack-free days | Month tab; one date column, events, and per-day Add button |
| Fixed-date add from a monthly row | Per-day Add keeps the month view open |
| Monthly Add with selectable date | Add button above month list |
| Snack events and snack-day totals | Monthly summary |
| Day/month/calendar swipes and Today shortcut | Horizontal swipes, animated date changes, Today toolbar button |
| Up to 3 autocomplete suggestions | Name, maker, and other-snack inputs; history frequency then alphabetical order, followed by Android's common defaults |
| All-time/yearly rankings | Rankings tab; separate collapsible sections, top 10 per category |
| Main-name, overall-including-others, and maker rankings | Same counting and tie-break rules as Android |
| Search names, makers, other snacks, and ISO dates | Search tab; newest events first, tap to edit |
| CSV export | Files menu > Export CSV, using the system file exporter |
| Protected startup and relock | Face ID/Touch ID/device passcode and privacy cover |
| App icon | Same vector shapes/colors as the Android snack icon |

Navigation uses native iOS tabs and sheets in place of Android's header toggles and dialogs. The data model and feature behavior stay aligned. JSON backup and import are additional iOS features.

## Move existing Android records to iOS

1. Export CSV in the Android app, then transfer that file to Files on the iPhone.
2. In iOS, open Files > Import records and choose the CSV.
3. Review the new/skipped counts and sample records, then confirm the import.

Import preserves existing data, matches duplicate occurrences, and skips records already represented in a previous import. For example, two identical events in an Android file remain two events. Re-importing the same file does not double them. Import is a one-time merge, not ongoing synchronization between devices; independently edited records can appear as additional events on later imports.

Android CSV joins other snacks with `; `. If a snack name itself contains that separator, CSV cannot preserve that distinction. The preview explains the split; review these records after import. JSON backups preserve names exactly.

Files > Back up as JSON creates a lossless iOS backup, also compatible with Android's raw date-keyed `days` JSON structure. JSON import accepts current records and Android's legacy plain-string entries. Invalid dates, missing names, malformed CSV, or unreadable files fail before anything is saved.

Local data lives in Application Support/SnackRecorder/days.json. Writes are atomic; read errors preserve the original file and disable editing/import until a successful reload. No server or shared cloud account is required.

## Validation

See [VALIDATION.md](VALIDATION.md) for the completed checks and remaining device acceptance work.

From `ios/`:

```sh
swift test
xcodebuild -project SnackRecorder.xcodeproj -scheme SnackRecorder \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
xcodebuild -project SnackRecorder.xcodeproj -scheme SnackRecorder \
  -configuration Release -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Core tests cover Android data compatibility, CRUD, persistence, corrupt-file preservation, CSV quoting including CRLF/Unicode, import validation and duplicate multiplicity, search, ranking/suggestion rules, leap dates, and date boundaries.

The Xcode UI-test target exercises the main flows through the app. It uses a dedicated test data directory and a fixed date. Authentication and the selected import file are injected at their boundaries in **Debug UI-test runs only**; the actual UI, file persistence, parsers, and merge code run normally. Release builds have no test authentication path. Real biometrics and the system Files picker still need device acceptance checks.

## Before App Store release

- Physical-device Face ID/Touch ID/passcode and system Files export/import acceptance.
- Signing/provisioning, TestFlight, App Store metadata and privacy disclosures.
- Broader VoiceOver, Dynamic Type, iPad, localization, and older-iOS device review.
