import 'dart:io';

/// Installed build: `android`, `ios`, `windows`, `macos` or `linux`.
String currentClientPlatform() => Platform.operatingSystem;
