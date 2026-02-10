import 'dart:convert';
import 'package:fimeride_front/formulario_pasajero.dart';
import 'package:fimeride_front/pagina_principal.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  _PantallaInicioState createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  final TextEditingController matriculaController = TextEditingController();
  final TextEditingController contraseniaController = TextEditingController();
  FocusNode focusMatricula = FocusNode();
  FocusNode focusContrasenia = FocusNode();

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double screenWidth = MediaQuery.of(context).size.width;

    bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    double imagePosition = isKeyboardVisible ? screenHeight / 10 : (screenHeight / 5) - (screenWidth / 2.6);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: SingleChildScrollView(
          child: Container(
            width: screenWidth,
            height: screenHeight,
            decoration: BoxDecoration(
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
                AnimatedPositioned(
                  duration: Duration(milliseconds: 300),
                  top: imagePosition,
                  left: (screenWidth / 2) - (screenWidth / 2.6),
                  child: Image.asset(
                    'assets/image/FimeRideLogo.png',
                    width: screenWidth / 1.3,
                    height: screenWidth / 1.3,
                  ),
                ),
                Align(
                  alignment: Alignment(0.0, -0.15),
                  child: Text(
                    "Vive La Fime",
                    style: TextStyle(
                      fontFamily: 'DirtyBrush',
                      color: Colors.white,
                      fontSize: screenWidth / 7,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment(0.0, 0.12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "MATRICULA",
                        style: TextStyle(
                          fontFamily: 'ADLaMDisplay',
                          color: Colors.white,
                          fontSize: screenWidth / 18,
                        ),
                      ),
                      SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: TextField(
                          controller: matriculaController,
                          focusNode: focusMatricula,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment(0.0, 0.46),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "CONTRASEÑA",
                        style: TextStyle(
                          fontFamily: 'ADLaMDisplay',
                          color: Colors.white,
                          fontSize: screenWidth / 18,
                        ),
                      ),
                      SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30.0),
                        child: TextField(
                          controller: contraseniaController,
                          focusNode: focusContrasenia,
                          obscureText: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment(0.0, 0.6),
                  child: SizedBox(
                    width: screenWidth * 0.9,
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: "Olvide la contraseña",
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: "ADLaMDisplay",
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _showInfoDialog("Agregar una apertura de vista de formulario"),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: screenHeight / 8 - 60,
                  left: (screenWidth / 3) - 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          String matricula = matriculaController.text;
                          String contrasenia = contraseniaController.text;

                          if (matricula.isEmpty || contrasenia.isEmpty) {
                            _showDialog("Error", "Por favor, completa todos los campos", false);
                          } else {
                            iniciarSesion(matricula, contrasenia);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 1, 91, 57),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(
                            color: Colors.white,
                            width: screenWidth * .008,
                          ),
                        ),
                        child: Text(
                          "Iniciar Sesion",
                          style: TextStyle(
                            fontSize: screenWidth / 25,
                            fontFamily: 'ADLaMDisplay',
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => FormularioPasajero()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color.fromARGB(255, 1, 91, 57),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(
                            color: Colors.white,
                            width: screenWidth * .008,
                          ),
                        ),
                        child: Text(
                          "Registrarse",
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

Future<void> iniciarSesion(String matricula, String password) async {
  final url = Uri.parse("https://fimeride.onrender.com/api/login/");
  final response = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"username": matricula, "password": password}),
  );

  if (response.statusCode == 200) {
    final responseData = jsonDecode(response.body);
    final usuarioId = responseData['usuario_id'];
    final conductorId = responseData['conductor_id'];
    final pasajeroId = responseData['pasajero_id'];
    final nombre = responseData['nombre'];

    // Verifica que usuario_id no sea null
    if (usuarioId == null) {
      _showDialog("Error", "No se pudo obtener el ID del usuario", false);
      return;
    }

    // Guarda los IDs en SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('usuario_id', usuarioId);

    // Guarda conductor_id si no es null
    if (conductorId != null) {
      await prefs.setInt('conductor_id', conductorId);
    }

    // Guarda pasajero_id si no es null
    if (pasajeroId != null) {
      await prefs.setInt('pasajero_id', pasajeroId);
    }

    if (nombre != null) {
      await prefs.setString('nombre', nombre); // Guarda el nombre como String
      print("Nombre guardado en SharedPreferences: $nombre");
    }

    _showDialog("Éxito", "Inicio de sesión exitoso", true);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PaginaPrincipal()),
    );
  } else if (response.statusCode == 403) {
    _showDialog(
      "Error",
      "No se le ha aprobado la solicitud. Si ya envió su solicitud, favor de estar atento al correo universitario para información de la aprobación.",
      false,
    );
  } else if (response.statusCode == 401) {
    _showDialog("Error", "Credenciales incorrectas", false);
  } else {
    _showDialog("Error", "Error inesperado: ${response.statusCode}", false);
  }
}

void _showDialog(String title, String message, bool isSuccess) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("Cerrar"),
          ),
        ],
      );
    },
  );
}

  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Información"),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cerrar"),
            ),
          ],
        );
      },
    );
  }
}