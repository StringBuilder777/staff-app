import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/backend_config.dart';
import 'screens/login_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'services/nfc_service.dart';
import 'services/staff_backend_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: BackendConfig.supabaseUrl,
    // `anonKey` está marcado como obsoleto en favor de `publishableKey`, pero
    // la clave del proyecto sigue siendo del formato antiguo (JWT `eyJ...`).
    // Se mantiene hasta migrar la clave en Supabase, porque equivocarse aquí
    // deja la app sin poder conectarse.
    // ignore: deprecated_member_use
    anonKey: BackendConfig.supabaseAnonKey,
  );
  runApp(const StaffApp());
}

class StaffApp extends StatelessWidget {
  const StaffApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Staff',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _Colors.teal),
      scaffoldBackgroundColor: const Color(0xFFF4F7FA),
      useMaterial3: true,
    ),
    home: const AuthGate(),
  );
}

/// Decide entre login y app según haya sesión de Supabase.
///
/// El modo simulación entra directo: existe para probar la interfaz sin backend
/// y pedir credenciales ahí no aportaría nada. En los demás modos la sesión es
/// obligatoria, porque el backend necesita saber qué staff registra cada acceso.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  GoTrueClient? _authOrNull() {
    try {
      return Supabase.instance.client.auth;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<BackendMode>(
    valueListenable: BackendConfig.modeNotifier,
    builder: (context, mode, _) {
      // Solo cloud exige sesión: es el proyecto que firma el JWT. Simulación no
      // habla con el backend, y túnel y red local apuntan a una instancia que
      // valida con otro secreto, así que ahí manda el token manual.
      if (mode != BackendMode.cloud) return const HomeScreen();

      final auth = _authOrNull();
      // Supabase sin inicializar (pruebas de widget): se sigue con el token
      // manual de BackendConfig, que es el comportamiento previo al login.
      if (auth == null) return const HomeScreen();

      return StreamBuilder<AuthState>(
        stream: auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.data?.session ?? auth.currentSession;
          return session == null ? const LoginScreen() : const HomeScreen();
        },
      );
    },
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        // El AuthGate devuelve al login en cuanto la sesión se cierra, así que
        // aquí no hace falta navegar.
        if (BackendConfig.mode == BackendMode.cloud)
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: _Colors.navy),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              // Los estáticos sobreviven al cierre de sesión: sin limpiarlos,
              // el siguiente staff heredaría el token y la última credencial
              // del anterior, y los accesos se le atribuirían a quien no fue.
              BackendConfig.staffAuthToken = '';
              BackendConfig.lastIssuedNfcToken = '';
              await Supabase.instance.client.auth.signOut();
            },
          ),
        IconButton(
          icon: const Icon(Icons.tune_rounded, color: _Colors.navy),
          tooltip: 'Configuración de conexión',
          onPressed: () async {
            await _showConfigSheet(context);
            setState(() {});
          },
        ),
      ],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Inicio',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: _Colors.navy,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Selecciona una operación para continuar.',
              style: TextStyle(fontSize: 16, color: _Colors.muted),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                await _showConfigSheet(context);
                setState(() {});
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: BackendConfig.isSimulation
                      ? const Color(0xFFFFF7ED)
                      : const Color(0xFFE6FFFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: BackendConfig.isSimulation
                        ? const Color(0xFFFFEDD5)
                        : const Color(0xFFB2F5EA),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      BackendConfig.isSimulation
                          ? Icons.offline_bolt_rounded
                          : Icons.cloud_done_rounded,
                      size: 18,
                      color: BackendConfig.isSimulation
                          ? const Color(0xFFC2410C)
                          : _Colors.teal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Modo: ${BackendConfig.modeLabel}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: BackendConfig.isSimulation
                            ? const Color(0xFF9A3412)
                            : _Colors.navy,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: _Colors.muted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            _ActionCard(
              title: 'Registro',
              description:
                  'Escanea el QR del equipo y escribe sus tarjetas NFC.',
              icon: Icons.group_outlined,
              primary: true,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RegistrationScreen(),
                  ),
                );
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            _ActionCard(
              title: 'Eventos',
              description: 'Valida asistentes en check-in, comida y desayuno.',
              icon: Icons.event_available_outlined,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const EventsScreen()),
                );
                setState(() {});
              },
            ),
            const Spacer(),
            const Center(
              child: Text(
                'Staff · Operación de evento',
                style: TextStyle(color: _Colors.muted),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _showConfigSheet(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => const _BackendConfigModal(),
      );
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  static const List<StaffParticipant> _simulatedParticipants = [
    StaffParticipant(id: 'sim-1', name: 'Ana Torres'),
    StaffParticipant(id: 'sim-2', name: 'Luis Herrera'),
    StaffParticipant(id: 'sim-3', name: 'María López'),
    StaffParticipant(id: 'sim-4', name: 'Diego Ramírez'),
  ];

  late final TextEditingController _qrController;
  List<StaffParticipant> _participants = [];
  final Set<String> _writtenParticipantIds = <String>{};
  bool _teamLoaded = false;
  bool _isLoading = false;
  String? _errorMessage;
  String _teamName = 'Equipo Boreal';
  String? _teamId;

  @override
  void initState() {
    super.initState();
    _qrController = TextEditingController(
      text: BackendConfig.isSimulation ? 'simulado-boreal-qr' : '',
    );
    if (BackendConfig.isSimulation) {
      _participants = _simulatedParticipants;
    }
  }

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
  }

  void _loadSimulatedTeam() {
    setState(() {
      _teamName = 'Equipo Boreal';
      _teamId = 'EQUIPO-BOREAL';
      _participants = _simulatedParticipants;
      _writtenParticipantIds.clear();
      _teamLoaded = true;
      _errorMessage = null;
    });
  }

  Future<void> _fetchTeamByQr() async {
    final token = _qrController.text.trim();
    if (token.isEmpty) {
      setState(
        () => _errorMessage = 'Por favor ingresa o escanea un token QR.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final service = StaffBackendService();
    final res = await service.getTeamFromQr(token);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.success) {
        _teamName = res.teamName ?? 'Equipo';
        _teamId = res.teamId;
        _participants = res.participants;
        _writtenParticipantIds.clear();
        for (final p in res.participants) {
          if (p.nfcActive) {
            _writtenParticipantIds.add(p.id);
          }
        }
        _teamLoaded = true;
        _errorMessage = null;
      } else {
        _errorMessage =
            res.errorMessage ?? 'Error al consultar equipo (${res.statusCode})';
      }
    });
  }

  Future<void> _openCameraScanner() async {
    final scannedCode = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScannerScreen()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      _qrController.text = scannedCode;
      await _fetchTeamByQr();
    }
  }

  Future<void> _showConfigSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => const _BackendConfigModal(),
    );
    if (!mounted) return;
    setState(() {
      if (BackendConfig.isSimulation && _participants.isEmpty) {
        _participants = _simulatedParticipants;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Registro de equipo'),
      backgroundColor: Colors.transparent,
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_rounded, color: _Colors.navy),
          tooltip: 'Configuración de conexión',
          onPressed: _showConfigSheet,
        ),
      ],
    ),
    body: SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _teamLoaded ? _teamDetails() : _qrStep(),
      ),
    ),
  );

  Widget _qrStep() {
    final isSimulation = BackendConfig.isSimulation;

    return SingleChildScrollView(
      key: const ValueKey('qr-step'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isSimulation) ...[
            InkWell(
              onTap: _showConfigSheet,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FFFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFB2F5EA)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_done_rounded,
                      color: _Colors.teal,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${BackendConfig.modeLabel}: ${BackendConfig.functionsUrl}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _Colors.navy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: _Colors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ],
          Text(
            isSimulation
                ? 'Escanea el QR del equipo'
                : 'Consulta de equipo por QR',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _Colors.navy,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isSimulation
                ? 'El código identifica el equipo y permite confirmar a todos sus integrantes.'
                : 'Apunta con la cámara al código QR o introduce el token registrado en Supabase.',
            style: const TextStyle(fontSize: 16, color: _Colors.muted),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: isSimulation ? _loadSimulatedTeam : _openCameraScanner,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: !isSimulation
                    ? Border.all(color: const Color(0xFFB2F5EA), width: 1.5)
                    : null,
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 100,
                    color: _Colors.navy,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isSimulation
                        ? 'Cámara lista para leer QR'
                        : 'Toca para abrir cámara y escanear QR',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: _Colors.navy,
                    ),
                  ),
                  if (!isSimulation) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Activa la cámara para lectura instantánea',
                      style: TextStyle(
                        color: _Colors.teal,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!isSimulation) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              style: _primaryButtonStyle,
              onPressed: _openCameraScanner,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Abrir cámara para escanear QR'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'O ingresa el código manualmente',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _qrController,
              decoration: InputDecoration(
                labelText: 'Token QR del equipo',
                hintText: 'Ej. 52cfc67e-... o pega el token QR',
                prefixIcon: const Icon(Icons.qr_code_2_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () => _qrController.clear(),
                ),
              ),
              onSubmitted: (_) => _fetchTeamByQr(),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _WarningBanner(message: _errorMessage!),
          ],
          const SizedBox(height: 20),
          if (isSimulation)
            FilledButton.icon(
              style: _primaryButtonStyle,
              onPressed: _loadSimulatedTeam,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Simular lectura de QR'),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isLoading ? null : _fetchTeamByQr,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              label: const Text('Consultar equipo por QR'),
            ),
        ],
      ),
    );
  }

  Widget _teamDetails() => ListView(
    key: const ValueKey('team-details'),
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFFE4F6F3),
              child: Icon(Icons.groups_rounded, color: _Colors.teal, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _teamName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _Colors.navy,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_participants.length} participantes confirmados',
                    style: const TextStyle(color: _Colors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.verified_rounded, color: _Colors.success),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Tarjetas de participantes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _Colors.navy,
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _teamLoaded = false),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: const Text('Cambiar QR'),
          ),
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        'Escribe una tarjeta individual por cada integrante.',
        style: TextStyle(color: _Colors.muted),
      ),
      const SizedBox(height: 12),
      ..._participants.indexed.map((entry) {
        final p = entry.$2;
        final isWritten =
            _writtenParticipantIds.contains(p.id) ||
            _writtenParticipantIds.contains(entry.$1.toString());
        return _ParticipantRow(
          name: p.fullName,
          written: isWritten,
          nfcToken: p.nfcToken,
          onWrite: () => _writeCard(p, entry.$1),
        );
      }),
      const SizedBox(height: 18),
      if (_writtenParticipantIds.length >= _participants.length &&
          _participants.isNotEmpty)
        const _SuccessBanner(
          message: 'Equipo registrado y credenciales activas',
        ),
    ],
  );

  Future<void> _writeCard(StaffParticipant participant, int index) async {
    final isSimulation = BackendConfig.isSimulation;
    bool isSubmitting = false;
    String? localError;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            8,
            24,
            MediaQuery.of(modalContext).viewInsets.bottom + 34,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.nfc_rounded, size: 52, color: _Colors.teal),
              const SizedBox(height: 12),
              Text(
                'Escribir tarjeta de ${participant.fullName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isSimulation
                    ? 'Acerca una tarjeta NFC vacía al teléfono.'
                    : 'Se emitirá la credencial y después deberás acercar una tarjeta NFC escribible.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _Colors.muted),
              ),
              if (localError != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          localError!,
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (isSimulation)
                FilledButton(
                  style: _primaryButtonStyle,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    setState(() {
                      _writtenParticipantIds.add(participant.id);
                      _writtenParticipantIds.add(index.toString());
                    });
                  },
                  child: const Text('Confirmar escritura simulada'),
                )
              else
                FilledButton.icon(
                  style: _primaryButtonStyle,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setModalState(() {
                            isSubmitting = true;
                            localError = null;
                          });
                          final service = StaffBackendService();
                          final res = await service.issueNfc(participant.id);
                          if (!modalContext.mounted) return;
                          if (res.success) {
                            final payload = res.payload?.trim() ?? '';
                            if (payload.isEmpty) {
                              setModalState(() {
                                isSubmitting = false;
                                localError =
                                    'El servidor no devolvió un payload NFC válido.';
                              });
                              return;
                            }

                            final writeResult = await const NfcService()
                                .writeTextPayload(payload);
                            if (!modalContext.mounted) return;
                            if (!mounted) return;
                            if (writeResult.success) {
                              BackendConfig.lastIssuedNfcToken =
                                  res.nfcToken ?? '';
                              Navigator.pop(sheetContext);
                              setState(() {
                                _writtenParticipantIds.add(participant.id);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Tarjeta NFC escrita y vinculada correctamente.',
                                  ),
                                  backgroundColor: _Colors.success,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            } else if (writeResult.cancelled) {
                              setModalState(() => isSubmitting = false);
                            } else {
                              setModalState(() {
                                isSubmitting = false;
                                localError =
                                    writeResult.errorMessage ??
                                    'No se pudo escribir la tarjeta NFC.';
                              });
                            }
                          } else {
                            setModalState(() {
                              isSubmitting = false;
                              localError =
                                  res.errorMessage ??
                                  'Error al emitir tarjeta NFC';
                            });
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.nfc_rounded),
                  label: Text(
                    isSubmitting
                        ? 'Vinculando...'
                        : 'Emitir tarjeta NFC en backend',
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // El sheet se puede descartar mientras el lector espera la tarjeta. Sin
    // este cierre la sesión quedaría abierta y la siguiente tarjeta que se
    // acercara se escribiría con la credencial de este participante.
    await const NfcService().cancel();
  }
}

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  static const _events = [
    _EventOption(
      'Check-in',
      'Registra la llegada del participante.',
      Icons.login_rounded,
      code: 'checkin',
    ),
    _EventOption(
      'Desayuno',
      'Valida una entrada al desayuno.',
      Icons.breakfast_dining_outlined,
      code: 'desayuno',
    ),
    _EventOption(
      'Comida',
      'Valida una entrada a la comida.',
      Icons.restaurant_outlined,
      code: 'comida',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Eventos'),
      backgroundColor: Colors.transparent,
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const Text(
              'Selecciona un evento',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _Colors.navy,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Cada opción abre el lector NFC para ese momento.',
              style: TextStyle(fontSize: 16, color: _Colors.muted),
            ),
            const SizedBox(height: 28),
            ..._events.indexed.expand(
              (entry) => [
                _ActionCard(
                  title: entry.$2.name,
                  description: entry.$2.description,
                  icon: entry.$2.icon,
                  primary: entry.$1 == 0,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EventScanScreen(event: entry.$2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class EventScanScreen extends StatefulWidget {
  const EventScanScreen({super.key, required this.event});
  final _EventOption event;
  @override
  State<EventScanScreen> createState() => _EventScanScreenState();
}

class _EventScanScreenState extends State<EventScanScreen> {
  _ScannedParticipant? _participant;
  bool _isLoading = false;

  /// Cierto solo mientras el lector NFC está abierto esperando una tarjeta, no
  /// durante la consulta posterior al backend. El botón usa esta distinción
  /// para ofrecer cancelar únicamente cuando cancelar tiene sentido.
  bool _isWaitingForCard = false;
  bool _isDuplicate = false;
  String? _duplicateTimestamp;
  late final TextEditingController _tokenInputController;

  @override
  void initState() {
    super.initState();
    _tokenInputController = TextEditingController(
      text: BackendConfig.lastIssuedNfcToken.isNotEmpty
          ? BackendConfig.lastIssuedNfcToken
          : 'valid-nfc-token-123',
    );
  }

  @override
  void dispose() {
    // Si se abandona la pantalla mientras espera una tarjeta hay que cerrar el
    // lector; si no, seguiría capturando tarjetas fuera de esta pantalla.
    unawaited(const NfcService().cancel());
    _tokenInputController.dispose();
    super.dispose();
  }

  Future<void> _cancelScan() => const NfcService().cancel();

  Future<void> _handleScan() async {
    if (BackendConfig.isSimulation) {
      setState(() {
        _participant = const _ScannedParticipant(
          'Ana Torres',
          'Equipo Boreal',
          'PART-00128',
        );
        _isDuplicate = false;
        _duplicateTimestamp = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isWaitingForCard = true;
    });
    final nfcResult = await const NfcService().readTextPayload();
    if (!mounted) return;
    setState(() => _isWaitingForCard = false);

    if (nfcResult.cancelled) {
      setState(() => _isLoading = false);
      return;
    }

    if (!nfcResult.success) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nfcResult.errorMessage ?? 'No se pudo leer la tarjeta NFC.',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final token = nfcResult.payload!;
    _tokenInputController.text = token;
    final service = StaffBackendService();
    final res = await service.scanNfc(
      nfcToken: token,
      accessType: widget.event.code,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.success) {
        _participant = _ScannedParticipant(
          res.participantName ?? 'Participante',
          res.teamName ?? 'Equipo',
          res.participantId ?? token,
        );
        _isDuplicate = false;
        _duplicateTimestamp = null;
      } else if (res.isDuplicate) {
        _participant = _ScannedParticipant(
          res.participantName ?? 'Participante',
          res.teamName ?? 'Equipo',
          'ACCESO-PREVIO',
        );
        _isDuplicate = true;
        _duplicateTimestamp = res.previouslyRegisteredAt;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorMessage ?? 'Error al escanear tarjeta'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.event.name),
      backgroundColor: Colors.transparent,
      actions: [
        IconButton(
          icon: const Icon(Icons.tune_rounded, color: _Colors.navy),
          tooltip: 'Configuración de conexión',
          onPressed: () async {
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (sheetContext) => const _BackendConfigModal(),
            );
            setState(() {});
          },
        ),
      ],
    ),
    body: Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lectura NFC · ${widget.event.name}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _Colors.navy,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Acerca la tarjeta del participante al teléfono para validarla.',
            style: TextStyle(color: _Colors.muted, fontSize: 16),
          ),
          const SizedBox(height: 20),
          if (!BackendConfig.isSimulation) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                controller: _tokenInputController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Última credencial leída',
                  hintText: 'Se completa al leer la tarjeta',
                  prefixIcon: const Icon(Icons.nfc_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _participant == null ? _readerState() : _participantCard(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: _primaryButtonStyle,
            onPressed: _isWaitingForCard
                ? _cancelScan
                : (_isLoading ? null : _handleScan),
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.nfc_rounded),
            label: Text(
              _isWaitingForCard
                  ? 'Cancelar lectura'
                  : BackendConfig.isSimulation
                  ? 'Simular lectura NFC'
                  : 'Leer tarjeta NFC',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _readerState() => Container(
    key: const ValueKey('reader'),
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: const Color(0xFFE9FAF7),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFFB8EAE1)),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.nfc_rounded, size: 88, color: _Colors.teal),
        SizedBox(height: 22),
        Text(
          'Listo para leer tarjeta',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _Colors.navy,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Mantén una sola tarjeta cerca del teléfono.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _Colors.muted),
        ),
      ],
    ),
  );

  Widget _participantCard() {
    final participant = _participant!;
    return ListView(
      key: const ValueKey('participant'),
      children: [
        if (_isDuplicate)
          _WarningBanner(
            message:
                'Acceso duplicado: registrado previamente a las ${_duplicateTimestamp ?? ""}',
          )
        else
          const _SuccessBanner(message: 'Acceso registrado correctamente'),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 42,
                backgroundColor: Color(0xFFE4F6F3),
                child: Icon(
                  Icons.person_rounded,
                  size: 46,
                  color: _Colors.teal,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                participant.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: _Colors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                participant.team,
                style: const TextStyle(fontSize: 16, color: _Colors.muted),
              ),
              const SizedBox(height: 24),
              const Divider(),
              _InfoRow(label: 'Evento', value: widget.event.name),
              _InfoRow(label: 'Credencial', value: participant.credential),
              _InfoRow(
                label: 'Estado',
                value: _isDuplicate ? 'Ya registrado (409)' : 'Acceso válido',
                success: !_isDuplicate,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => setState(() => _participant = null),
          icon: const Icon(Icons.nfc_rounded),
          label: const Text('Leer otra tarjeta'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.success = false,
  });
  final String label;
  final String value;
  final bool success;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: _Colors.muted)),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: success ? _Colors.success : _Colors.navy,
          ),
        ),
      ],
    ),
  );
}

class _EventOption {
  const _EventOption(
    this.name,
    this.description,
    this.icon, {
    this.code = 'checkin',
  });
  final String name;
  final String description;
  final IconData icon;
  final String code;
}

class _ScannedParticipant {
  const _ScannedParticipant(this.name, this.team, this.credential);
  final String name;
  final String team;
  final String credential;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: Ink(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primary ? _Colors.teal : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(icon, size: 44, color: primary ? Colors.white : _Colors.navy),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: primary ? Colors.white : _Colors.navy,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.35,
                    color: primary
                        ? Colors.white.withValues(alpha: .9)
                        : _Colors.muted,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: primary ? Colors.white : _Colors.navy,
          ),
        ],
      ),
    ),
  );
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.name,
    required this.written,
    this.nfcToken,
    required this.onWrite,
  });
  final String name;
  final bool written;
  final String? nfcToken;
  final VoidCallback onWrite;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          backgroundColor: Color(0xFFEAF0F5),
          child: Icon(Icons.person_outline, color: _Colors.navy),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _Colors.navy,
                ),
              ),
              Text(
                // `written` sale de `nfc_activa` del backend: significa que la
                // credencial está emitida, no que se haya escrito una tarjeta
                // física en esta sesión.
                written ? 'Credencial activa' : 'Pendiente de escribir',
                style: TextStyle(
                  color: written ? _Colors.success : _Colors.muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (written) ...[
          const Icon(Icons.check_circle_rounded, color: _Colors.success),
          const SizedBox(width: 4),
        ],
        // El botón nunca se oculta: si alguien pierde la tarjeta hay que poder
        // reescribirla sin tener que volver a escanear el QR del equipo.
        TextButton(
          onPressed: onWrite,
          child: Text(written ? 'Reescribir' : 'Escribir NFC'),
        ),
      ],
    ),
  );
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFDDF8EE),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: _Colors.success),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF047857),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Participant {
  const _Participant(this.name);
  final String name;
}

class _Colors {
  static const navy = Color(0xFF102A43);
  static const teal = Color(0xFF0FA99A);
  static const success = Color(0xFF059669);
  static const muted = Color(0xFF627D98);
}

final _primaryButtonStyle = FilledButton.styleFrom(
  minimumSize: const Size.fromHeight(56),
  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
);

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF3C7),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFDE68A)),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF92400E),
            ),
          ),
        ),
      ],
    ),
  );
}

class _BackendConfigModal extends StatefulWidget {
  const _BackendConfigModal();

  @override
  State<_BackendConfigModal> createState() => _BackendConfigModalState();
}

class _BackendConfigModalState extends State<_BackendConfigModal> {
  late BackendMode _selectedMode;
  late TextEditingController _tunnelController;
  late TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    _selectedMode = BackendConfig.mode;
    _tunnelController = TextEditingController(
      text: BackendConfig.tunnelBaseUrl,
    );
    _tokenController = TextEditingController(
      text: BackendConfig.staffAuthToken,
    );
  }

  @override
  void dispose() {
    _tunnelController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Configuración de Conexión',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _Colors.navy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecciona el modo de comunicación con Supabase Edge Functions:',
              style: TextStyle(color: _Colors.muted),
            ),
            const SizedBox(height: 14),
            RadioListTile<BackendMode>(
              title: const Text('Túnel HTTPS (Cloudflare / localtunnel)'),
              subtitle: const Text(
                'Recomendado: Cloudflare Tunnel o localtunnel',
              ),
              value: BackendMode.tunnel,
              groupValue: _selectedMode,
              onChanged: (val) => setState(() => _selectedMode = val!),
            ),
            if (_selectedMode == BackendMode.tunnel)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: TextField(
                  controller: _tunnelController,
                  decoration: const InputDecoration(
                    labelText: 'URL del túnel',
                    hintText: 'https://xyz.trycloudflare.com/functions/v1',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            RadioListTile<BackendMode>(
              title: const Text('Red Local Wi-Fi (IP de la Mac)'),
              subtitle: const Text('http://10.0.40.78:54321/functions/v1'),
              value: BackendMode.localNetwork,
              groupValue: _selectedMode,
              onChanged: (val) => setState(() => _selectedMode = val!),
            ),
            RadioListTile<BackendMode>(
              title: const Text('Supabase Cloud (Remoto)'),
              subtitle: const Text('uopfoekxkluotowilzaa.supabase.co'),
              value: BackendMode.cloud,
              groupValue: _selectedMode,
              onChanged: (val) => setState(() => _selectedMode = val!),
            ),
            RadioListTile<BackendMode>(
              title: const Text('Modo Simulación (Offline)'),
              subtitle: const Text(
                'Prueba de interfaz sin conexión al servidor',
              ),
              value: BackendMode.simulation,
              groupValue: _selectedMode,
              onChanged: (val) => setState(() => _selectedMode = val!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'JWT Token de Staff (Opcional si --no-verify-jwt)',
                hintText: 'Pega el token Bearer para autenticación',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: _primaryButtonStyle,
              onPressed: () {
                setState(() {
                  BackendConfig.mode = _selectedMode;
                  BackendConfig.tunnelBaseUrl = _tunnelController.text.trim();
                  BackendConfig.staffAuthToken = _tokenController.text.trim();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Modo activo: ${_selectedMode.name}')),
                );
              },
              child: const Text('Guardar configuración'),
            ),
          ],
        ),
      ),
    );
  }
}
