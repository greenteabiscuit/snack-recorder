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

    SnackRecord(String name, String maker) {
        this.name = name == null ? "" : name;
        this.maker = maker == null ? "" : maker;
    }

    String getName() {
        return name;
    }

    String getMaker() {
        return maker;
    }

    String displayText() {
        if (maker == null || maker.trim().isEmpty()) {
            return name;
        }
        return name + " — " + maker;
    }
}
