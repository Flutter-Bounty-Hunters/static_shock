class PackageName {
  static bool isValid(String name) {
    // Package names should consist solely of lowercase letters and underscores.
    if (name.startsWith(RegExp(r'[^a-z]'))) {
      return false;
    }

    return !RegExp(r'[^a-z\d_]+').hasMatch(name);
  }

  static bool canFix(String badName) {
    return fix(badName).isNotEmpty;
  }

  static String fix(String badName) {
    String fixedName = badName //
        .toLowerCase()
        // Remove leading underscores, e.g., "_bad".
        .replaceFirst(RegExp(r'^_+'), "")
        // Remove all special characters.
        .replaceAll(RegExp(r'[^a-z\d_-]+'), "")
        // Replace dashes with underscores.
        .replaceAll("-", "_");

    final leadingNumberMatch = RegExp(r'^\d+').matchAsPrefix(badName);
    if (leadingNumberMatch != null) {
      fixedName = fixedName.substring(leadingNumberMatch.end);
    }

    return fixedName;
  }

  const PackageName._();
}
