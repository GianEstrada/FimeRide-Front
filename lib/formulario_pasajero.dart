import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fimeride_front/formulario_conductores.dart';
import 'package:fimeride_front/login.dart';

class FormularioPasajero extends StatefulWidget {
  const FormularioPasajero({super.key});

  @override
  _FormularioPasajeroState createState() => _FormularioPasajeroState();
}

class _FormularioPasajeroState extends State<FormularioPasajero> {
  bool _solicitarConductor = false;
  File? _profileImage;
  File? _frontCredentialImage;
  File? _backCredentialImage;
  File? _boletaRectoria;
  String _boletaFileName = "Seleccionar boleta de rectoría";

  final TextEditingController _matriculaController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nombreCompletoController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();

  Future<void> _handleImageSelection(Function(File) onImageSelected) async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text("Tomar foto"),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await picker.pickImage(source: ImageSource.camera);
                if (pickedFile != null) {
                  setState(() {
                    onImageSelected(File(pickedFile.path));
                  });
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text("Seleccionar de la galería"),
              onTap: () async {
                Navigator.pop(context);
                final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                if (pickedFile != null) {
                  setState(() {
                    onImageSelected(File(pickedFile.path));
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectPdf() async {
    try {
      final XTypeGroup typeGroup = XTypeGroup(
        label: 'PDF',
        extensions: ['pdf'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file != null) {
        setState(() {
          _boletaRectoria = File(file.path);
          _boletaFileName = file.name;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se seleccionó ningún archivo")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al seleccionar el archivo: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _handleImageSelection((image) => _profileImage = image),
                  child: Container(
                    width: screenWidth / 2.3,
                    height: screenWidth / 2.3,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      image: _profileImage != null
                          ? DecorationImage(
                              image: FileImage(_profileImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _profileImage == null
                        ? Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(
                              child: Text(
                                "Selecciona tu foto de perfil \n (Tu cara debe de estar completamente visible)",
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                SizedBox(height: 10),
                _buildInputSection("MATRICULA", _matriculaController, false),
                SizedBox(height: 15),
                _buildInputSection("CONTRASEÑA", _passwordController, true),
                SizedBox(height: 15),
                _buildInputSection("CONFIRME CONTRASEÑA", _confirmPasswordController, true),
                SizedBox(height: 15),
                _buildInputSection("NOMBRE COMPLETO", _nombreCompletoController, false),
                SizedBox(height: 15),
                _buildInputSection("CORREO UNIVERSITARIO", _correoController, false),
                SizedBox(height: 15),
                GestureDetector(
                  onTap: () {},
                  child: Column(
                    children: [
                      Text(
                        "CREDENCIAL UNIVERSITARIA",
                        style: TextStyle(
                          fontFamily: 'ADLaMDisplay',
                          color: Colors.white,
                          fontSize: screenWidth / 18,
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildImagePicker("Foto frontal\n de la credencial", _frontCredentialImage,
                              (image) {
                            setState(() {
                              _frontCredentialImage = image;
                            });
                          }),
                          SizedBox(width: 10),
                          _buildImagePicker("Foto trasera\n de la credencial", _backCredentialImage,
                              (image) {
                            setState(() {
                              _backCredentialImage = image;
                            });
                          }),
                        ],
                      ),
                      SizedBox(height: 15),
                      Text(
                        "BOLETA DE RECTORÍA",
                        style: TextStyle(
                          fontFamily: 'ADLaMDisplay',
                          color: Colors.white,
                          fontSize: screenWidth / 18,
                        ),
                      ),
                      SizedBox(height: 10),
                      _buildPdfPicker(_boletaFileName, _boletaRectoria, _selectPdf),
                    ],
                  ),
                ),
                SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _solicitarConductor,
                        onChanged: (bool? value) {
                          setState(() {
                            _solicitarConductor = value ?? false;
                          });
                        },
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Quiero ser conductor",
                        style: TextStyle(
                          fontFamily: 'ADLaMDisplay',
                          color: Colors.white,
                          fontSize: screenWidth / 25,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text("Confirmación"),
                          content: Text(
                            "Al hacer click en continuar automáticamente aceptas los Términos y Condiciones de la aplicación.\n\n"
                            "También das fe de que todos los datos y documentos enviados son totalmente reales y propios.\n\n"
                            "¿Desea continuar?",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text("Cancelar"),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _registrarUsuario();
                              },
                              child: Text("Continuar"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Text("Continuar"),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection(String label, TextEditingController controller, bool obscureText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'ADLaMDisplay',
            color: Colors.white,
            fontSize: MediaQuery.of(context).size.width / 18,
          ),
        ),
        SizedBox(height: 5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker(String label, File? imageFile, Function(File) onImageSelected) {
    return GestureDetector(
      onTap: () => _handleImageSelection(onImageSelected),
      child: Container(
        width: MediaQuery.of(context).size.width / 2.4,
        height: MediaQuery.of(context).size.width / 2.4,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(12),
          image: imageFile != null
              ? DecorationImage(
                  image: FileImage(imageFile),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: imageFile == null
            ? Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildPdfPicker(String label, File? pdfFile, Function() onPdfSelected) {
    return GestureDetector(
      onTap: onPdfSelected,
      child: Container(
        width: MediaQuery.of(context).size.width / 2.4,
        height: MediaQuery.of(context).size.width / 2.4,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Center(
            child: Text(
              pdfFile != null
                  ? label
                  : "Seleccionar boleta de rectoría\n(Archivo PDF)",
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _registrarUsuario() async {
  final url = Uri.parse('https://fimeride.onrender.com/api/registrar/');
  final request = http.MultipartRequest('POST', url);

  request.fields['nombre_completo'] = _nombreCompletoController.text;
  request.fields['correo_universitario'] = _correoController.text;
  request.fields['matricula'] = _matriculaController.text;
  request.fields['contraseña'] = _passwordController.text;
  request.fields['solicito_conductor'] = _solicitarConductor.toString();

  if (_profileImage != null) {
    request.files.add(await http.MultipartFile.fromPath('foto_perfil', _profileImage!.path));
  }
  if (_frontCredentialImage != null) {
    request.files.add(await http.MultipartFile.fromPath('credencial_frontal', _frontCredentialImage!.path));
  }
  if (_backCredentialImage != null) {
    request.files.add(await http.MultipartFile.fromPath('credencial_trasera', _backCredentialImage!.path));
  }
  if (_boletaRectoria != null) {
    request.files.add(await http.MultipartFile.fromPath('boleta_rectoria', _boletaRectoria!.path));
  }

  try {
    final response = await request.send();

    if (response.statusCode == 201) {
      final responseBody = await response.stream.bytesToString();
      final responseData = jsonDecode(responseBody);

      // Obtén el usuario_id de la respuesta
      final usuarioId = responseData['usuario_id'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Registro exitoso")),
      );

      // Si el usuario marcó el checkbox, pasa el usuario_id al segundo formulario
      if (_solicitarConductor) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FormularioConductores(usuarioId: usuarioId),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PantallaInicio()),
        );
      }
    } else {
      final responseBody = await response.stream.bytesToString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al registrar: $responseBody")),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error de red: $e")),
    );
  }
}
}