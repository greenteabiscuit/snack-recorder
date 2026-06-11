# Snack Recorder

Native Android app for recording snacks eaten each day.

## Core model

Each day is represented by:

- `dateIso`: the day in `yyyy-MM-dd` format
- `snacks`: `List<String>` of snack names eaten that day
- `snackCount`: calculated from `snacks.size()`

Data is stored locally in `SharedPreferences` as JSON.

## UI

- Month calendar grid with per-day snack counts
- Month and year spinners for fast navigation
- Previous/next month and previous/next year buttons
- Selected-day snack list
- Header list icon toggles between individual-day mode and monthly snack-list mode
- Header crosshair button slides back to the current date/current month
- Header calendar button opens the calendar date picker from either mode
- Calendar date picker supports left/right swipe with slide animation to change months
- Monthly snack-list mode shows every day in one month, including snack-free days
- Monthly rows include weekday labels; only Saturday/Sunday weekday labels are colored blue/red
- Monthly summary shows snack count, snack days, and snack-free days
- Monthly snack-list mode includes an **Add snack** modal with a date picker and snack field
- Tapping a day in monthly mode opens the add-snack modal for that date without leaving monthly mode
- Swipe left/right in monthly mode to move to the next/previous month
- Swipe left/right on the main screen to move to the next/previous day
- Swipe transitions use a quick slide animation
- Add snack by typing a name and tapping **Add**
- Edit snacks with the ✎ button and remove them with the 🗑 button
- Export all snacks as CSV with `date,snack` columns

## Build

```bash
./gradlew assembleDebug
```

The debug APK is generated at:

```text
app/build/outputs/apk/debug/app-debug.apk
```
