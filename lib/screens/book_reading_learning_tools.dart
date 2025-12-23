// Learning tools logic for BookReadingScreen
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Learning tools logic for BookReadingScreen
mixin BookReadingLearningToolsMixin<T extends StatefulWidget> on State<T> {
  // Abstract getters/setters for mode variables
  bool get phonicsMode;
  set phonicsMode(bool value);
  bool get ipaMode;
  set ipaMode(bool value);
  bool get syllableMode;
  set syllableMode(bool value);
  bool get comprehensionMode;
  set comprehensionMode(bool value);

  void togglePhonicsMode() {
    setState(() {
      phonicsMode = !phonicsMode;
      if (phonicsMode) {
        ipaMode = false;
        syllableMode = false;
        comprehensionMode = false;
      }
    });
    HapticFeedback.lightImpact();
  }

  void toggleIpaMode() {
    setState(() {
      ipaMode = !ipaMode;
      if (ipaMode) {
        phonicsMode = false;
        syllableMode = false;
        comprehensionMode = false;
      }
    });
    HapticFeedback.lightImpact();
  }

  void toggleSyllableMode() {
    setState(() {
      syllableMode = !syllableMode;
      if (syllableMode) {
        phonicsMode = false;
        ipaMode = false;
        comprehensionMode = false;
      }
    });
    HapticFeedback.lightImpact();
  }

  void toggleComprehensionMode() {
    setState(() {
      comprehensionMode = !comprehensionMode;
      if (comprehensionMode) {
        phonicsMode = false;
        ipaMode = false;
        syllableMode = false;
      }
    });
    HapticFeedback.lightImpact();
  }
}
