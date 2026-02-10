import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String?> fetchMapboxToken() async {
  final url = Uri.parse("https://fimeride.onrender.com/api/mapbox-token/");
  print("URL: $url");
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("Token de Mapbox: ${data['token']}");
      return data['token'];
      
    } else {
      print("Error al obtener el token: ${response.statusCode}");
      return null;
    }
  } catch (e) {
    print("Error al conectar con el backend: $e");
    return null;
  }
}