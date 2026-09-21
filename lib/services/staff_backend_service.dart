import 'dart:convert';
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
  String? _sessionToken() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    // La sesión la firma el proyecto cloud, así que solo sirve contra cloud.
    // En túnel y red local el backend valida con otro secreto y ese JWT daría
    // 401, por eso ahí manda el token pegado a mano.
    final session = _sessionToken() ?? '';
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
        headers: _buildHeaders(),
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
        headers: _buildHeaders(),
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
        headers: _buildHeaders(),
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
}
