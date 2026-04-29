import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Провайдер, хранящий текущий Locale приложения.
/// По умолчанию открываемся на таджикском.
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => const Locale('tg');

  void set(Locale value) {
    state = value;
  }
}
