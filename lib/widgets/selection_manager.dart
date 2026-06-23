import 'package:flutter/material.dart';

mixin SelectionManager<T extends StatefulWidget> on State<T> {
  final Set<String> selectedIds = {};
  bool isSelectionMode = false;

  void toggleSelection(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
        if (selectedIds.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedIds.add(id);
        isSelectionMode = true;
      }
    });
    onSelectionChanged();
  }

  void enterSelectionMode(String id) {
    if (!isSelectionMode) {
      setState(() {
        isSelectionMode = true;
        selectedIds.add(id);
      });
      onSelectionChanged();
    }
  }

  void exitSelectionMode() {
    setState(() {
      isSelectionMode = false;
      selectedIds.clear();
    });
    onSelectionChanged();
  }

  void onSelectionChanged();
}
