import 'package:flutter/foundation.dart';

class SettingsEvents {
  static final SettingsEvents _instance = SettingsEvents._internal();
  factory SettingsEvents() => _instance;
  SettingsEvents._internal();

  final ValueNotifier<int> version = ValueNotifier<int>(0);

  void notifyUpdated() {
    version.value = version.value + 1;
  }
}
