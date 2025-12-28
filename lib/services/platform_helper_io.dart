import 'dart:io';

bool isDesktopPlatform() {
  return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
}

bool isWindows() {
  return Platform.isWindows;
}

bool isAndroid() {
  return Platform.isAndroid;
}

String getOperatingSystem() {
  return Platform.operatingSystem;
}
