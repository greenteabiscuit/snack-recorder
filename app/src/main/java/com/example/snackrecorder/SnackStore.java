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

    List<SnackDay> getDaysInMonth(int year, int monthZeroBased) {
        String monthPrefix = String.format(Locale.US, "%04d-%02d-", year, monthZeroBased + 1);
        ArrayList<SnackDay> monthDays = new ArrayList<>();
        TreeMap<String, ArrayList<String>> sortedDays = new TreeMap<>(loadDays());
        for (Map.Entry<String, ArrayList<String>> entry : sortedDays.entrySet()) {
            if (entry.getKey().startsWith(monthPrefix)) {
                monthDays.add(new SnackDay(entry.getKey(), entry.getValue()));
            }
        }
        return monthDays;
    }

    void addSnack(String dateIso, String snack) {
        Map<String, ArrayList<String>> days = loadDays();
        ArrayList<String> snacks = days.get(dateIso);
        if (snacks == null) {
            snacks = new ArrayList<>();
            days.put(dateIso, snacks);
        }
        snacks.add(snack);
        saveDays(days);
    }

    void removeSnack(String dateIso, int snackIndex) {
        Map<String, ArrayList<String>> days = loadDays();
        ArrayList<String> snacks = days.get(dateIso);
        if (snacks == null || snackIndex < 0 || snackIndex >= snacks.size()) {
            return;
        }

        snacks.remove(snackIndex);
        if (snacks.isEmpty()) {
            days.remove(dateIso);
        }
        saveDays(days);
    }

    String exportCsv() {
        StringBuilder csv = new StringBuilder("date,snack\n");
        TreeMap<String, ArrayList<String>> sortedDays = new TreeMap<>(loadDays());
        for (Map.Entry<String, ArrayList<String>> entry : sortedDays.entrySet()) {
            for (String snack : entry.getValue()) {
                appendCsvField(csv, entry.getKey());
                csv.append(',');
                appendCsvField(csv, snack);
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

    private Map<String, ArrayList<String>> loadDays() {
        HashMap<String, ArrayList<String>> days = new HashMap<>();
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
                ArrayList<String> snacks = new ArrayList<>();
                for (int j = 0; j < snackArray.length(); j++) {
                    snacks.add(snackArray.getString(j));
                }
                days.put(dateIso, snacks);
            }
        } catch (JSONException ignored) {
            preferences.edit().remove(DAYS_KEY).apply();
        }
        return days;
    }

    private void saveDays(Map<String, ArrayList<String>> days) {
        JSONObject root = new JSONObject();
        try {
            for (Map.Entry<String, ArrayList<String>> entry : days.entrySet()) {
                JSONArray snacks = new JSONArray();
                for (String snack : entry.getValue()) {
                    snacks.put(snack);
                }
                root.put(entry.getKey(), snacks);
            }
        } catch (JSONException ignored) {
            return;
        }

        preferences.edit().putString(DAYS_KEY, root.toString()).apply();
    }
}
