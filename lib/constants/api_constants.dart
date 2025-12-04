/// API Configuration Constants
class ApiConstants {
  // Base URL for all API endpoints
  // Socket.IO doesn't work with HTTPS in socket_io_client package
  // Using HTTP with domain (works through Nginx on port 80)
  static const String baseUrl = 'https://api.myserverdevops.com';
  // static const String baseUrl = 'http://192.168.1.14:3000';

  // TODO: Switch to HTTPS when socket_io_client fixes HTTPS support
  // static const String baseUrl = 'https://api.myserverdevops.com';

  // Private constructor to prevent instantiation
  ApiConstants._();
}
