package com.example.snackrecorder;

import android.content.Context;
import android.content.SharedPreferences;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Locale;
import java.util.TreeMap;

final class SnackStore {
    private static final String PREFS_NAME = "snack_recorder";
    private static final String DAYS_KEY = "days";

    private final SharedPreferences preferences;

    SnackStore(Context context) {
        preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    SnackDay getDay(String dateIso) {
        return new SnackDay(dateIso, loadDays().getOrDefault(dateIso, new ArrayList<>()));
    }

    int getSnackCount(String dateIso) {
        return getDay(dateIso).getSnackCount();
    }

    List<String> getSnackNames() {
        HashMap<String, Integer> snackCounts = new HashMap<>();
        HashMap<String, String> displayNames = new HashMap<>();
        TreeMap<String, ArrayList<SnackRecord>> sortedDays = new TreeMap<>(loadDays());
        for (ArrayList<SnackRecord> snacks : sortedDays.values()) {
            for (SnackRecord snack : snacks) {
                countSuggestion(snackCounts, displayNames, snack.getName());
                countSuggestion(snackCounts, displayNames, snack.getMaker());
            }
        }

        ArrayList<String> snackNames = new ArrayList<>(displayNames.values());
        snackNames.sort((left, right) -> {
            String normalizedLeft = left.toLowerCase(Locale.US);
            String normalizedRight = right.toLowerCase(Locale.US);
            int countComparison = Integer.compare(
                    snackCounts.getOrDefault(normalizedRight, 0),
                    snackCounts.getOrDefault(normalizedLeft, 0)
            );
            if (countComparison != 0) {
                return countComparison;
            }

            int nameComparison = left.compareToIgnoreCase(right);
            if (nameComparison != 0) {
                return nameComparison;
            }
            return left.compareTo(right);
        });
        return snackNames;
    }

    private void countSuggestion(HashMap<String, Integer> snackCounts, HashMap<String, String> displayNames, String value) {
        String suggestion = value == null ? "" : value.trim();
        if (suggestion.isEmpty()) {
            return;
        }

        String normalizedSuggestion = suggestion.toLowerCase(Locale.US);
        snackCounts.put(normalizedSuggestion, snackCounts.getOrDefault(normalizedSuggestion, 0) + 1);
        displayNames.putIfAbsent(normalizedSuggestion, suggestion);
    }

    List<SnackDay> getDaysInMonth(int year, int monthZeroBased) {
        String monthPrefix = String.format(Locale.US, "%04d-%02d-", year, monthZeroBased + 1);
        ArrayList<SnackDay> monthDays = new ArrayList<>();
        TreeMap<String, ArrayList<SnackRecord>> sortedDays = new TreeMap<>(loadDays());
        for (Map.Entry<String, ArrayList<SnackRecord>> entry : sortedDays.entrySet()) {
            if (entry.getKey().startsWith(monthPrefix)) {
                monthDays.add(new SnackDay(entry.getKey(), entry.getValue()));
            }
        }
        return monthDays;
    }

    List<SnackDay> getAllDays() {
        ArrayList<SnackDay> days = new ArrayList<>();
        TreeMap<String, ArrayList<SnackRecord>> sortedDays = new TreeMap<>(loadDays());
        for (Map.Entry<String, ArrayList<SnackRecord>> entry : sortedDays.entrySet()) {
            days.add(new SnackDay(entry.getKey(), entry.getValue()));
        }
        return days;
    }

    void addSnack(String dateIso, String snack, String maker) {
        Map<String, ArrayList<SnackRecord>> days = loadDays();
        ArrayList<SnackRecord> snacks = days.get(dateIso);
        if (snacks == null) {
            snacks = new ArrayList<>();
            days.put(dateIso, snacks);
        }
        snacks.add(new SnackRecord(snack, maker));
        saveDays(days);
    }

    void removeSnack(String dateIso, int snackIndex) {
        Map<String, ArrayList<SnackRecord>> days = loadDays();
        ArrayList<SnackRecord> snacks = days.get(dateIso);
        if (snacks == null || snackIndex < 0 || snackIndex >= snacks.size()) {
            return;
        }

        snacks.remove(snackIndex);
        if (snacks.isEmpty()) {
            days.remove(dateIso);
        }
        saveDays(days);
    }

    void updateSnack(String dateIso, int snackIndex, String snack, String maker) {
        Map<String, ArrayList<SnackRecord>> days = loadDays();
        ArrayList<SnackRecord> snacks = days.get(dateIso);
        if (snacks == null || snackIndex < 0 || snackIndex >= snacks.size()) {
            return;
        }

        snacks.set(snackIndex, new SnackRecord(snack, maker));
        saveDays(days);
    }

    String exportCsv() {
        StringBuilder csv = new StringBuilder("date,snack,maker\n");
        TreeMap<String, ArrayList<SnackRecord>> sortedDays = new TreeMap<>(loadDays());
        for (Map.Entry<String, ArrayList<SnackRecord>> entry : sortedDays.entrySet()) {
            for (SnackRecord snack : entry.getValue()) {
                appendCsvField(csv, entry.getKey());
                csv.append(',');
                appendCsvField(csv, snack.getName());
                csv.append(',');
                appendCsvField(csv, snack.getMaker());
                csv.append('\n');
            }
        }
        return csv.toString();
    }

    private void appendCsvField(StringBuilder csv, String value) {
        boolean needsQuotes = value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r");
        if (!needsQuotes) {
            csv.append(value);
            return;
        }

        csv.append('"');
        for (int i = 0; i < value.length(); i++) {
            char character = value.charAt(i);
            if (character == '"') {
                csv.append("\"\"");
            } else {
                csv.append(character);
            }
        }
        csv.append('"');
    }

    private Map<String, ArrayList<SnackRecord>> loadDays() {
        HashMap<String, ArrayList<SnackRecord>> days = new HashMap<>();
        String rawJson = preferences.getString(DAYS_KEY, "{}");
        try {
            JSONObject root = new JSONObject(rawJson);
            JSONArray names = root.names();
            if (names == null) {
                return days;
            }

            for (int i = 0; i < names.length(); i++) {
                String dateIso = names.getString(i);
                JSONArray snackArray = root.getJSONArray(dateIso);
                ArrayList<SnackRecord> snacks = new ArrayList<>();
                for (int j = 0; j < snackArray.length(); j++) {
                    Object snackValue = snackArray.get(j);
                    if (snackValue instanceof JSONObject) {
                        JSONObject snackObject = (JSONObject) snackValue;
                        snacks.add(new SnackRecord(
                                snackObject.optString("name", ""),
                                snackObject.optString("maker", "")
                        ));
                    } else {
                        snacks.add(new SnackRecord(String.valueOf(snackValue), ""));
                    }
                }
                days.put(dateIso, snacks);
            }
        } catch (JSONException ignored) {
            preferences.edit().remove(DAYS_KEY).apply();
        }
        return days;
    }

    private void saveDays(Map<String, ArrayList<SnackRecord>> days) {
        JSONObject root = new JSONObject();
        try {
            for (Map.Entry<String, ArrayList<SnackRecord>> entry : days.entrySet()) {
                JSONArray snacks = new JSONArray();
                for (SnackRecord snack : entry.getValue()) {
                    JSONObject snackObject = new JSONObject();
                    snackObject.put("name", snack.getName());
                    snackObject.put("maker", snack.getMaker());
                    snacks.put(snackObject);
                }
                root.put(entry.getKey(), snacks);
            }
        } catch (JSONException ignored) {
            return;
        }

        preferences.edit().putString(DAYS_KEY, root.toString()).apply();
    }
}
