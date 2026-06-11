package com.example.snackrecorder;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

final class SnackDay {
    private final String dateIso;
    private final ArrayList<String> snacks;

    SnackDay(String dateIso, List<String> snacks) {
        this.dateIso = dateIso;
        this.snacks = new ArrayList<>(snacks);
    }

    String getDateIso() {
        return dateIso;
    }

    List<String> getSnacks() {
        return Collections.unmodifiableList(snacks);
    }

    int getSnackCount() {
        return snacks.size();
    }
}
