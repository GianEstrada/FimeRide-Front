import 'dart:io';

import 'package:fimeride_front/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';

class FormularioConductores extends StatefulWidget {
  final int usuarioId;

  const FormularioConductores({required this.usuarioId, super.key});

  @override
  _FormularioConductoresState createState() => _FormularioConductoresState();
}

class _FormularioConductoresState extends State<FormularioConductores> {
  final TextEditingController _placasController = TextEditingController();
  final TextEditingController _modeloController = TextEditingController();
  File? _polizaSeguro;
  String _polizaFileName = "Seleccionar póliza de seguro";

  File? _frontLicenseImage;
  File? _backLicenseImage;
  File? _frontIdImage;
  File? _backIdImage;

  @override
  void dispose() {
    _placasController.dispose();
    _modeloController.dispose();
    super.dispose();
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
          _polizaSeguro = File(file.path);
          _polizaFileName = file.name;
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
                _buildInputSection("Número de placas", _placasController),
                SizedBox(height: 15),
                _buildInputSection("Marca, modelo y año", _modeloController),
                SizedBox(height: 15),
                Text(
                  "Licencia de conducir",
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
                    _buildImagePicker("Frontal", _frontLicenseImage, (image) {
                      setState(() {
                        _frontLicenseImage = image;
                      });
                    }),
                    SizedBox(width: 10),
                    _buildImagePicker("Trasera", _backLicenseImage, (image) {
                      setState(() {
                        _backLicenseImage = image;
                      });
                    }),
                  ],
                ),
                SizedBox(height: 15),
                Text(
                  "Identificación oficial",
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
                    _buildImagePicker("Frontal", _frontIdImage, (image) {
                      setState(() {
                        _frontIdImage = image;
                      });
                    }),
                    SizedBox(width: 10),
                    _buildImagePicker("Trasera", _backIdImage, (image) {
                      setState(() {
                        _backIdImage = image;
                      });
                    }),
                  ],
                ),
                SizedBox(height: 15),
                Text(
                  "Póliza de seguro",
                  style: TextStyle(
                    fontFamily: 'ADLaMDisplay',
                    color: Colors.white,
                    fontSize: screenWidth / 18,
                  ),
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: _selectPdf,
                  child: Container(
                    width: screenWidth / 2.4,
                    height: screenWidth / 2.4,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: Text(
                          _polizaFileName,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
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
                                _registrarConductor();
                              },
                              child: Text("Continuar"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Text("Registrar"),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection(String label, TextEditingController controller) {
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

  Future<void> _registrarConductor() async {
    final url = Uri.parse('https://fimeride.onrender.com/api/registrar_conductor/');
    final request = http.MultipartRequest('POST', url);

    // Agrega el usuario_id al request
    request.fields['usuario_id'] = widget.usuarioId.toString();
    request.fields['numero_placas'] = _placasController.text;
    request.fields['marca_modelo_año'] = _modeloController.text;

    if (_frontLicenseImage != null) {
      request.files.add(await http.MultipartFile.fromPath('licencia_frontal', _frontLicenseImage!.path));
    }
    if (_backLicenseImage != null) {
      request.files.add(await http.MultipartFile.fromPath('licencia_trasera', _backLicenseImage!.path));
    }
    if (_frontIdImage != null) {
      request.files.add(await http.MultipartFile.fromPath('identificacion_frontal', _frontIdImage!.path));
    }
    if (_backIdImage != null) {
      request.files.add(await http.MultipartFile.fromPath('identificacion_trasera', _backIdImage!.path));
    }
    if (_polizaSeguro != null) {
      request.files.add(await http.MultipartFile.fromPath('poliza_seguro', _polizaSeguro!.path));
    }

    

    try {
      final response = await request.send();

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Registro de conductor exitoso")),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PantallaInicio()),
        );
      } else {
        final responseBody = await response.stream.bytesToString();
        print("Error al registrar conductor: $responseBody");
        print("Datos enviados:");
print("usuario_id: ${widget.usuarioId}");
print("numero_placas: ${_placasController.text}");
print("marca_modelo_año: ${_modeloController.text}");
print("licencia_frontal: ${_frontLicenseImage?.path}");
print("licencia_trasera: ${_backLicenseImage?.path}");
print("identificacion_frontal: ${_frontIdImage?.path}");
print("identificacion_trasera: ${_backIdImage?.path}");
print("poliza_seguro: ${_polizaSeguro?.path}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al registrar conductor: $responseBody")),
          
          
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error de red: $e")),
      );
    }
  }
}