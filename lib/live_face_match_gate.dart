import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;

class LiveFaceMatchGate extends StatefulWidget {
  final int usuarioId;

  const LiveFaceMatchGate({super.key, required this.usuarioId});

  @override
  State<LiveFaceMatchGate> createState() => _LiveFaceMatchGateState();
}

class _LiveFaceMatchGateState extends State<LiveFaceMatchGate> {
  CameraController? _cameraController;
  late final FaceDetector _faceDetector;

  Timer? _scanTimer;
  bool _initializing = true;
  bool _processingFrame = false;
  bool _submitting = false;
  bool _finished = false;

  int _attempts = 0;
  String _status = 'Inicializando camara...';

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        enableContours: false,
        enableLandmarks: false,
      ),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _status = 'No se detecto una camara disponible';
        });
        return;
      }

      CameraDescription selected = cameras.first;
      for (final cam in cameras) {
        if (cam.lensDirection == CameraLensDirection.front) {
          selected = cam;
          break;
        }
      }

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _initializing = false;
        _status = 'Buscando rostro...';
      });
      _startAutoScan();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _status = 'No se pudo inicializar la camara';
      });
    }
  }

  void _startAutoScan() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      _scanAndValidate();
    });
  }

  Future<void> _scanAndValidate() async {
    if (_finished || _initializing || _processingFrame || _submitting) return;
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    _processingFrame = true;
    File? frameFile;
    try {
      final frame = await controller.takePicture();
      frameFile = File(frame.path);

      final inputImage = InputImage.fromFilePath(frame.path);
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        if (mounted) {
          setState(() => _status = 'Colocate frente a la camara...');
        }
        return;
      }

      final bestFace = faces.reduce((a, b) {
        final areaA = a.boundingBox.width * a.boundingBox.height;
        final areaB = b.boundingBox.width * b.boundingBox.height;
        return areaA >= areaB ? a : b;
      });

      if (bestFace.boundingBox.width < 100 ||
          bestFace.boundingBox.height < 100) {
        if (mounted) {
          setState(() => _status = 'Acercate un poco para validar tu rostro');
        }
        return;
      }

      _submitting = true;
      if (mounted) {
        setState(() => _status = 'Rostro detectado. Validando identidad...');
      }

      final result = await _callLoginFaceMatch(frameFile);
      if (!mounted) return;

      if (result.ok) {
        _finished = true;
        _scanTimer?.cancel();
        setState(() => _status = 'Validacion facial aprobada');
        await Future.delayed(const Duration(milliseconds: 350));
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      _attempts += 1;
      setState(() {
        _status = '${result.message} Reintentando...';
      });
      await Future.delayed(const Duration(milliseconds: 1200));
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Error al capturar imagen. Reintentando...');
      }
    } finally {
      _processingFrame = false;
      _submitting = false;
      try {
        if (frameFile != null && await frameFile.exists()) {
          await frameFile.delete();
        }
      } catch (_) {}
    }
  }

  Future<_FaceLoginResult> _callLoginFaceMatch(File frameFile) async {
    final uri = Uri.parse(
      'https://fimeride.onrender.com/api/login_face_match/',
    );

    try {
      final request =
          http.MultipartRequest('POST', uri)
            ..fields['usuario_id'] = widget.usuarioId.toString()
            ..files.add(
              await http.MultipartFile.fromPath('imagen_viva', frameFile.path),
            );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      if (response.statusCode == 200 && data['ok'] == true) {
        return const _FaceLoginResult(ok: true, message: 'Validacion aprobada');
      }

      final backendError = data['error']?.toString();
      if (backendError != null && backendError.isNotEmpty) {
        return _FaceLoginResult(ok: false, message: backendError);
      }

      return _FaceLoginResult(
        ok: false,
        message: 'No se pudo validar identidad (${response.statusCode})',
      );
    } catch (_) {
      return const _FaceLoginResult(
        ok: false,
        message: 'Error de conexion al validar identidad',
      );
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _faceDetector.close();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    final canShowCamera =
        !_initializing && controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: const Color(0xFF031E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF005736),
        foregroundColor: Colors.white,
        title: const Text('Acceso seguro a FimeRide'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  color: Colors.black,
                  child:
                      canShowCamera
                          ? CameraPreview(controller)
                          : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Intentos: $_attempts',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed:
                  _finished
                      ? null
                      : () {
                        Navigator.of(context).pop(false);
                      },
              icon: const Icon(Icons.close),
              label: const Text('Cancelar acceso a FimeRide'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceLoginResult {
  final bool ok;
  final String message;

  const _FaceLoginResult({required this.ok, required this.message});
}
