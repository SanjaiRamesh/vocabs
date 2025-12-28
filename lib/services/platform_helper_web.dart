bool isDesktopPlatform() {
  return false; // Web is never a desktop platform in this context
}

bool isWindows() {
  return false;
}

bool isAndroid() {
  return false;
}

String getOperatingSystem() {
  return 'web';
}
