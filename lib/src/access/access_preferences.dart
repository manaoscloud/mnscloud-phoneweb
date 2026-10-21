import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Language of the access screen; null follows the device. Only this choice
/// and "continue without an account" are stored: never credentials or tokens.
final accessLocale = ValueNotifier<Locale?>(null);

const _languageKey = 'phoneweb.language';
const _skippedKey = 'phoneweb.accessSkipped';

Locale? parseAccessLocale(String? value) => switch (value) {
  'pt-BR' => const Locale('pt', 'BR'),
  'es-ES' => const Locale('es', 'ES'),
  'en-US' => const Locale('en', 'US'),
  _ => null,
};

Future<void> loadAccessLocale() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    accessLocale.value = parseAccessLocale(prefs.getString(_languageKey));
  } catch (_) {
    // The device language stays when storage is denied.
  }
}

Future<void> setAccessLocale(String value) async {
  accessLocale.value = parseAccessLocale(value);
  try {
    await (await SharedPreferences.getInstance()).setString(
      _languageKey,
      value,
    );
  } catch (_) {}
}

/// Whether the user chose to use PhoneWeb without a MNSCloud account.
Future<bool> readAccessSkipped() async {
  try {
    return (await SharedPreferences.getInstance()).getBool(_skippedKey) ??
        false;
  } catch (_) {
    return false;
  }
}

Future<void> writeAccessSkipped(bool value) async {
  try {
    await (await SharedPreferences.getInstance()).setBool(_skippedKey, value);
  } catch (_) {}
}
