import 'dart:convert';
import 'package:fimeride_front/formulario_pasajero.dart';
import 'package:fimeride_front/fimehub_home.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FimeHubLogin extends StatefulWidget {
  const FimeHubLogin({super.key});

  @override
  _FimeHubLoginState createState() => _FimeHubLoginState();
}

class _FimeHubLoginState extends State<FimeHubLogin> {
  final TextEditingController _matriculaController = TextEditingController();
  final TextEditingController _contraseniaController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _matriculaController.dispose();
    _contraseniaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    double imagePosition =
        isKeyboardVisible ? screenHeight / 10 : (screenHeight / 5) - (screenWidth / 2.6);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SingleChildScrollView(
          child: Container(
            width: screenWidth,
            height: screenHeight,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 0, 162, 100),
                  Color.fromARGB(255, 0, 87, 54),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Logo animado
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  top: imagePosition,
                  left: (screenWidth / 2) - (screenWidth / 2.6),
                  child: Image.asset(
                    'assets/image/Fimehub.png',
                    width: screenWidth / 1.3,
                    height: screenWidth / 1.3,
                  ),
                ),

                // Título
                Align(
                  alignment: const Alignment(0.0, -0.15),
                  child: Text(
                    'FIMEHUB',
                    style: TextStyle(
                      fontFamily: 'DirtyBrush',
                      color: Colors.white,
                      fontSize: screenWidth / 7,
                    ),
                  ),
                ),

                // Campo matrícula
                Align(
                  alignment: const Alignment(0.0, 0.12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'MATRICULA',
                        style: TextStyle(
                          fontFamily: 'ADLaMDisplay',
                          color: Colors.white,
                          fontSize: screenWidth / 18,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: TextField(
                          controller: _matriculaController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Campo contraseña
                Align(
                  alignment: const Alignment(0.0, 0.46),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'CONTRASEÑA',
                        style: TextStyle(
                          fontFamily: 'ADLaMDisplay',
                          color: Colors.white,
                          fontSize: screenWidth / 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: TextField(
                          controller: _contraseniaController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10.0, horizontal: 15.0),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.black54,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Align(
                  alignment: const Alignment(0.0, 0.62),
                  child: SizedBox(
                    width: screenWidth * 0.9,
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: 'OLVIDE LA CONTRASEÑA',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'ADLaMDisplay',
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _showInfoDialog('Agregar una apertura de vista de formulario'),
                      ),
                    ),
                  ),
                ),

                // Botones iniciar sesión y registrarse
                Positioned(
                  bottom: screenHeight / 8 - 55,
                  left: (screenWidth / 3) - 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 1, 91, 57),
                          foregroundColor: Colors.purple,
                          overlayColor: Colors.white.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(
                            color: Colors.white,
                            width: screenWidth * .008,
                          ),
                        ),
                        icon: const Icon(Icons.login, color: Colors.white),
                        label: Text(
                          'Iniciar Sesión',
                          style: TextStyle(
                            fontSize: screenWidth / 25,
                            fontFamily: 'ADLaMDisplay',
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const FormularioPasajero()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 1, 91, 57),
                          foregroundColor: Colors.purple,
                          overlayColor: Colors.white.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(
                            color: Colors.white,
                            width: screenWidth * .008,
                          ),
                        ),
                        icon: const Icon(Icons.app_registration, color: Colors.white),
                        label: Text(
                          'Registrarse',
                          style: TextStyle(
                            fontSize: screenWidth / 25,
                            fontFamily: 'ADLaMDisplay',
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final matricula = _matriculaController.text.trim();
    final contrasenia = _contraseniaController.text;
    if (matricula.isEmpty || contrasenia.isEmpty) {
      _showDialog('Error', 'Por favor, completa todos los campos');
    } else {
      _iniciarSesion(matricula, contrasenia);
    }
  }

  Future<void> _iniciarSesion(String matricula, String password) async {
    final url = Uri.parse('https://fimeride.onrender.com/api/login/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': matricula, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final usuarioId = data['usuario_id'];

        if (usuarioId == null) {
          _showDialog('Error', 'No se pudo obtener el ID del usuario');
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('usuario_id', usuarioId);
        await prefs.setString('matricula', matricula);
        if (data['conductor_id'] != null) {
          await prefs.setInt('conductor_id', data['conductor_id']);
        }
        if (data['pasajero_id'] != null) {
          await prefs.setInt('pasajero_id', data['pasajero_id']);
        }
        if (data['nombre'] != null) {
          await prefs.setString('nombre', data['nombre']);
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FimeHubHome()),
        );
      } else if (response.statusCode == 403) {
        _showDialog('Error',
            'No se le ha aprobado la solicitud. Revise su correo universitario.');
      } else if (response.statusCode == 401) {
        _showDialog('Error', 'Credenciales incorrectas');
      } else {
        _showDialog('Error', 'Error inesperado: ${response.statusCode}');
      }
    } catch (_) {
      _showDialog('Error de conexión', 'Verifica tu internet');
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Información'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
