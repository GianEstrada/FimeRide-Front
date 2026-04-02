import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class terminos_condiciones extends StatefulWidget {
  const terminos_condiciones({super.key});

  @override
  _terminos_condicionesState createState() => _terminos_condicionesState();
}

class _terminos_condicionesState extends State<terminos_condiciones> {
  // Cambia esta URL por la real de tu PDF
  final String pdfUrl = 'https://github.com/GianEstrada/FimeRide-Front/blob/master/terminos_condiciones.pdf';
  bool _isLoading = true;
  String? _errorMessage;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _downloadPDF();
  }

  Future<void> _downloadPDF() async {
    try {
      final response = await http.get(Uri.parse(pdfUrl));
      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/terminos_condiciones.pdf');
        await file.writeAsBytes(response.bodyBytes);
        if (mounted) {
          setState(() {
            _localPath = file.path;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Error al descargar PDF');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No se pudo cargar el documento.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos y Condiciones'),
        backgroundColor: const Color.fromARGB(255, 0, 87, 54),
      ),
      body: Stack(
        children: [
          if (_localPath != null)
            PDFView(
              filePath: _localPath,
              enableSwipe: true,
              swipeHorizontal: true,
            ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
          if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                        _downloadPDF();
                      });
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}