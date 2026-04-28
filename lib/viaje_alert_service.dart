import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

import 'local_notification_service.dart';

typedef ConductorPopupCallback = Future<void> Function(Map<String, dynamic> viajeData);
typedef ConductorPreinicioCallback = Future<void> Function(Map<String, dynamic> preinicioData);
typedef PasajeroPopupCallback = Future<void> Function(Map<String, dynamic> viajeData, {required bool esHoraSalida});
typedef PasajeroConfirmadoCallback = Future<void> Function(Map<String, dynamic> viajeData);

class ViajeAlertService {
  ViajeAlertService({
    required this.conductorId,
    required this.pasajeroId,
    required this.onConductorPopup,
    required this.onConductorPreinicio,
    required this.onPasajeroPopup,
    required this.onPasajeroConductorConfirmado,
  });

  final int? conductorId;
  final int? pasajeroId;
  final ConductorPopupCallback onConductorPopup;
  final ConductorPreinicioCallback onConductorPreinicio;
  final PasajeroPopupCallback onPasajeroPopup;
  final PasajeroConfirmadoCallback onPasajeroConductorConfirmado;

  Timer? _pollTimer;
  DateTime? _ultimaNotifConductor;
  final Set<int> _viajesConConfirmacionNotificada = <int>{};
  final Set<int> _viajes5MinNotificados = <int>{};
  final Set<int> _viajesHoraSalidaNotificados = <int>{};
  bool _popupConductorActivo = false;

  Future<void> start() async {
    await _poll();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await _poll();
    });
  }

  Future<void> forceRefresh() async {
    await _poll();
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _poll() async {
    if (conductorId != null) {
      await _pollConductor();
    }
    if (pasajeroId != null) {
      await _pollPasajero();
    }
  }

  Future<void> _pollConductor() async {
    final url = Uri.parse('https://fimeride.onrender.com/api/recordatorios/conductor/$conductorId/');
    final response = await http.get(url);
    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final showPopup = data['show_popup'] == true;
    final showNotification = data['show_notification'] == true;
    final viaje = data['viaje'] as Map<String, dynamic>?;
    final preinicio = data['preinicio'] as Map<String, dynamic>?;

    if (showPopup && viaje != null && !_popupConductorActivo) {
      _popupConductorActivo = true;
      await onConductorPopup(viaje);
      _popupConductorActivo = false;
    }

    final ahora = DateTime.now();
    if (showNotification && viaje != null) {
      final hanPasado3Min = _ultimaNotifConductor == null ||
          ahora.difference(_ultimaNotifConductor!).inMinutes >= 3;
      if (hanPasado3Min) {
        _ultimaNotifConductor = ahora;
        await LocalNotificationService.show(
          id: 1100 + (viaje['id'] as int? ?? 0),
          title: 'Tiene un viaje proximo',
          body: 'Por favor confirme o se cancelara automaticamente',
        );
      }
    }

    if (preinicio != null) {
      await onConductorPreinicio(preinicio);
    }
  }

  Future<void> _pollPasajero() async {
    final url = Uri.parse('https://fimeride.onrender.com/api/recordatorios/pasajero/$pasajeroId/');
    final response = await http.get(url);
    if (response.statusCode != 200) return;

    final data = jsonDecode(response.body) as List<dynamic>;
    for (final item in data) {
      final viaje = item as Map<String, dynamic>;
      final viajeId = viaje['viaje_id'] as int;
      final confirmado = viaje['confirmado_por_conductor'] == true;
      final mostrar5Min = viaje['mostrar_aviso_5_min'] == true;
      final mostrarHora = viaje['mostrar_preinicio'] == true;

      if (confirmado && !_viajesConConfirmacionNotificada.contains(viajeId)) {
        _viajesConConfirmacionNotificada.add(viajeId);
        await onPasajeroConductorConfirmado(viaje);
        await LocalNotificationService.show(
          id: 2100 + viajeId,
          title: 'Conductor confirmo el viaje',
          body:
              'El conductor del viaje de ${viaje['inicio']} a ${viaje['destino']} a las ${viaje['hora_salida']} confirmo el viaje de hoy.',
        );
      }

      if (mostrar5Min && !_viajes5MinNotificados.contains(viajeId)) {
        _viajes5MinNotificados.add(viajeId);
        await onPasajeroPopup(viaje, esHoraSalida: false);
        await LocalNotificationService.show(
          id: 2200 + viajeId,
          title: 'Tienes un viaje proximo',
          body:
              '${viaje['inicio']} -> ${viaje['destino']} ${viaje['hora_salida']}. Tienes 5 minutos despues de la hora de salida para subir.',
        );
      }

      if (mostrarHora && !_viajesHoraSalidaNotificados.contains(viajeId)) {
        _viajesHoraSalidaNotificados.add(viajeId);
        await onPasajeroPopup(viaje, esHoraSalida: true);
        await LocalNotificationService.show(
          id: 2300 + viajeId,
          title: 'Hora del viaje',
          body: 'Ya es hora de salida. Confirma si ya estas en el vehiculo.',
        );
      }
    }
  }
}
