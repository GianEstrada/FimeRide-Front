import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class formulario_actualizar_datos extends StatefulWidget {
  const formulario_actualizar_datos({super.key});

  @override
  _formulario_actualizar_datosState createState() => _formulario_actualizar_datosState();
}

class _formulario_actualizar_datosState extends State<formulario_actualizar_datos> {
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool get _isFormValid =>
      _currentController.text.isNotEmpty &&
      _newController.text.isNotEmpty &&
      _confirmController.text.isNotEmpty &&
      _newController.text == _confirmController.text;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_newController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La nueva contraseña debe tener al menos 6 caracteres')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final prefs = await SharedPreferences.getInstance();
    final usuarioId = prefs.getInt('usuario_id');
    if (usuarioId == null) {
      if (mounted) Navigator.pop(context);
      _showError('Sesión no válida. Inicia sesión nuevamente.');
      return;
    }

    final url = Uri.parse('https://fimeride.onrender.com/api/cambiar-password/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': usuarioId,
          'current_password': _currentController.text,
          'new_password': _newController.text,
        }),
      );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        _showSuccess('Contraseña actualizada');
        if (mounted) Navigator.pop(context);
      } else if (response.statusCode == 401) {
        _showError('Contraseña actual incorrecta');
      } else {
        _showError('Error al cambiar contraseña');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showError('Error de red. Intenta más tarde.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
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
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                child: Column(
                  children: [
                    // Logo FimeHub
                    Padding(
                      padding: EdgeInsets.only(top: screenHeight * 0.05),
                      child: Image.asset(
                        'assets/image/Fimehub.png',
                        width: screenWidth * 0.35,
                        height: screenWidth * 0.35,
                      ),
                    ),
                    // Título principal
                    Text(
                      'Cambiar Contraseña',
                      style: TextStyle(
                        fontFamily: 'ADLaMDisplay',
                        color: Colors.white,
                        fontSize: screenWidth / 12,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.05),

                    // Campos del formulario
                    _buildPasswordField(
                      label: 'CONTRASEÑA ACTUAL',
                      controller: _currentController,
                      obscure: _obscureCurrent,
                      onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                    SizedBox(height: screenHeight * 0.03),

                    _buildPasswordField(
                      label: 'NUEVA CONTRASEÑA',
                      controller: _newController,
                      obscure: _obscureNew,
                      onToggle: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                    SizedBox(height: screenHeight * 0.03),

                    _buildPasswordField(
                      label: 'CONFIRMAR NUEVA CONTRASEÑA',
                      controller: _confirmController,
                      obscure: _obscureConfirm,
                      onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    SizedBox(height: screenHeight * 0.05),

                    // Botón actualizar
                    ElevatedButton.icon(
                      onPressed: _isFormValid ? _changePassword : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 1, 91, 57),
                        foregroundColor: Colors.white,
                        overlayColor: Colors.white.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        side: BorderSide(
                          color: Colors.white,
                          width: screenWidth * .008,
                        ),
                      ),
                      icon: const Icon(Icons.lock_outline, color: Colors.white),
                      label: Text(
                        'Actualizar',
                        style: TextStyle(
                          fontSize: screenWidth / 25,
                          fontFamily: 'ADLaMDisplay',
                          color: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.05),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'ADLaMDisplay',
            color: Colors.white,
            fontSize: screenWidth / 18,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (_isFormValid) _changePassword();
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: Colors.black54,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}