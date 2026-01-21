import 'package:chat_app/core/network/api_client.dart';

class LoginRepository {
  final ApiClient apiClient;

  LoginRepository({required this.apiClient});

  Future<dynamic> login(String email, String password) async {
    // Replace with your actual endpoint
    return await apiClient.post('/login', body: {
      'email': email,
      'password': password,
    });
  }
}