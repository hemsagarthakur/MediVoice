class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.demoMode});

  factory AppConfig.fromEnvironment() {
    const value = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000',
    );
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw StateError('API_BASE_URL must be an absolute URL.');
    }
    const demoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);
    return const AppConfig(apiBaseUrl: value, demoMode: demoMode);
  }

  final String apiBaseUrl;
  final bool demoMode;
}
