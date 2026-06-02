class InstalledExternalApp {
  final String packageName;
  final String appName;
  final String? iconPath;

  const InstalledExternalApp({
    required this.packageName,
    required this.appName,
    this.iconPath,
  });
}
