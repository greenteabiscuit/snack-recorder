# iOS parity validation

Validated on October 31, 2026 (Asia/Tokyo), with Xcode 26.2, Swift 6.2.3, and an iPhone 17 simulator running iOS 26.2.

- **14 core tests passed.** Coverage includes Android current/legacy JSON, persistence, corrupt-file preservation, local date keys, leap dates/year boundaries, ranking categories and counts, autocomplete ordering, cross-field search, CSV quoting/CRLF/Unicode, import validation, and duplicate-event handling.
- **10 simulator UI flows passed.** The main run passed nine flows; after correcting the exporter test for the iOS 26 sheet UI, the exporter flow passed in a targeted rerun. The app code is identical across those runs.
- **Release simulator build passed** for arm64 and x86_64. Test launch/authentication/fixture flags were absent from the Release executable.
- **Android source and build configuration are unchanged** relative to main. Android was not rebuilt during this iOS change.

| UI flow | Result |
| --- | --- |
| Add snack with maker and other snacks; edit, relaunch, delete | Passed |
| Monthly empty days, fixed-date add, selectable-date add, summary | Passed |
| Calendar counts, month/year controls, leap-day selection, Today | Passed |
| Search names, makers, other snacks, dates, and edit results | Passed |
| All-time/yearly rankings and selecting an autocomplete suggestion | Passed |
| Day/month swipes, Today, relock on background, retained navigation | Passed |
| Authentication rejection keeps records hidden | Passed |
| Backgrounding while editing dismisses the editor and relocks | Passed |
| Import preview, merge, and repeat-import duplicate handling | Passed |
| System CSV exporter shows the expected filename and dismisses | Passed |

Each test uses its own resettable test data namespace. Authentication is injected for automated UI runs, and the import test injects a selected CSV at the file-reader boundary; neither injection is compiled into Release builds. CSV export uses the real system sheet. Named screenshots are attached to Xcode test results.

Before shipping, validate real Face ID/Touch ID/passcode and real Files save/import on a physical device, configure signing, and complete TestFlight/App Store acceptance. Automated tests do not substitute for those device checks. Broader iPad, VoiceOver, Dynamic Type, localization, and older-iOS checks remain release QA tasks.
