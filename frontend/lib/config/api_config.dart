class ApiConfig {
  static const String baseUrl = 'http://localhost:3000/api';
  
  // Endpoints
  static const String partNumbers = '$baseUrl/part-numbers';
  static const String esdBoxes = '$baseUrl/esd-boxes';
  static const String operators = '$baseUrl/operators';
  static const String exitRecords = '$baseUrl/exit-records';
  static const String boxScans = '$baseUrl/box-scans';
  static const String oqcRejections = '$baseUrl/oqc-rejections';
  static const String health = '$baseUrl/health';
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
