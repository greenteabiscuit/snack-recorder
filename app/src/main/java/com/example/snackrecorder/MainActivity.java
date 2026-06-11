package com.example.snackrecorder;

import android.app.Activity;
import android.app.Dialog;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Bundle;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.Window;
import android.view.animation.DecelerateInterpolator;
import android.view.inputmethod.EditorInfo;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.DatePicker;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.GridLayout;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.text.DateFormatSymbols;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public final class MainActivity extends Activity {
    private static final int ORANGE = Color.rgb(249, 115, 22);
    private static final int ORANGE_DARK = Color.rgb(194, 65, 12);
    private static final int ORANGE_LIGHT = Color.rgb(255, 237, 213);
    private static final int BACKGROUND = Color.rgb(255, 247, 237);
    private static final int TEXT_DARK = Color.rgb(67, 20, 7);
    private static final int TEXT_MUTED = Color.rgb(120, 113, 108);
    private static final int SATURDAY_BLUE = Color.rgb(37, 99, 235);
    private static final int SUNDAY_RED = Color.rgb(220, 38, 38);
    private static final int MIN_SWIPE_DISTANCE_DP = 72;
    private static final int REQUEST_CREATE_CSV = 1001;
    private static final int SLIDE_DISTANCE_DP = 56;

    private final SimpleDateFormat isoDateFormat = new SimpleDateFormat("yyyy-MM-dd", Locale.US);
    private final SimpleDateFormat friendlyDateFormat = new SimpleDateFormat("EEE, MMM d, yyyy", Locale.US);
    private final SimpleDateFormat compactDateFormat = new SimpleDateFormat("MMM d", Locale.US);
    private final SimpleDateFormat weekdayFormat = new SimpleDateFormat("EEE", Locale.US);
    private final ArrayList<TextView> dayCells = new ArrayList<>();
    private final ArrayList<String> monthRowDates = new ArrayList<>();
    private final String[] monthNames = new DateFormatSymbols(Locale.US).getMonths();

    private SnackStore snackStore;
    private Calendar visibleMonth;
    private String selectedDateIso;
    private Dialog calendarDialog;
    private float touchDownX;
    private float touchDownY;
    private boolean monthView;
    private boolean slideInProgress;
    private Spinner monthSpinner;
    private Spinner yearSpinner;
    private Button viewToggleButton;
    private LinearLayout selectedDayPanel;
    private LinearLayout monthPanel;
    private TextView selectedDayTitle;
    private TextView selectedDayCount;
    private TextView monthTitle;
    private TextView monthSummary;
    private TextView monthAddDateLabel;
    private EditText snackInput;
    private LinearLayout snackListContainer;
    private ArrayAdapter<CharSequence> monthListAdapter;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        snackStore = new SnackStore(this);
        Calendar today = Calendar.getInstance();
        selectedDateIso = isoDateFormat.format(today.getTime());
        visibleMonth = firstDayOfMonth(today);

        setContentView(createContentView());
        renderSelectedDay();
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQUEST_CREATE_CSV || resultCode != RESULT_OK || data == null || data.getData() == null) {
            return;
        }

        writeCsvToUri(data.getData());
    }

    @Override
    public boolean dispatchTouchEvent(MotionEvent event) {
        if (calendarDialog == null && !slideInProgress) {
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    touchDownX = event.getX();
                    touchDownY = event.getY();
                    break;
                case MotionEvent.ACTION_UP:
                    float deltaX = event.getX() - touchDownX;
                    float deltaY = event.getY() - touchDownY;
                    int minSwipeDistance = dp(MIN_SWIPE_DISTANCE_DP);
                    if (Math.abs(deltaX) > minSwipeDistance && Math.abs(deltaX) > Math.abs(deltaY) * 1.5f) {
                        if (monthView) {
                            slideToMonth(deltaX < 0 ? 1 : -1);
                        } else {
                            slideToSelectedDay(deltaX < 0 ? 1 : -1);
                        }
                        return true;
                    }
                    break;
                default:
                    break;
            }
        }
        return super.dispatchTouchEvent(event);
    }

    private FrameLayout createContentView() {
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(BACKGROUND);

        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        int horizontalPadding = dp(16);
        int topPadding = dp(14);
        int bottomPadding = dp(92);
        content.setPadding(horizontalPadding, topPadding, horizontalPadding, bottomPadding);

        LinearLayout titleRow = new LinearLayout(this);
        titleRow.setGravity(Gravity.CENTER_VERTICAL);

        TextView title = new TextView(this);
        title.setText("Snack Recorder");
        title.setTextColor(TEXT_DARK);
        title.setTextSize(28);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        titleRow.addView(title, new LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
        ));

        Button todayButton = compactButton("⌖");
        todayButton.setTextSize(22);
        todayButton.setOnClickListener(view -> goToToday());
        titleRow.addView(todayButton);

        Button calendarButton = compactButton("▦");
        calendarButton.setTextSize(22);
        calendarButton.setOnClickListener(view -> showCalendarDialog());
        titleRow.addView(calendarButton);

        viewToggleButton = compactButton("☰");
        viewToggleButton.setTextSize(22);
        viewToggleButton.setOnClickListener(view -> toggleMonthView());
        titleRow.addView(viewToggleButton);
        content.addView(titleRow);

        TextView subtitle = new TextView(this);
        subtitle.setText("Track the list of snacks you ate each day.");
        subtitle.setTextColor(TEXT_MUTED);
        subtitle.setTextSize(15);
        content.addView(subtitle);

        content.addView(createSelectedDayPanel(), new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
        ));

        content.addView(createMonthPanel(), new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
        ));

        root.addView(content, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));

        Button exportButton = circularExportButton();
        FrameLayout.LayoutParams exportButtonParams = new FrameLayout.LayoutParams(dp(72), dp(72));
        exportButtonParams.gravity = Gravity.BOTTOM | Gravity.END;
        exportButtonParams.setMargins(0, 0, dp(16), dp(16));
        root.addView(exportButton, exportButtonParams);

        root.setOnApplyWindowInsetsListener((view, insets) -> {
            content.setPadding(
                    horizontalPadding,
                    topPadding + insets.getSystemWindowInsetTop(),
                    horizontalPadding,
                    bottomPadding + insets.getSystemWindowInsetBottom()
            );

            FrameLayout.LayoutParams params = (FrameLayout.LayoutParams) exportButton.getLayoutParams();
            params.setMargins(0, 0, dp(16), dp(16) + insets.getSystemWindowInsetBottom());
            exportButton.setLayoutParams(params);
            return insets;
        });

        return root;
    }

    private Button circularExportButton() {
        Button button = new Button(this);
        button.setText("CSV");
        button.setTextColor(Color.WHITE);
        button.setTextSize(14);
        button.setTypeface(Typeface.DEFAULT_BOLD);
        button.setAllCaps(false);
        button.setBackground(roundRect(ORANGE, dp(36), Color.TRANSPARENT, 0));
        button.setElevation(dp(8));
        button.setOnClickListener(view -> exportCsv());
        return button;
    }

    private void toggleMonthView() {
        monthView = !monthView;
        if (monthView) {
            visibleMonth = firstDayOfMonth(selectedDateCalendar());
            selectedDayPanel.setVisibility(View.GONE);
            monthPanel.setVisibility(View.VISIBLE);
            viewToggleButton.setText("1");
            renderMonthView();
        } else {
            selectedDayPanel.setVisibility(View.VISIBLE);
            monthPanel.setVisibility(View.GONE);
            viewToggleButton.setText("☰");
            renderSelectedDay();
        }
    }

    private LinearLayout createMonthControls() {
        LinearLayout controls = new LinearLayout(this);
        controls.setGravity(Gravity.CENTER_VERTICAL);
        controls.setPadding(0, dp(12), 0, dp(8));

        Button previousYear = compactButton("«");
        previousYear.setOnClickListener(view -> shiftYear(-1));
        controls.addView(previousYear);

        Button previousMonth = compactButton("‹");
        previousMonth.setOnClickListener(view -> shiftMonth(-1));
        controls.addView(previousMonth);

        monthSpinner = new Spinner(this);
        ArrayAdapter<String> monthAdapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_item, visibleMonthNames());
        monthAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        monthSpinner.setAdapter(monthAdapter);
        monthSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, android.view.View view, int position, long id) {
                if (visibleMonth.get(Calendar.MONTH) != position) {
                    visibleMonth.set(Calendar.MONTH, position);
                    visibleMonth = firstDayOfMonth(visibleMonth);
                    renderCalendar();
                }
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
            }
        });
        controls.addView(monthSpinner, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        yearSpinner = new Spinner(this);
        ArrayAdapter<String> yearAdapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_item, yearOptions());
        yearAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        yearSpinner.setAdapter(yearAdapter);
        yearSpinner.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, android.view.View view, int position, long id) {
                int year = Integer.parseInt((String) parent.getItemAtPosition(position));
                if (visibleMonth.get(Calendar.YEAR) != year) {
                    visibleMonth.set(Calendar.YEAR, year);
                    visibleMonth = firstDayOfMonth(visibleMonth);
                    renderCalendar();
                }
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {
            }
        });
        controls.addView(yearSpinner, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 0.72f));

        Button nextMonth = compactButton("›");
        nextMonth.setOnClickListener(view -> shiftMonth(1));
        controls.addView(nextMonth);

        Button nextYear = compactButton("»");
        nextYear.setOnClickListener(view -> shiftYear(1));
        controls.addView(nextYear);

        return controls;
    }

    private GridLayout createCalendarGrid() {
        GridLayout grid = new GridLayout(this);
        grid.setColumnCount(7);
        grid.setRowCount(7);
        grid.setPadding(0, dp(4), 0, dp(8));

        String[] weekDays = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
        for (String weekDay : weekDays) {
            TextView label = calendarLabel(weekDay);
            grid.addView(label, gridParams(dp(28)));
        }

        for (int i = 0; i < 42; i++) {
            TextView dayCell = calendarDayCell();
            dayCells.add(dayCell);
            grid.addView(dayCell, gridParams(dp(54)));
        }
        return grid;
    }

    private LinearLayout createSelectedDayPanel() {
        LinearLayout panel = new LinearLayout(this);
        selectedDayPanel = panel;
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(dp(14), dp(12), dp(14), dp(12));
        panel.setBackground(roundRect(Color.WHITE, dp(18), Color.TRANSPARENT, 0));

        selectedDayTitle = new TextView(this);
        selectedDayTitle.setTextColor(TEXT_DARK);
        selectedDayTitle.setTextSize(20);
        selectedDayTitle.setTypeface(Typeface.DEFAULT_BOLD);
        panel.addView(selectedDayTitle);

        selectedDayCount = new TextView(this);
        selectedDayCount.setTextColor(ORANGE_DARK);
        selectedDayCount.setTextSize(15);
        selectedDayCount.setPadding(0, dp(2), 0, dp(10));
        panel.addView(selectedDayCount);

        LinearLayout addRow = new LinearLayout(this);
        addRow.setGravity(Gravity.CENTER_VERTICAL);
        addRow.setPadding(0, dp(8), 0, 0);

        snackInput = new EditText(this);
        snackInput.setSingleLine(true);
        snackInput.setHint("Snack name, e.g. almonds");
        snackInput.setImeOptions(EditorInfo.IME_ACTION_DONE);
        snackInput.setOnEditorActionListener((view, actionId, event) -> {
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                addSnackFromInput();
                return true;
            }
            return false;
        });
        addRow.addView(snackInput, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

        Button addButton = new Button(this);
        addButton.setText("Add");
        addButton.setOnClickListener(view -> addSnackFromInput());
        addRow.addView(addButton);
        panel.addView(addRow);

        snackListContainer = new LinearLayout(this);
        snackListContainer.setOrientation(LinearLayout.VERTICAL);
        snackListContainer.setPadding(0, dp(8), 0, 0);
        panel.addView(snackListContainer, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
        ));

        return panel;
    }

    private LinearLayout createMonthPanel() {
        LinearLayout panel = new LinearLayout(this);
        monthPanel = panel;
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(dp(14), dp(12), dp(14), dp(12));
        panel.setBackground(roundRect(Color.WHITE, dp(18), Color.TRANSPARENT, 0));
        panel.setVisibility(View.GONE);

        monthTitle = new TextView(this);
        monthTitle.setTextColor(TEXT_DARK);
        monthTitle.setTextSize(22);
        monthTitle.setTypeface(Typeface.DEFAULT_BOLD);
        panel.addView(monthTitle);

        monthSummary = new TextView(this);
        monthSummary.setTextColor(ORANGE_DARK);
        monthSummary.setTextSize(15);
        monthSummary.setPadding(0, dp(2), 0, dp(10));
        panel.addView(monthSummary);

        TextView hint = new TextView(this);
        hint.setText("Swipe left/right for next/previous month. Tap a day to open it.");
        hint.setTextColor(TEXT_MUTED);
        hint.setTextSize(13);
        hint.setPadding(0, 0, 0, dp(8));
        panel.addView(hint);

        monthAddDateLabel = new TextView(this);
        monthAddDateLabel.setTextColor(TEXT_MUTED);
        monthAddDateLabel.setTextSize(13);
        panel.addView(monthAddDateLabel);

        Button addButton = new Button(this);
        addButton.setText("Add snack");
        addButton.setAllCaps(false);
        addButton.setOnClickListener(view -> showAddSnackDialog());
        panel.addView(addButton, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
        ));

        ListView monthList = new ListView(this);
        monthListAdapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, new ArrayList<>());
        monthList.setAdapter(monthListAdapter);
        monthList.setOnItemClickListener((parent, view, position, id) -> {
            if (position < 0 || position >= monthRowDates.size()) {
                return;
            }

            selectedDateIso = monthRowDates.get(position);
            toggleMonthView();
        });
        panel.addView(monthList, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f
        ));

        return panel;
    }

    private void showCalendarDialog() {
        visibleMonth = firstDayOfMonth(selectedDateCalendar());
        dayCells.clear();

        Dialog dialog = new Dialog(this);
        calendarDialog = dialog;
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(14), dp(14), dp(14), dp(10));
        content.setBackgroundColor(BACKGROUND);

        TextView title = new TextView(this);
        title.setText("Choose snack day");
        title.setTextColor(TEXT_DARK);
        title.setTextSize(22);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        content.addView(title);

        TextView hint = new TextView(this);
        hint.setText("Switch months or years, then tap a day.");
        hint.setTextColor(TEXT_MUTED);
        hint.setTextSize(14);
        content.addView(hint);

        content.addView(createMonthControls());
        content.addView(createCalendarGrid());

        Button closeButton = new Button(this);
        closeButton.setText("Close");
        closeButton.setAllCaps(false);
        closeButton.setOnClickListener(view -> dialog.dismiss());
        content.addView(closeButton, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
        ));

        dialog.setContentView(content);
        dialog.setOnDismissListener(dialogInterface -> {
            calendarDialog = null;
            monthSpinner = null;
            yearSpinner = null;
            dayCells.clear();
        });
        dialog.show();

        Window window = dialog.getWindow();
        if (window != null) {
            window.setLayout(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
            );
        }

        renderCalendar();
    }

    private void renderCalendar() {
        if (monthSpinner == null || yearSpinner == null || dayCells.isEmpty()) {
            return;
        }

        monthSpinner.setSelection(visibleMonth.get(Calendar.MONTH));
        selectYearSpinnerValue(visibleMonth.get(Calendar.YEAR));

        Calendar cursor = firstDayOfMonth(visibleMonth);
        int firstDayOffset = cursor.get(Calendar.DAY_OF_WEEK) - Calendar.SUNDAY;
        int maxDay = cursor.getActualMaximum(Calendar.DAY_OF_MONTH);
        String todayIso = isoDateFormat.format(Calendar.getInstance().getTime());

        for (int i = 0; i < dayCells.size(); i++) {
            TextView cell = dayCells.get(i);
            int dayOfMonth = i - firstDayOffset + 1;
            if (dayOfMonth < 1 || dayOfMonth > maxDay) {
                cell.setText("");
                cell.setOnClickListener(null);
                cell.setBackgroundColor(Color.TRANSPARENT);
                continue;
            }

            Calendar cellDate = firstDayOfMonth(visibleMonth);
            cellDate.set(Calendar.DAY_OF_MONTH, dayOfMonth);
            String cellDateIso = isoDateFormat.format(cellDate.getTime());
            int snackCount = snackStore.getSnackCount(cellDateIso);
            boolean selected = cellDateIso.equals(selectedDateIso);
            boolean today = cellDateIso.equals(todayIso);

            String label = String.valueOf(dayOfMonth);
            if (snackCount > 0) {
                label += "\n" + snackCount + " snack" + (snackCount == 1 ? "" : "s");
            }
            cell.setText(label);
            cell.setTextColor(selected ? Color.WHITE : TEXT_DARK);
            cell.setTypeface(Typeface.DEFAULT, selected || snackCount > 0 ? Typeface.BOLD : Typeface.NORMAL);
            cell.setBackground(dayBackground(selected, today, snackCount));
            cell.setOnClickListener(view -> {
                selectedDateIso = cellDateIso;
                renderCalendar();
                renderSelectedDay();
                if (calendarDialog != null) {
                    calendarDialog.dismiss();
                }
            });
        }
    }

    private void renderSelectedDay() {
        SnackDay snackDay = snackStore.getDay(selectedDateIso);
        Calendar selected = Calendar.getInstance();
        try {
            selected.setTime(isoDateFormat.parse(snackDay.getDateIso()));
        } catch (Exception ignored) {
        }

        int count = snackDay.getSnackCount();
        selectedDayTitle.setText(friendlyDateFormat.format(selected.getTime()));
        selectedDayCount.setText(count + " snack" + (count == 1 ? "" : "s") + " recorded · " + snackDay.getDateIso());
        renderSnackRows(snackDay);
    }

    private void renderSnackRows(SnackDay snackDay) {
        if (snackListContainer == null) {
            return;
        }

        snackListContainer.removeAllViews();
        List<String> snacks = snackDay.getSnacks();
        if (snacks.isEmpty()) {
            TextView emptyState = new TextView(this);
            emptyState.setText("No snacks recorded for this day.");
            emptyState.setTextColor(TEXT_MUTED);
            emptyState.setTextSize(15);
            emptyState.setPadding(0, dp(12), 0, 0);
            snackListContainer.addView(emptyState);
            return;
        }

        for (int i = 0; i < snacks.size(); i++) {
            snackListContainer.addView(createSnackRow(snacks.get(i), i));
        }
    }

    private LinearLayout createSnackRow(String snack, int snackIndex) {
        LinearLayout row = new LinearLayout(this);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(0, dp(3), 0, dp(3));

        TextView snackName = new TextView(this);
        snackName.setText(snack);
        snackName.setTextColor(TEXT_DARK);
        snackName.setTextSize(18);
        row.addView(snackName, new LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
        ));

        Button editButton = compactButton("✎");
        editButton.setTextSize(18);
        editButton.setOnClickListener(view -> showEditSnackDialog(snackIndex, snack));
        row.addView(editButton);

        Button deleteButton = compactButton("🗑");
        deleteButton.setTextSize(18);
        deleteButton.setOnClickListener(view -> {
            snackStore.removeSnack(selectedDateIso, snackIndex);
            refreshAllViews();
        });
        row.addView(deleteButton);

        return row;
    }

    private void showEditSnackDialog(int snackIndex, String currentSnack) {
        Dialog dialog = new Dialog(this);
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(16), dp(16), dp(16), dp(12));
        content.setBackgroundColor(BACKGROUND);

        TextView title = new TextView(this);
        title.setText("Edit snack");
        title.setTextColor(TEXT_DARK);
        title.setTextSize(22);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        content.addView(title);

        EditText editInput = new EditText(this);
        editInput.setSingleLine(true);
        editInput.setText(currentSnack);
        editInput.setSelectAllOnFocus(true);
        editInput.setImeOptions(EditorInfo.IME_ACTION_DONE);
        content.addView(editInput, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
        ));

        LinearLayout actions = new LinearLayout(this);
        actions.setGravity(Gravity.END);
        actions.setPadding(0, dp(10), 0, 0);

        Button cancelButton = new Button(this);
        cancelButton.setText("Cancel");
        cancelButton.setAllCaps(false);
        cancelButton.setOnClickListener(view -> dialog.dismiss());
        actions.addView(cancelButton);

        Button saveButton = new Button(this);
        saveButton.setText("Save");
        saveButton.setAllCaps(false);
        saveButton.setOnClickListener(view -> {
            String updatedSnack = editInput.getText().toString().trim();
            if (updatedSnack.isEmpty()) {
                Toast.makeText(this, "Enter a snack first", Toast.LENGTH_SHORT).show();
                return;
            }

            snackStore.updateSnack(selectedDateIso, snackIndex, updatedSnack);
            refreshAllViews();
            dialog.dismiss();
        });
        actions.addView(saveButton);
        content.addView(actions);

        dialog.setContentView(content);
        dialog.show();

        Window window = dialog.getWindow();
        if (window != null) {
            window.setLayout(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
            );
        }
    }

    private void renderMonthView() {
        if (monthTitle == null || monthSummary == null || monthListAdapter == null || monthAddDateLabel == null) {
            return;
        }

        int year = visibleMonth.get(Calendar.YEAR);
        int month = visibleMonth.get(Calendar.MONTH);
        List<SnackDay> monthDays = snackStore.getDaysInMonth(year, month);
        Map<String, SnackDay> daysByDate = new HashMap<>();
        int snackCount = 0;
        int snackDays = 0;

        monthTitle.setText(monthNames[month] + " " + year);
        monthListAdapter.clear();
        monthRowDates.clear();

        for (SnackDay day : monthDays) {
            daysByDate.put(day.getDateIso(), day);
        }

        Calendar cursor = firstDayOfMonth(visibleMonth);
        int daysInMonth = cursor.getActualMaximum(Calendar.DAY_OF_MONTH);
        for (int dayOfMonth = 1; dayOfMonth <= daysInMonth; dayOfMonth++) {
            cursor.set(Calendar.DAY_OF_MONTH, dayOfMonth);
            String dateIso = isoDateFormat.format(cursor.getTime());
            SnackDay day = daysByDate.get(dateIso);
            Calendar dayCalendar = Calendar.getInstance();
            dayCalendar.setTime(cursor.getTime());

            monthRowDates.add(dateIso);
            String dayLabel = compactDateFormat.format(dayCalendar.getTime())
                    + " ("
                    + weekdayFormat.format(dayCalendar.getTime())
                    + ")";
            if (day == null || day.getSnackCount() == 0) {
                monthListAdapter.add(formatMonthRow(dayCalendar, dayLabel + "  ·  "));
            } else {
                snackDays++;
                snackCount += day.getSnackCount();
                monthListAdapter.add(formatMonthRow(dayCalendar, dayLabel + "  ·  " + formatSnackList(day.getSnacks())));
            }
        }

        int snackFreeDays = daysInMonth - snackDays;
        monthSummary.setText(
                snackCount + " snack" + (snackCount == 1 ? "" : "s")
                        + " · "
                        + snackDays + " snack day" + (snackDays == 1 ? "" : "s")
                        + " · "
                        + snackFreeDays + " snack-free day" + (snackFreeDays == 1 ? "" : "s")
        );
        monthAddDateLabel.setText("Add a snack with a date in " + monthNames[month]);
        monthListAdapter.notifyDataSetChanged();
    }

    private String formatSnackList(List<String> snacks) {
        StringBuilder list = new StringBuilder();
        for (int i = 0; i < snacks.size(); i++) {
            if (i > 0) {
                list.append(", ");
            }
            list.append(snacks.get(i));
        }
        return list.toString();
    }

    private CharSequence formatMonthRow(Calendar dayCalendar, String rowText) {
        int dayOfWeek = dayCalendar.get(Calendar.DAY_OF_WEEK);
        int color = TEXT_DARK;
        if (dayOfWeek == Calendar.SATURDAY) {
            color = SATURDAY_BLUE;
        } else if (dayOfWeek == Calendar.SUNDAY) {
            color = SUNDAY_RED;
        } else {
            return rowText;
        }

        int weekdayStart = rowText.indexOf('(');
        int weekdayEnd = rowText.indexOf(')', weekdayStart);
        if (weekdayStart < 0 || weekdayEnd < weekdayStart) {
            return rowText;
        }

        SpannableString styledRow = new SpannableString(rowText);
        styledRow.setSpan(
                new ForegroundColorSpan(color),
                weekdayStart,
                weekdayEnd + 1,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
        );
        return styledRow;
    }

    private void exportCsv() {
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("text/csv");
        intent.putExtra(Intent.EXTRA_TITLE, "snack-recorder.csv");
        startActivityForResult(intent, REQUEST_CREATE_CSV);
    }

    private void writeCsvToUri(Uri uri) {
        try (OutputStream outputStream = getContentResolver().openOutputStream(uri)) {
            if (outputStream == null) {
                Toast.makeText(this, "Could not open export file", Toast.LENGTH_SHORT).show();
                return;
            }

            outputStream.write(snackStore.exportCsv().getBytes(StandardCharsets.UTF_8));
            Toast.makeText(this, "CSV exported", Toast.LENGTH_SHORT).show();
        } catch (Exception exception) {
            Toast.makeText(this, "CSV export failed", Toast.LENGTH_SHORT).show();
        }
    }

    private void addSnackFromInput() {
        String snack = snackInput.getText().toString().trim();
        if (snack.isEmpty()) {
            Toast.makeText(this, "Enter a snack first", Toast.LENGTH_SHORT).show();
            return;
        }

        snackStore.addSnack(selectedDateIso, snack);
        snackInput.setText("");
        refreshAllViews();
    }

    private void refreshAllViews() {
        renderCalendar();
        renderSelectedDay();
        renderMonthView();
    }

    private Calendar monthAddDateCalendar() {
        Calendar selected = selectedDateCalendar();
        boolean selectedDateInVisibleMonth = selected.get(Calendar.YEAR) == visibleMonth.get(Calendar.YEAR)
                && selected.get(Calendar.MONTH) == visibleMonth.get(Calendar.MONTH);
        if (selectedDateInVisibleMonth) {
            return selected;
        }

        return firstDayOfMonth(visibleMonth);
    }

    private void showAddSnackDialog() {
        Calendar defaultDate = monthAddDateCalendar();

        Dialog dialog = new Dialog(this);
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(16), dp(16), dp(16), dp(12));
        content.setBackgroundColor(BACKGROUND);

        TextView title = new TextView(this);
        title.setText("Add snack");
        title.setTextColor(TEXT_DARK);
        title.setTextSize(22);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        content.addView(title);

        TextView hint = new TextView(this);
        hint.setText("Choose the date and enter the snack you ate.");
        hint.setTextColor(TEXT_MUTED);
        hint.setTextSize(14);
        hint.setPadding(0, 0, 0, dp(8));
        content.addView(hint);

        DatePicker datePicker = new DatePicker(this);
        datePicker.init(
                defaultDate.get(Calendar.YEAR),
                defaultDate.get(Calendar.MONTH),
                defaultDate.get(Calendar.DAY_OF_MONTH),
                null
        );
        content.addView(datePicker);

        EditText snackInput = new EditText(this);
        snackInput.setSingleLine(true);
        snackInput.setHint("Snack name");
        snackInput.setImeOptions(EditorInfo.IME_ACTION_DONE);
        content.addView(snackInput, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
        ));

        LinearLayout actions = new LinearLayout(this);
        actions.setGravity(Gravity.END);
        actions.setPadding(0, dp(10), 0, 0);

        Button cancelButton = new Button(this);
        cancelButton.setText("Cancel");
        cancelButton.setAllCaps(false);
        cancelButton.setOnClickListener(view -> dialog.dismiss());
        actions.addView(cancelButton);

        Button saveButton = new Button(this);
        saveButton.setText("Add");
        saveButton.setAllCaps(false);
        saveButton.setOnClickListener(view -> {
            String snack = snackInput.getText().toString().trim();
            if (snack.isEmpty()) {
                Toast.makeText(this, "Enter a snack first", Toast.LENGTH_SHORT).show();
                return;
            }

            Calendar selectedDate = Calendar.getInstance();
            selectedDate.set(datePicker.getYear(), datePicker.getMonth(), datePicker.getDayOfMonth(), 0, 0, 0);
            selectedDate.set(Calendar.MILLISECOND, 0);
            selectedDateIso = isoDateFormat.format(selectedDate.getTime());
            visibleMonth = firstDayOfMonth(selectedDate);
            snackStore.addSnack(selectedDateIso, snack);
            renderCalendar();
            renderSelectedDay();
            renderMonthView();
            dialog.dismiss();
        });
        actions.addView(saveButton);
        content.addView(actions);

        dialog.setContentView(content);
        dialog.show();

        Window window = dialog.getWindow();
        if (window != null) {
            window.setLayout(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
            );
        }
    }

    private void shiftSelectedDay(int deltaDays) {
        Calendar selected = selectedDateCalendar();
        selected.add(Calendar.DAY_OF_MONTH, deltaDays);
        selectedDateIso = isoDateFormat.format(selected.getTime());
        visibleMonth = firstDayOfMonth(selected);
        renderCalendar();
        renderSelectedDay();
    }

    private void goToToday() {
        Calendar today = Calendar.getInstance();
        if (monthView) {
            int monthDelta = monthDelta(visibleMonth, today);
            if (monthDelta == 0) {
                jumpToToday();
            } else {
                slideToTodayMonth(monthDelta > 0 ? 1 : -1);
            }
            return;
        }

        Calendar selected = selectedDateCalendar();
        int dayDelta = today.compareTo(selected);
        if (dayDelta == 0) {
            jumpToToday();
        } else {
            slideToTodayDay(dayDelta > 0 ? 1 : -1);
        }
    }

    private void jumpToToday() {
        Calendar today = Calendar.getInstance();
        selectedDateIso = isoDateFormat.format(today.getTime());
        visibleMonth = firstDayOfMonth(today);
        renderCalendar();
        renderSelectedDay();
        renderMonthView();
    }

    private int monthDelta(Calendar fromMonth, Calendar toDate) {
        return (toDate.get(Calendar.YEAR) - fromMonth.get(Calendar.YEAR)) * 12
                + toDate.get(Calendar.MONTH) - fromMonth.get(Calendar.MONTH);
    }

    private void slideToTodayDay(int direction) {
        if (selectedDayPanel == null) {
            jumpToToday();
            return;
        }

        runSlide(selectedDayPanel, direction, this::jumpToToday);
    }

    private void slideToTodayMonth(int direction) {
        if (monthPanel == null) {
            jumpToToday();
            return;
        }

        runSlide(monthPanel, direction, this::jumpToToday);
    }

    private void slideToSelectedDay(int deltaDays) {
        if (selectedDayPanel == null) {
            shiftSelectedDay(deltaDays);
            return;
        }

        runSlide(selectedDayPanel, deltaDays, () -> shiftSelectedDay(deltaDays));
    }

    private void slideToMonth(int deltaMonths) {
        if (monthPanel == null) {
            shiftVisibleMonth(deltaMonths);
            return;
        }

        runSlide(monthPanel, deltaMonths, () -> shiftVisibleMonth(deltaMonths));
    }

    private void runSlide(View panel, int direction, Runnable contentChange) {
        slideInProgress = true;
        int slideDistance = dp(SLIDE_DISTANCE_DP);
        int outgoingX = direction > 0 ? -slideDistance : slideDistance;
        int incomingX = -outgoingX;
        DecelerateInterpolator interpolator = new DecelerateInterpolator();

        panel.animate()
                .translationX(outgoingX)
                .alpha(0.35f)
                .setDuration(75)
                .setInterpolator(interpolator)
                .withEndAction(() -> {
                    contentChange.run();
                    panel.setTranslationX(incomingX);
                    panel.animate()
                            .translationX(0f)
                            .alpha(1f)
                            .setDuration(95)
                            .setInterpolator(interpolator)
                            .withEndAction(() -> slideInProgress = false)
                            .start();
                })
                .start();
    }

    private void shiftVisibleMonth(int deltaMonths) {
        visibleMonth.add(Calendar.MONTH, deltaMonths);
        visibleMonth = firstDayOfMonth(visibleMonth);
        renderCalendar();
        renderMonthView();
    }

    private void shiftMonth(int delta) {
        visibleMonth.add(Calendar.MONTH, delta);
        visibleMonth = firstDayOfMonth(visibleMonth);
        renderCalendar();
        renderMonthView();
    }

    private void shiftYear(int delta) {
        visibleMonth.add(Calendar.YEAR, delta);
        visibleMonth = firstDayOfMonth(visibleMonth);
        renderCalendar();
        renderMonthView();
    }

    private List<String> visibleMonthNames() {
        ArrayList<String> months = new ArrayList<>();
        for (int i = 0; i < 12; i++) {
            months.add(monthNames[i]);
        }
        return months;
    }

    private List<String> yearOptions() {
        int currentYear = Calendar.getInstance().get(Calendar.YEAR);
        ArrayList<String> years = new ArrayList<>();
        for (int year = currentYear - 20; year <= currentYear + 20; year++) {
            years.add(String.valueOf(year));
        }
        return years;
    }

    private void selectYearSpinnerValue(int year) {
        for (int i = 0; i < yearSpinner.getCount(); i++) {
            if (String.valueOf(year).equals(yearSpinner.getItemAtPosition(i))) {
                yearSpinner.setSelection(i);
                return;
            }
        }
    }

    private Calendar firstDayOfMonth(Calendar source) {
        Calendar copy = (Calendar) source.clone();
        copy.set(Calendar.DAY_OF_MONTH, 1);
        copy.set(Calendar.HOUR_OF_DAY, 0);
        copy.set(Calendar.MINUTE, 0);
        copy.set(Calendar.SECOND, 0);
        copy.set(Calendar.MILLISECOND, 0);
        return copy;
    }

    private Calendar selectedDateCalendar() {
        Calendar selected = Calendar.getInstance();
        try {
            selected.setTime(isoDateFormat.parse(selectedDateIso));
        } catch (Exception ignored) {
        }
        return selected;
    }

    private TextView calendarLabel(String text) {
        TextView label = new TextView(this);
        label.setText(text);
        label.setTextColor(TEXT_MUTED);
        label.setTextSize(12);
        label.setTypeface(Typeface.DEFAULT_BOLD);
        label.setGravity(Gravity.CENTER);
        return label;
    }

    private TextView calendarDayCell() {
        TextView cell = new TextView(this);
        cell.setGravity(Gravity.CENTER);
        cell.setTextSize(12);
        cell.setPadding(dp(2), dp(2), dp(2), dp(2));
        return cell;
    }

    private GridLayout.LayoutParams gridParams(int height) {
        GridLayout.LayoutParams params = new GridLayout.LayoutParams();
        params.width = 0;
        params.height = height;
        params.columnSpec = GridLayout.spec(GridLayout.UNDEFINED, 1f);
        params.setMargins(dp(2), dp(2), dp(2), dp(2));
        return params;
    }

    private Button compactButton(String text) {
        Button button = new Button(this);
        button.setText(text);
        button.setTextSize(18);
        button.setMinWidth(dp(40));
        button.setMinimumWidth(dp(40));
        button.setPadding(0, 0, 0, 0);
        return button;
    }

    private GradientDrawable dayBackground(boolean selected, boolean today, int snackCount) {
        int fillColor = selected ? ORANGE : snackCount > 0 ? ORANGE_LIGHT : Color.WHITE;
        int strokeColor = today ? ORANGE_DARK : Color.TRANSPARENT;
        int strokeWidth = today ? dp(2) : 0;
        return roundRect(fillColor, dp(14), strokeColor, strokeWidth);
    }

    private GradientDrawable roundRect(int fillColor, int radius, int strokeColor, int strokeWidth) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(fillColor);
        drawable.setCornerRadius(radius);
        if (strokeWidth > 0) {
            drawable.setStroke(strokeWidth, strokeColor);
        }
        return drawable;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
