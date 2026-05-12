enum AppDesignMode {
  modern,
  classic;

  String get label {
    switch (this) {
      case AppDesignMode.modern:
        return 'Moderno';
      case AppDesignMode.classic:
        return 'Clássico';
    }
  }

  String get preferenceValue {
    switch (this) {
      case AppDesignMode.modern:
        return 'modern';
      case AppDesignMode.classic:
        return 'classic';
    }
  }
}

AppDesignMode appDesignModeFromPreference(String? value) {
  switch (value) {
    case 'classic':
      return AppDesignMode.classic;
    case 'modern':
    default:
      return AppDesignMode.modern;
  }
}
