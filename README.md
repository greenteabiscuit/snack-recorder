# Snack Recorder

Native Android app for recording snacks eaten each day.

## Core model

Each day is represented by:

- `dateIso`: the day in `yyyy-MM-dd` format
- `snacks`: snack records with a required snack name, optional `maker`, and optional list of `otherSnacks`
- `snackCount`: calculated from `snacks.size()`

Data is stored locally in `SharedPreferences` as JSON.

## UI

- Month calendar grid with per-day snack counts
- Month and year spinners for fast navigation; year choices include current and past years only
- Previous/next month and previous/next year buttons
- Selected-day snack list
- Header list icon toggles between individual-day mode and monthly snack-list mode
- Header star button toggles a POC rankings page
- Header crosshair button slides back to the current date/current month
- Header calendar button opens the calendar date picker from either mode
- App opens to a fingerprint-protected lock screen before showing snack records
- Calendar date picker supports left/right swipe with slide animation to change months
- Monthly snack-list mode shows every day in one month, including snack-free days
- Monthly rows include weekday labels; only Saturday/Sunday weekday labels are colored blue/red
- Monthly rows align snack names in a separate column from the date/weekday label, with multiple snacks separated by new lines
- Monthly summary shows snack days
- Rankings page shows fixed all-time rankings above selectable yearly rankings for snacks and makers
- Monthly snack-list mode includes an **Add snack** modal with a date picker and snack field
- Tapping a day in monthly mode opens a fixed-date add-snack modal without leaving monthly mode
- Snack and maker entry fields autocomplete up to 3 suggestions above the input after the first typed letter, prioritizing previous snack and maker values by frequency then alphabetical order
- Swipe left/right in monthly mode to move to the next/previous month
- Swipe left/right on the main screen to move to the next/previous day
- Swipe transitions use a quick slide animation
- Add snack by typing a name, optionally typing a maker and other snacks eaten during the event, and tapping **Add**
- Edit snack names, makers, and other snacks with the ✎ button and remove them with the 🗑 button
- Export all snacks as CSV with `date,snack,maker,other_snacks` columns

## Build

```bash
./gradlew assembleDebug
```

The debug APK is generated at:

```text
app/build/outputs/apk/debug/app-debug.apk
```
