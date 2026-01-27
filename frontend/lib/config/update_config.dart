/// Configuración para el sistema de auto-actualización via GitHub Releases
class UpdateConfig {
  /// Usuario/Organización de GitHub
  static const String githubUser = 'ChaiGmzR';

  /// Nombre del repositorio
  static const String repoName = 'RegistroSalidasOQC';

  /// Versión actual de la aplicación (debe coincidir con pubspec.yaml)
  static const String currentVersion = '1.0.1';

  /// URL de la API de GitHub para obtener el último release
  static String get latestReleaseUrl =>
      'https://api.github.com/repos/$githubUser/$repoName/releases/latest';

  /// URL base para descargas de releases
  static String get releasesUrl =>
      'https://github.com/$githubUser/$repoName/releases';

  /// Nombre del archivo ZIP esperado en el release (patrón)
  static const String assetFilePattern = '.zip';

  /// Verificar actualizaciones al iniciar la app
  static const bool checkOnStartup = true;

  /// Intervalo mínimo entre verificaciones (en horas)
  static const int checkIntervalHours = 24;
}
