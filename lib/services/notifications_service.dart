// lib/services/notifications_service.dart
import 'package:flutter/foundation.dart'; // <-- Añade esta línea para debugPrint
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationsService {
  static final NotificationsService _instance = NotificationsService._internal();
  factory NotificationsService() => _instance;
  NotificationsService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Variable para saber si está inicializado
  bool _isInitialized = false;

  Future<void> init() async {
    // ✅ CORREGIDO: Inicializar solo en plataformas móviles
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        // Inicializar datos de zona horaria
        tz_data.initializeTimeZones();

        const AndroidInitializationSettings initializationSettingsAndroid =
            AndroidInitializationSettings('@mipmap/ic_launcher');

        const DarwinInitializationSettings initializationSettingsIOS =
            DarwinInitializationSettings(
              requestAlertPermission: true,
              requestBadgePermission: true,
              requestSoundPermission: true,
            );

        const InitializationSettings initializationSettings =
            InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

        await flutterLocalNotificationsPlugin.initialize(
          initializationSettings,
          onDidReceiveNotificationResponse: (NotificationResponse payload) {
            debugPrint('Notificación recibida: ${payload.payload}');
            // Aquí puedes manejar la navegación cuando se toca la notificación
            // Puedes navegar a una pantalla específica basada en el payload
          },
        );
        _isInitialized = true; // Marcar como inicializado
        debugPrint('DEBUG: Servicio de notificaciones inicializado correctamente.');
      } catch (e) {
        debugPrint('ERROR: No se pudo inicializar el servicio de notificaciones: $e');
        // Opcional: Manejar el error de forma más elegante
      }
    } else {
      debugPrint('DEBUG: Servicio de notificaciones no inicializado (plataforma no móvil o web).');
      // Opcional: Puedes marcarlo como inicializado de forma "vacía" si es necesario para la lógica de tu app
      // _isInitialized = true;
    }
  }

  // Método para verificar si está listo para usar
  bool get isReady => _isInitialized;

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // ✅ CORREGIDO: Verificar si está inicializado antes de intentar mostrar
    if (!isReady) {
      debugPrint('WARNING: showNotification llamado, pero el servicio no está inicializado.');
      return;
    }
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'loan_app_channel', // ID del canal
      'Cobros Pendientes', // Nombre del canal
      channelDescription: 'Notificaciones para recordatorios de cobro.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Nuevo recordatorio',
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0, // ID único de la notificación
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Opcional: Método para programar notificaciones (v19.x)
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    // ✅ CORREGIDO: Verificar si está inicializado antes de intentar programar
    if (!isReady) {
      debugPrint('WARNING: scheduleNotification llamado, pero el servicio no está inicializado.');
      return;
    }
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'loan_app_channel', // ID del canal
      'Cobros Pendientes', // Nombre del canal
      channelDescription: 'Notificaciones programadas para recordatorios de cobro.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local), // Usar zona horaria local
      platformChannelSpecifics,
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}