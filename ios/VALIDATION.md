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

## Physical-device installation — November 2, 2026

- The Release build passed for a physical iPhone 15 Plus running iOS 27.2.
- The app was signed with the paid developer team, installed, and launched successfully. The device reports Snack Recorder 0.1.0 (build 1), bundle ID `com.greenteabiscuit.snackrecorder`.
- The embedded development profile includes this iPhone, is not a free provisioning profile, and expires November 2, 2027. The app passed deep, strict code-signature verification.
- No UI-test launch arguments or simulated authentication were used for the device installation. Successful real Face ID/passcode authentication and real Files save/import still require user acceptance on the phone.

### Sliding navigation update

- Day lists, month lists, and calendar grids now use directional page transitions. Departing pages retain their own date and records while sliding; Reduce Motion uses a short crossfade instead.
- Three targeted simulator UI tests passed: forward/reverse day and month swipes with background relocking, calendar swipes and date selection, and snack creation/editing/deletion with persistence.
- A simulator recording was inspected frame by frame to confirm visible horizontal movement in both directions. The signed Release device build also passed.

### Quiet month rows

- Removed the repeated per-day Add snack labels. An empty day's blank row opens the fixed-date editor; the date label on a populated day adds another record, while existing snack entries retain their edit/delete controls.
- Two targeted UI tests passed, covering blank-area taps, the fixed-date editor, existing-entry editing, month summaries, and bidirectional swipe navigation without accidentally opening an editor. The signed Release device build passed.
- Today's month row uses a gray background based on the current local calendar date. The Release build with this highlight passed signature verification and was installed and launched on the iPhone.

Before shipping, validate real Face ID/Touch ID/passcode and real Files save/import on a physical device, and complete TestFlight/App Store acceptance. Automated tests do not substitute for those device checks. Broader iPad, VoiceOver, Dynamic Type, localization, and older-iOS checks remain release QA tasks.
