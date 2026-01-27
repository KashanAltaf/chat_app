/// Application asset paths
/// Centralized asset path definitions for easy access and refactoring
class AppAssets {
  // Image paths
  static const String imagesPath = 'assets/images';
  static const String iconsPath = 'assets/icons';
  static const String fontsPath = 'assets/fonts';

  // Images

  // Icons
  static const String iconGoogle = '$iconsPath/googleIcon.png';
  static const String iconHomeSelected = '$iconsPath/nav-home-selected.png';
  static const String iconHomeUnselected = '$iconsPath/nav-home-unselected.png';
  static const String iconSettingsSelected = '$iconsPath/settingSelectedIcon.png';
  static const String iconSettingsUnselected = '$iconsPath/settingUnselectedIcon.png';
  static const String iconSearchSelected = '$iconsPath/nav-search-selected.png';
  static const String iconSearchUnselected = '$iconsPath/nav-search-unselected.png';

  // // Fonts
  // static const String fontFamilyPrimary = 'Circular';
  // static const String fontFamilySecondary = 'Gotham';

  // Private constructor to prevent instantiation
  AppAssets._();
}

/// Asset helper extensions
extension AssetHelper on String {
  /// Get image asset path
  String get image => this;

  /// Get icon asset path
  String get icon => this;

  /// Get font asset path
  String get font => this;
}

