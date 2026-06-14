package com.example.snackrecorder;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

final class SnackDay {
    private final String dateIso;
    private final ArrayList<SnackRecord> snacks;

    SnackDay(String dateIso, List<SnackRecord> snacks) {
        this.dateIso = dateIso;
        this.snacks = new ArrayList<>(snacks);
    }

    String getDateIso() {
        return dateIso;
    }

    List<SnackRecord> getSnacks() {
        return Collections.unmodifiableList(snacks);
    }

    int getSnackCount() {
        return snacks.size();
    }
}

final class SnackRecord {
    private final String name;
    private final String maker;
    private final ArrayList<String> otherSnacks;

    SnackRecord(String name, String maker, List<String> otherSnacks) {
        this.name = name == null ? "" : name;
        this.maker = maker == null ? "" : maker;
        this.otherSnacks = new ArrayList<>();
        if (otherSnacks != null) {
            this.otherSnacks.addAll(otherSnacks);
        }
    }

    String getName() {
        return name;
    }

    String getMaker() {
        return maker;
    }

    List<String> getOtherSnacks() {
        return Collections.unmodifiableList(otherSnacks);
    }

    String displayText() {
        StringBuilder text = new StringBuilder();
        if (maker == null || maker.trim().isEmpty()) {
            text.append(name);
        } else {
            text.append(name).append(" — ").append(maker);
        }
        if (!otherSnacks.isEmpty()) {
            text.append("\nOther: ");
            for (int i = 0; i < otherSnacks.size(); i++) {
                if (i > 0) {
                    text.append("; ");
                }
                text.append(otherSnacks.get(i));
            }
        }
        return text.toString();
    }
}
