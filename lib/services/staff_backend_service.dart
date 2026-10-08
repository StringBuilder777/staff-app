import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/backend_config.dart';

class StaffParticipant {
  final String id;
  final String name;
  final String? lastName;
  final String? nfcToken;
  final bool nfcActive;
  final String? checkinAt;
  final String? breakfastAt;
  final String? lunchAt;

  const StaffParticipant({
    required this.id,
    required this.name,
    this.lastName,
    this.nfcToken,
    this.nfcActive = false,
    this.checkinAt,
    this.breakfastAt,
    this.lunchAt,
  });

  factory StaffParticipant.fromJson(Map<String, dynamic> json) {
    return StaffParticipant(
      id: json['id']?.toString() ?? '',
      name: json['nombre']?.toString() ?? '',
      lastName: json['apellidos']?.toString(),
      nfcToken: json['nfc_token']?.toString(),
      nfcActive: json['nfc_activa'] == true,
      checkinAt: json['checkin_en']?.toString(),
      breakfastAt: json['desayuno_en']?.toString(),
      lunchAt: json['comida_en']?.toString(),
    );
  }

  String get fullName =>
      lastName != null && lastName!.isNotEmpty ? '$name $lastName' : name;
}

class TeamFromQrResult {
  final bool success;
  final int statusCode;
  final String? teamId;
  final String? teamName;
  final List<StaffParticipant> participants;
  final String? errorMessage;

  const TeamFromQrResult({
    required this.success,
    required this.statusCode,
    this.teamId,
    this.teamName,
    this.participants = const [],
    this.errorMessage,
  });

  factory TeamFromQrResult.success({
    required String teamId,
    required String teamName,
    required List<StaffParticipant> participants,
  }) => TeamFromQrResult(
    success: true,
    statusCode: 200,
    teamId: teamId,
    teamName: teamName,
    participants: participants,
  );

  factory TeamFromQrResult.error({
    required int statusCode,
    required String message,
  }) => TeamFromQrResult(
    success: false,
    statusCode: statusCode,
    errorMessage: message,
  );
}

class IssueNfcResult {
  final bool success;
  final int statusCode;
  final String? integranteId;
  final String? nfcToken;
  final String? payload;
  final String? errorMessage;

  const IssueNfcResult({
    required this.success,
    required this.statusCode,
    this.integranteId,
    this.nfcToken,
    this.payload,
    this.errorMessage,
  });

  factory IssueNfcResult.success({
    required String integranteId,
    required String nfcToken,
    required String payload,
  }) => IssueNfcResult(
    success: true,
    statusCode: 200,
    integranteId: integranteId,
    nfcToken: nfcToken,
    payload: payload,
  );

  factory IssueNfcResult.error({
    required int statusCode,
    required String message,
  }) => IssueNfcResult(
    success: false,
    statusCode: statusCode,
    errorMessage: message,
  );
}

/// Asistente de SITEC tal como lo ve el registro.
class SitecAsistente {
  final String id;
  final String fullName;

  /// Cuándo se confirmó que su tarjeta está escrita; null si todavía no tiene.
  final String? nfcIssuedAt;

  const SitecAsistente({
    required this.id,
    required this.fullName,
    this.nfcIssuedAt,
  });

  factory SitecAsistente.fromJson(Map<String, dynamic> json) => SitecAsistente(
    id: json['id']?.toString() ?? '',
    fullName: StaffBackendService._sitecName(json),
    nfcIssuedAt: json['nfc_emitida_en']?.toString(),
  );
}

class SitecAsistentesResult {
  final bool success;
  final int statusCode;
  final List<SitecAsistente> asistentes;
  final String? errorMessage;

  const SitecAsistentesResult({
    required this.success,
    required this.statusCode,
    this.asistentes = const [],
    this.errorMessage,
  });

  factory SitecAsistentesResult.success(List<SitecAsistente> asistentes) =>
      SitecAsistentesResult(
        success: true,
        statusCode: 200,
        asistentes: asistentes,
      );

  factory SitecAsistentesResult.error({
    required int statusCode,
    required String message,
  }) => SitecAsistentesResult(
    success: false,
    statusCode: statusCode,
    errorMessage: message,
  );
}

class ScanNfcResult {
  final bool success;
  final bool isDuplicate;
  final int statusCode;
  final String? accessType;
  final String? registeredAt;
  final String? previouslyRegisteredAt;
  final String? participantName;
  final String? teamName;
  final String? participantId;

  /// Kit del asistente de SITEC tal como se muestra: Premium, Básico o
  /// General. Null en el hackathon y en quien no está en el registro de ventas.
  final String? kit;
  final String? errorMessage;

  const ScanNfcResult({
    required this.success,
    required this.isDuplicate,
    required this.statusCode,
    this.accessType,
    this.registeredAt,
    this.previouslyRegisteredAt,
    this.participantName,
    this.teamName,
    this.participantId,
    this.kit,
    this.errorMessage,
  });

  factory ScanNfcResult.accepted({
    required String accessType,
    required String registeredAt,
    required String participantName,
    required String teamName,
    required String participantId,
  }) => ScanNfcResult(
    success: true,
    isDuplicate: false,
    statusCode: 200,
    accessType: accessType,
    registeredAt: registeredAt,
    participantName: participantName,
    teamName: teamName,
    participantId: participantId,
  );

  factory ScanNfcResult.duplicate({
    required String accessType,
    required String previouslyRegisteredAt,
    required String errorMessage,
    required String participantName,
    required String teamName,
  }) => ScanNfcResult(
    success: false,
    isDuplicate: true,
    statusCode: 409,
    accessType: accessType,
    previouslyRegisteredAt: previouslyRegisteredAt,
    errorMessage: errorMessage,
    participantName: participantName,
    teamName: teamName,
  );

  factory ScanNfcResult.error({
    required int statusCode,
    required String errorMessage,
  }) => ScanNfcResult(
    success: false,
    isDuplicate: false,
    statusCode: statusCode,
    errorMessage: errorMessage,
  );
}

class StaffBackendService {
  final http.Client _client;

  StaffBackendService({http.Client? client})
    : _client = client ?? http.Client();

  /// Token de la sesión activa, que `supabase_flutter` renueva por su cuenta.
  ///
  /// Devuelve null si Supabase no está inicializado, cosa que ocurre en las
  /// pruebas de widget, para que ahí se siga usando el token manual.
  Future<String?> _sessionToken() async {
    try {
      final auth = Supabase.instance.client.auth;
      final session = auth.currentSession;
      if (session == null) return null;
      // Al restaurar la sesión tras un rato apagado, el access token puede
      // venir caducado mientras el refresco corre por detrás. Sin esperarlo,
      // el primer escaneo del día saldría con un JWT muerto y daría 401.
      if (session.isExpired) {
        final refreshed = await auth.refreshSession();
        return refreshed.session?.accessToken;
      }
      return session.accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    // La sesión la firma el proyecto cloud, así que solo sirve contra cloud.
    // En túnel y red local el backend valida con otro secreto y ese JWT daría
    // 401, por eso ahí manda el token pegado a mano.
    final session = await _sessionToken() ?? '';
    final manual = BackendConfig.staffAuthToken;
    final token = BackendConfig.mode == BackendMode.cloud
        ? (session.isNotEmpty ? session : manual)
        : (manual.isNotEmpty ? manual : session);
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// 1. Consulta equipo e integrantes mediante el token QR
  Future<TeamFromQrResult> getTeamFromQr(String qrToken) async {
    try {
      final url = Uri.parse('${BackendConfig.functionsUrl}/staff-team-from-qr');
      final response = await _client.post(
        url,
        headers: await _buildHeaders(),
        body: jsonEncode({'qrToken': qrToken}),
      );

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final equipo = body['equipo'] as Map<String, dynamic>;
        final rawList = (body['integrantes'] as List<dynamic>?) ?? [];
        final list = rawList
            .map((e) => StaffParticipant.fromJson(e as Map<String, dynamic>))
            .toList();

        return TeamFromQrResult.success(
          teamId: equipo['id']?.toString() ?? '',
          teamName: equipo['nombre']?.toString() ?? '',
          participants: list,
        );
      }

      return TeamFromQrResult.error(
        statusCode: response.statusCode,
        message: body['error']?.toString() ?? 'Error al obtener equipo',
      );
    } catch (e) {
      return TeamFromQrResult.error(
        statusCode: 0,
        message: 'No se pudo conectar con el servidor: $e',
      );
    }
  }

  /// 2. Asigna o reactiva una tarjeta NFC a un participante
  Future<IssueNfcResult> issueNfc(String integranteId) async {
    try {
      final url = Uri.parse('${BackendConfig.functionsUrl}/staff-issue-nfc');
      final response = await _client.post(
        url,
        headers: await _buildHeaders(),
        body: jsonEncode({'integranteId': integranteId}),
      );

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return IssueNfcResult.success(
          integranteId: body['integranteId']?.toString() ?? '',
          nfcToken: body['nfcToken']?.toString() ?? '',
          payload: body['payload']?.toString() ?? '',
        );
      }

      return IssueNfcResult.error(
        statusCode: response.statusCode,
        message: body['error']?.toString() ?? 'Error al emitir NFC',
      );
    } catch (e) {
      return IssueNfcResult.error(
        statusCode: 0,
        message: 'No se pudo conectar con el servidor: $e',
      );
    }
  }

  /// 3. Escanea una tarjeta NFC para registrar checkin, desayuno o comida
  Future<ScanNfcResult> scanNfc({
    required String nfcToken,
    required String accessType,
  }) async {
    try {
      final url = Uri.parse('${BackendConfig.functionsUrl}/staff-scan-nfc');
      final response = await _client.post(
        url,
        headers: await _buildHeaders(),
        body: jsonEncode({'nfcToken': nfcToken, 'accessType': accessType}),
      );

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final part = body['participante'] as Map<String, dynamic>?;
        final team = body['equipo'] as Map<String, dynamic>?;

        return ScanNfcResult.accepted(
          accessType: body['accessType']?.toString() ?? accessType,
          registeredAt: body['registeredAt']?.toString() ?? '',
          participantName: part?['nombre']?.toString() ?? 'Participante',
          teamName: team?['nombre']?.toString() ?? 'Equipo',
          participantId: part?['id']?.toString() ?? '',
        );
      }

      if (response.statusCode == 409) {
        final part = body['participante'] as Map<String, dynamic>?;
        final team = body['equipo'] as Map<String, dynamic>?;

        return ScanNfcResult.duplicate(
          accessType: body['accessType']?.toString() ?? accessType,
          previouslyRegisteredAt:
              body['previouslyRegisteredAt']?.toString() ?? '',
          errorMessage: body['error']?.toString() ?? 'Acceso ya registrado',
          participantName: part?['nombre']?.toString() ?? 'Participante',
          teamName: team?['nombre']?.toString() ?? 'Equipo',
        );
      }

      return ScanNfcResult.error(
        statusCode: response.statusCode,
        errorMessage: body['error']?.toString() ?? 'Error al validar NFC',
      );
    } catch (e) {
      return ScanNfcResult.error(
        statusCode: 0,
        errorMessage: 'No se pudo conectar con el servidor: $e',
      );
    }
  }

  /// 4. Escanea una tarjeta NFC en un punto de acceso de SITEC.
  ///
  /// SITEC valida contra sus propios asistentes y no tiene equipos, así que el
  /// resultado llega sin [ScanNfcResult.teamName].
  Future<ScanNfcResult> scanSitecNfc({
    required String nfcToken,
    required String accessType,
  }) async {
    try {
      final url = Uri.parse(
        '${BackendConfig.functionsUrl}/staff-sitec-scan-nfc',
      );
      final response = await _client.post(
        url,
        headers: await _buildHeaders(),
        body: jsonEncode({'nfcToken': nfcToken, 'accessType': accessType}),
      );

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      final asistente = body['asistente'] as Map<String, dynamic>?;

      if (response.statusCode == 200) {
        return ScanNfcResult(
          success: true,
          isDuplicate: false,
          statusCode: 200,
          accessType: body['accessType']?.toString() ?? accessType,
          registeredAt: body['registeredAt']?.toString() ?? '',
          participantName: _sitecName(asistente),
          participantId: asistente?['id']?.toString() ?? '',
          kit: sitecKitLabel(asistente?['kit']),
        );
      }

      if (response.statusCode == 409) {
        return ScanNfcResult(
          success: false,
          isDuplicate: true,
          statusCode: 409,
          accessType: body['accessType']?.toString() ?? accessType,
          previouslyRegisteredAt:
              body['previouslyRegisteredAt']?.toString() ?? '',
          errorMessage: body['error']?.toString() ?? 'Acceso ya registrado',
          participantName: _sitecName(asistente),
          kit: sitecKitLabel(asistente?['kit']),
        );
      }

      // Los errores propios de la plataforma, como una función todavía sin
      // desplegar, traen `message` en vez de `error`.
      return ScanNfcResult.error(
        statusCode: response.statusCode,
        errorMessage:
            (body['error'] ?? body['message'])?.toString() ??
            'Error al validar NFC',
      );
    } catch (e) {
      return ScanNfcResult.error(
        statusCode: 0,
        errorMessage: 'No se pudo conectar con el servidor: $e',
      );
    }
  }

  /// 5. Lista a los asistentes de SITEC para el registro, en orden alfabético.
  Future<SitecAsistentesResult> listSitecAsistentes() async {
    try {
      final url = Uri.parse(
        '${BackendConfig.functionsUrl}/staff-sitec-asistentes',
      );
      final response = await _client.post(
        url,
        headers: await _buildHeaders(),
        body: jsonEncode(<String, dynamic>{}),
      );

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final rawList = (body['asistentes'] as List<dynamic>?) ?? [];
        return SitecAsistentesResult.success(
          rawList
              .map((e) => SitecAsistente.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }

      // Los errores propios de la plataforma, como una función todavía sin
      // desplegar, traen `message` en vez de `error`.
      return SitecAsistentesResult.error(
        statusCode: response.statusCode,
        message:
            (body['error'] ?? body['message'])?.toString() ??
            'Error al obtener los asistentes',
      );
    } catch (e) {
      return SitecAsistentesResult.error(
        statusCode: 0,
        message: 'No se pudo conectar con el servidor: $e',
      );
    }
  }

  /// 6. Emite la tarjeta NFC de un asistente de SITEC, en dos pasos: primero
  /// pide el payload que se escribe y, con [written], confirma que la tarjeta
  /// ya está escrita para que el registro la cuente.
  ///
  /// Devuelve el mismo [IssueNfcResult] que el hackathon, porque el registro
  /// solo usa el payload y el token; [IssueNfcResult.integranteId] lleva aquí
  /// el id del asistente.
  Future<IssueNfcResult> issueSitecNfc(
    String asistenteId, {
    bool written = false,
  }) async {
    try {
      final url = Uri.parse(
        '${BackendConfig.functionsUrl}/staff-sitec-issue-nfc',
      );
      final response = await _client.post(
        url,
        headers: await _buildHeaders(),
        body: jsonEncode({'asistenteId': asistenteId, 'written': written}),
      );

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return IssueNfcResult.success(
          integranteId: body['asistenteId']?.toString() ?? '',
          nfcToken: body['nfcToken']?.toString() ?? '',
          payload: body['payload']?.toString() ?? '',
        );
      }

      return IssueNfcResult.error(
        statusCode: response.statusCode,
        message:
            (body['error'] ?? body['message'])?.toString() ??
            'Error al emitir NFC',
      );
    } catch (e) {
      return IssueNfcResult.error(
        statusCode: 0,
        message: 'No se pudo conectar con el servidor: $e',
      );
    }
  }

  /// Nombre completo del asistente. Sin equipo que lo acompañe, el apellido es
  /// lo que distingue en la puerta a dos asistentes que se llaman igual.
  static String _sitecName(Map<String, dynamic>? asistente) {
    final name = [asistente?['nombre'], asistente?['apellidos']]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    return name.isEmpty ? 'Asistente' : name;
  }

  /// Kit de SITEC tal como se muestra. La base lo guarda en minúsculas y sin
  /// acento; un valor que la app no conozca se muestra tal cual.
  @visibleForTesting
  static String? sitecKitLabel(Object? kit) {
    if (kit is! String || kit.trim().isEmpty) return null;
    return switch (kit.trim().toLowerCase()) {
      'premium' => 'Premium',
      'basico' => 'Básico',
      'general' => 'General',
      final otro => otro,
    };
  }
}
