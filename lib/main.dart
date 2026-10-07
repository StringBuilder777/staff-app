import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/backend_config.dart';
import 'screens/event_selection_screen.dart';
import 'screens/login_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'services/connection_status.dart';
import 'theme/dot_matrix.dart';
import 'theme/motion.dart';
import 'theme/nothing.dart';
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
    theme: Nothing.theme(),
    home: const AuthGate(),
  );
}

/// Raíz de la app una vez resuelto el acceso.
const _eventSelection = EventSelectionScreen(
  hackathon: HomeScreen(),
  sitec: SitecScreen(),
  actions: [_TopBarActions()],
);

/// Acciones de la barra superior: configuración de conexión y cierre de sesión.
///
/// Viven aquí y no en la pantalla de selección porque dependen del estado de
/// sesión de Supabase y del modo de backend.
class _TopBarActions extends StatefulWidget {
  const _TopBarActions();

  @override
  State<_TopBarActions> createState() => _TopBarActionsState();
}

class _TopBarActionsState extends State<_TopBarActions> {
  @override
  void initState() {
    super.initState();
    ConnectionStatus.start();
  }

  @override
  void dispose() {
    // Sin esto el temporizador del sondeo sobrevive al widget y deja timers
    // pendientes que hacen fallar las pruebas de widget.
    ConnectionStatus.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const _ConnectionDot(),
      if (BackendConfig.mode == BackendMode.cloud)
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Nothing.ink),
          tooltip: 'Cerrar sesión',
          onPressed: () async {
            // Los estáticos sobreviven al cierre de sesión: sin limpiarlos, el
            // siguiente staff heredaría el token y la última credencial del
            // anterior, y los accesos se le atribuirían a quien no fue.
            BackendConfig.staffAuthToken = '';
            BackendConfig.lastIssuedNfcToken = '';
            await Supabase.instance.client.auth.signOut();
          },
        ),
    ],
  );
}

/// Luz de conexión con las Edge Functions: verde responde, rojo no.
///
/// Reemplaza al aviso de texto con el modo activo. Al operar siempre contra
/// Supabase, el modo dejó de ser información útil y lo único que importa de un
/// vistazo es si hay servidor al otro lado.
class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool?>(
    valueListenable: ConnectionStatus.isOnline,
    builder: (context, online, _) {
      final (color, label) = switch (online) {
        true => (Nothing.ok, 'Conectado'),
        false => (const Color(0xFFDC2626), 'Sin conexión con el servidor'),
        null => (Nothing.muted, 'Comprobando conexión'),
      };

      return Tooltip(
        message: label,
        child: Semantics(
          label: label,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 7,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Decide entre login y app según haya sesión de Supabase.
///
/// Solo el modo cloud exige sesión, porque es el proyecto que firma el JWT.
/// Simulación no habla con el backend, y túnel y red local apuntan a una
/// instancia que valida con otro secreto, así que ahí manda el token manual.
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
      if (mode != BackendMode.cloud) return _eventSelection;

      final auth = _authOrNull();
      // Supabase sin inicializar (pruebas de widget): se sigue con el token
      // manual de BackendConfig, que es el comportamiento previo al login.
      if (auth == null) return _eventSelection;

      return StreamBuilder<AuthState>(
        stream: auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.data?.session ?? auth.currentSession;
          return session == null ? const LoginScreen() : _eventSelection;
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
      actions: const [_TopBarActions()],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Nothing.gutter,
          8,
          Nothing.gutter,
          Nothing.gutter,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Reveal(child: SectionLabel('01', 'Hackathon')),
            const SizedBox(height: 20),
            Reveal(step: 1, child: Text('INICIO', style: Nothing.display(46))),
            const SizedBox(height: 14),
            const Reveal(
              step: 2,
              child: Text(
                'Selecciona una operación para continuar.',
                style: Nothing.body,
              ),
            ),
            const SizedBox(height: 32),
            const RevealLine(step: 3),
            Reveal(
              step: 3,
              child: _ActionCard(
                index: '01',
                title: 'Registro',
                description:
                    'Escanea el QR del equipo y escribe sus tarjetas NFC.',
                glyph: DotGlyphs.qr,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const RegistrationScreen(),
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
            ),
            const RevealLine(step: 4),
            Reveal(
              step: 4,
              child: _ActionCard(
                index: '02',
                title: 'Eventos',
                description:
                    'Check-in y cena el viernes; desayuno, comida y check-out el sábado.',
                glyph: DotGlyphs.nfc,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EventsScreen(),
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
            ),
            const RevealLine(step: 4),
            const Spacer(),
            const Reveal(
              step: 4,
              child: DotField(columns: 16, rows: 3, dot: 3, gap: 8),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Hoja de configuración de conexión.
///
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Registro de equipo'),
      backgroundColor: Colors.transparent,
      actions: const [_TopBarActions()],
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
      padding: const EdgeInsets.fromLTRB(
        Nothing.gutter,
        8,
        Nothing.gutter,
        Nothing.gutter,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Reveal(child: SectionLabel('01', 'Equipo')),
          const SizedBox(height: 20),
          Reveal(
            step: 1,
            child: Text('ESCANEA\nEL QR', style: Nothing.display(46)),
          ),
          const SizedBox(height: 14),
          Reveal(
            step: 2,
            child: Text(
              isSimulation
                  ? 'El código identifica el equipo y permite confirmar a todos sus integrantes.'
                  : 'Apunta con la cámara al código QR del equipo.',
              style: Nothing.body,
            ),
          ),
          const SizedBox(height: 40),
          Reveal(
            step: 3,
            child: Center(
              child: DotMatrix(
                DotGlyphs.qr,
                dot: 11,
                gap: 6,
                color: Nothing.ink,
              ),
            ),
          ),
          const SizedBox(height: 40),
          if (_errorMessage != null) ...[
            Notice(message: _errorMessage!),
            const SizedBox(height: 24),
          ],
          if (isSimulation)
            Reveal(
              step: 4,
              child: PrimaryAction(
                label: 'Simular lectura de QR',
                icon: Icons.qr_code_scanner,
                onPressed: _loadSimulatedTeam,
              ),
            )
          else
            Reveal(
              step: 4,
              child: PrimaryAction(
                // Bloqueado mientras se consulta el equipo, para que un
                // segundo escaneo no pise al primero.
                label: _isLoading
                    ? 'Consultando equipo'
                    : 'Abrir cámara y escanear QR',
                icon: Icons.camera_alt_rounded,
                busy: _isLoading,
                onPressed: _openCameraScanner,
              ),
            ),
        ],
      ),
    );
  }

  Widget _teamDetails() => ListView(
    key: const ValueKey('team-details'),
    padding: const EdgeInsets.all(20),
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Expanded(child: SectionLabel('02', 'Equipo confirmado')),
          DotCircle(cells: 11, dot: 3, gap: 4, color: Nothing.ok, hollow: true),
        ],
      ),
      const SizedBox(height: 18),
      Text(_teamName, style: Nothing.display(36)),
      const SizedBox(height: 24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          DisplayNumber(
            value: '${_participants.length}'.padLeft(2, '0'),
            caption: 'Integrantes',
            size: 46,
          ),
          const SizedBox(width: 36),
          DisplayNumber(
            value: '${_writtenParticipantIds.length}'.padLeft(2, '0'),
            caption: 'Credenciales',
            size: 46,
            color: _writtenParticipantIds.length >= _participants.length
                ? Nothing.ok
                : Nothing.ink,
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _teamLoaded = false),
            child: const Text(
              'CAMBIAR QR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: Nothing.ink,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
      const Text(
        'Escribe una tarjeta individual por cada integrante.',
        style: Nothing.body,
      ),
      const SizedBox(height: 20),
      const Hairline(),
      ..._participants.indexed.map((entry) {
        final p = entry.$2;
        final isWritten =
            _writtenParticipantIds.contains(p.id) ||
            _writtenParticipantIds.contains(entry.$1.toString());
        return _ParticipantRow(
          index: '${entry.$1 + 1}'.padLeft(2, '0'),
          name: p.fullName,
          written: isWritten,
          nfcToken: p.nfcToken,
          onWrite: () => _writeCard(p, entry.$1),
        );
      }),
      const SizedBox(height: 24),
      if (_writtenParticipantIds.length >= _participants.length &&
          _participants.isNotEmpty)
        const Notice(
          tone: NoticeTone.ok,
          label: 'Equipo registrado',
          message: 'Todas las credenciales del equipo están activas.',
        ),
    ],
  );

  Future<void> _writeCard(StaffParticipant participant, int index) async {
    final isSimulation = BackendConfig.isSimulation;
    bool isSubmitting = false;
    String? localError;

    // showModalBottomSheet se resuelve en cuanto la hoja empieza a cerrarse,
    // pero su contenido sigue montado durante la animación. Sin esta marca,
    // una emisión que respondiera en ese momento arrancaría una escritura que
    // ya nadie cancelaría.
    var sheetOpen = true;

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
              const Icon(Icons.nfc_rounded, size: 52, color: Nothing.ink),
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
                style: const TextStyle(color: Nothing.muted),
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
                          if (!sheetOpen || !modalContext.mounted) return;
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
                                .writeTextPayload(
                                  payload,
                                  webUrl: NfcService.cardUrl(
                                    payload,
                                    event: NfcCardEvent.hackathon,
                                  ),
                                );
                            if (!sheetOpen || !modalContext.mounted) return;
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
                                  backgroundColor: Nothing.ok,
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
    sheetOpen = false;

    // El sheet se puede descartar mientras el lector espera la tarjeta. Sin
    // este cierre la sesión quedaría abierta y la siguiente tarjeta que se
    // acercara se escribiría con la credencial de este participante.
    await const NfcService().cancel();
  }
}

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  /// Accesos del hackathon final por día: el viernes la llegada y la cena; el
  /// sábado el desayuno, la comida y la salida.
  static const _days = [
    (
      'Viernes',
      [
        _EventOption(
          'Check-in',
          'Registra la llegada del participante.',
          Icons.login_rounded,
          glyph: DotGlyphs.checkin,
          code: 'checkin',
        ),
        _EventOption(
          'Cena',
          'Valida una entrada a la cena.',
          Icons.dinner_dining_outlined,
          glyph: DotGlyphs.dinner,
          code: 'cena',
        ),
      ],
    ),
    (
      'Sábado',
      [
        _EventOption(
          'Desayuno',
          'Valida una entrada al desayuno.',
          Icons.breakfast_dining_outlined,
          glyph: DotGlyphs.breakfast,
          code: 'desayuno',
        ),
        _EventOption(
          'Comida',
          'Valida una entrada a la comida.',
          Icons.restaurant_outlined,
          glyph: DotGlyphs.lunch,
          code: 'comida',
        ),
        _EventOption(
          'Check-out',
          'Registra la salida del participante.',
          Icons.logout_rounded,
          glyph: DotGlyphs.checkout,
          code: 'checkout',
        ),
      ],
    ),
  ];

  /// Una cabecera por día y, debajo, sus accesos numerados de corrido.
  List<Widget> _accessCards(BuildContext context) {
    final cards = <Widget>[];
    var number = 0;
    for (final (day, events) in _days) {
      cards.add(
        Reveal(
          step: 3 + number,
          child: Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 4),
            child: Text(day.toUpperCase(), style: Nothing.label),
          ),
        ),
      );
      for (final event in events) {
        cards
          ..add(
            Reveal(
              step: 3 + number,
              child: _ActionCard(
                index: '0${number + 1}',
                title: event.name,
                description: event.description,
                glyph: event.glyph,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => EventScanScreen(event: event),
                  ),
                ),
              ),
            ),
          )
          ..add(RevealLine(step: 3 + number));
        number++;
      }
    }
    return cards;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Eventos'),
      backgroundColor: Colors.transparent,
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Nothing.gutter,
          8,
          Nothing.gutter,
          Nothing.gutter,
        ),
        child: ListView(
          children: [
            Reveal(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(child: SectionLabel('02', 'Accesos')),
                  DotCircle(cells: 11, dot: 3, gap: 4, color: Nothing.border),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Reveal(
              step: 1,
              child: Text('SELECCIONA\nUN EVENTO', style: Nothing.display(40)),
            ),
            const SizedBox(height: 14),
            const Reveal(
              step: 2,
              child: Text(
                'Cada opción abre el lector NFC para ese momento.',
                style: Nothing.body,
              ),
            ),
            const SizedBox(height: 32),
            const RevealLine(step: 3),
            ..._accessCards(context),
          ],
        ),
      ),
    ),
  );
}

/// Inicio de SITEC: el registro de asistentes y los dos días del evento.
///
/// Sigue la forma del inicio del hackathon, pero los accesos se agrupan por
/// día: el staff elige primero la jornada y así no valida la comida del jueves
/// en el punto del viernes.
class SitecScreen extends StatelessWidget {
  const SitecScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: const [_TopBarActions()],
    ),
    body: SafeArea(
      // Lista y no columna: con tres filas, en un móvil pequeño la columna se
      // quedaría sin alto y se desbordaría.
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Nothing.gutter,
          8,
          Nothing.gutter,
          Nothing.gutter,
        ),
        children: [
          const Reveal(child: SectionLabel('02', 'SITEC')),
          const SizedBox(height: 20),
          Reveal(step: 1, child: Text('INICIO', style: Nothing.display(46))),
          const SizedBox(height: 14),
          const Reveal(
            step: 2,
            child: Text(
              'Elige el día y después el punto de acceso.',
              style: Nothing.body,
            ),
          ),
          const SizedBox(height: 32),
          const RevealLine(step: 3),
          Reveal(
            step: 3,
            child: _ActionCard(
              index: '01',
              title: 'Registro',
              description: 'Busca a cada asistente y escribe su tarjeta NFC.',
              glyph: DotGlyphs.person,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const _SitecRegistrationScreen(),
                ),
              ),
            ),
          ),
          const RevealLine(step: 3),
          ..._sitecDays.indexed.expand((entry) {
            final index = '0${entry.$1 + 2}';
            return [
              Reveal(
                step: 4 + entry.$1,
                child: _ActionCard(
                  index: index,
                  title: entry.$2.name,
                  description: entry.$2.summary,
                  glyph: entry.$2.glyph,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          _SitecDayScreen(day: entry.$2, index: index),
                    ),
                  ),
                ),
              ),
              RevealLine(step: 4 + entry.$1),
            ];
          }),
          const SizedBox(height: 36),
          const Reveal(
            step: 5,
            child: DotField(columns: 16, rows: 3, dot: 3, gap: 8),
          ),
        ],
      ),
    ),
  );
}

/// Puntos de acceso de un día de SITEC. Cada punto abre el lector NFC.
class _SitecDayScreen extends StatelessWidget {
  const _SitecDayScreen({required this.day, required this.index});

  final _SitecDay day;

  /// Número del día en el inicio de SITEC: la etiqueta repite el de la fila
  /// que se pulsó.
  final String index;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(day.name), backgroundColor: Colors.transparent),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Nothing.gutter,
          8,
          Nothing.gutter,
          Nothing.gutter,
        ),
        child: ListView(
          children: [
            Reveal(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SectionLabel(index, 'SITEC · Accesos')),
                  DotMatrix(day.glyph, dot: 3, gap: 1.5, color: Nothing.border),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Reveal(
              step: 1,
              child: Text(day.name.toUpperCase(), style: Nothing.display(46)),
            ),
            const SizedBox(height: 14),
            const Reveal(
              step: 2,
              child: Text(
                'Cada punto abre el lector NFC para ese momento del día.',
                style: Nothing.body,
              ),
            ),
            const SizedBox(height: 32),
            const RevealLine(step: 3),
            ...day.points.indexed.expand(
              (entry) => [
                Reveal(
                  step: 3 + entry.$1,
                  child: _ActionCard(
                    index: '0${entry.$1 + 1}',
                    title: entry.$2.name,
                    description: entry.$2.description,
                    glyph: entry.$2.glyph,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EventScanScreen(event: entry.$2),
                      ),
                    ),
                  ),
                ),
                RevealLine(step: 3 + entry.$1),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Registro de SITEC: los asistentes ya están cargados, así que aquí solo se
/// busca a cada uno por su nombre y se escribe su tarjeta.
class _SitecRegistrationScreen extends StatefulWidget {
  const _SitecRegistrationScreen();

  @override
  State<_SitecRegistrationScreen> createState() =>
      _SitecRegistrationScreenState();
}

class _SitecRegistrationScreenState extends State<_SitecRegistrationScreen> {
  static const List<SitecAsistente> _simulatedAsistentes = [
    SitecAsistente(id: 'sim-sitec-1', fullName: 'Ana Torres'),
    SitecAsistente(id: 'sim-sitec-2', fullName: 'Jorge Salas'),
    SitecAsistente(id: 'sim-sitec-3', fullName: 'Marta Ruiz'),
    SitecAsistente(id: 'sim-sitec-4', fullName: 'Sofía Treviño'),
  ];

  final TextEditingController _searchController = TextEditingController();
  List<SitecAsistente> _asistentes = const [];

  /// Asistentes con la tarjeta ya escrita, según el backend o en esta sesión.
  final Set<String> _issuedIds = <String>{};

  /// Tarjetas escritas desde este teléfono. Una recarga no las borra aunque el
  /// backend aún no las tenga: la confirmación pudo fallar o llegar después.
  final Set<String> _writtenHere = <String>{};
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // UnderlineField no avisa de cada letra; el filtro escucha al controlador.
    _searchController.addListener(() => setState(() {}));
    if (BackendConfig.isSimulation) {
      _asistentes = _simulatedAsistentes;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool fromRefresh = false}) async {
    // Al tirar para recargar ya hay un indicador: el spinner propio solo sale
    // en la primera carga o al pulsar «Reintentar».
    final firstLoad = _asistentes.isEmpty;
    setState(() => _isLoading = firstLoad && !fromRefresh);

    final res = await StaffBackendService().listSitecAsistentes();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.success) {
        _errorMessage = null;
        _asistentes = res.asistentes;
        _issuedIds
          ..clear()
          ..addAll(
            res.asistentes.where((a) => a.nfcIssuedAt != null).map((a) => a.id),
          )
          ..addAll(_writtenHere);
      } else if (firstLoad) {
        _errorMessage =
            res.errorMessage ??
            'No se pudo cargar la lista de asistentes (${res.statusCode}).';
      }
    });

    // Si falla una recarga, la lista que ya había sigue siendo útil: no se
    // tapa con el error, solo se avisa.
    if (!res.success && !firstLoad) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'No se pudo actualizar la lista.'),
        ),
      );
    }
  }

  /// Asistentes cuyo nombre contiene todas las palabras buscadas, en cualquier
  /// orden y sin distinguir tildes ni mayúsculas.
  List<SitecAsistente> get _matches {
    final words = _normalize(
      _searchController.text,
    ).split(' ').where((word) => word.isNotEmpty);
    if (words.isEmpty) return _asistentes;
    return _asistentes.where((a) {
      final name = _normalize(a.fullName);
      return words.every(name.contains);
    }).toList();
  }

  /// En la mesa nadie teclea «Peña» o «Jesús» con su tilde, y la lista trae
  /// nombres escritos de las dos maneras.
  static String _normalize(String text) {
    const accented = 'áàäâéèëêíìïîóòöôúùüûñ';
    const plain = 'aaaaeeeeiiiioooouuuun';
    final buffer = StringBuffer();
    for (final char in text.toLowerCase().split('')) {
      final i = accented.indexOf(char);
      buffer.write(i == -1 ? char : plain[i]);
    }
    return buffer
        .toString()
        // Tildes sueltas, por si algún nombre llegó como letra + acento.
        .replaceAll(RegExp('[\u0300-\u036f]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _writeCard(SitecAsistente asistente) async {
    final result = await _showWriteSheet(asistente);
    if (!result.written || !mounted) return;

    setState(() {
      _issuedIds.add(asistente.id);
      _writtenHere.add(asistente.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.saved
              ? 'Tarjeta de ${asistente.fullName} escrita.'
              // La tarjeta funciona igual; solo falta que el registro la cuente.
              : 'Tarjeta de ${asistente.fullName} escrita, pero no se guardó '
                    'en el servidor: en otros teléfonos aparecerá pendiente.',
        ),
        backgroundColor: result.saved ? Nothing.ok : null,
      ),
    );
  }

  /// Emite la credencial en el backend, la escribe en la tarjeta que se
  /// acerque y confirma la escritura. [written] dice si la tarjeta quedó
  /// escrita y [saved], si el backend lo registró.
  Future<({bool written, bool saved})> _showWriteSheet(
    SitecAsistente asistente,
  ) async {
    final isSimulation = BackendConfig.isSimulation;
    var isSubmitting = false;
    String? localError;

    // showModalBottomSheet se resuelve en cuanto la hoja empieza a cerrarse,
    // pero su contenido sigue montado durante la animación. Sin esta marca,
    // una emisión que respondiera en ese momento arrancaría una escritura que
    // ya nadie cancelaría.
    var sheetOpen = true;

    // Confirmación en curso de una tarjeta ya escrita. Si la hoja se cierra a
    // mano mientras viaja, la tarjeta cuenta igual.
    Future<IssueNfcResult>? confirmation;

    final result = await showModalBottomSheet<({bool written, bool saved})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            Nothing.gutter,
            8,
            Nothing.gutter,
            MediaQuery.of(modalContext).viewInsets.bottom + 34,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('NFC', 'Escribir tarjeta'),
              const SizedBox(height: 16),
              Text(asistente.fullName, style: Nothing.display(30)),
              const SizedBox(height: 10),
              Text(
                isSimulation
                    ? 'Acerca una tarjeta NFC vacía al teléfono.'
                    : 'Se emite su credencial y después hay que acercar una '
                          'tarjeta NFC escribible.',
                style: Nothing.body,
              ),
              if (localError != null) ...[
                const SizedBox(height: 18),
                Notice(tone: NoticeTone.danger, message: localError!),
              ],
              const SizedBox(height: 24),
              PrimaryAction(
                // Etiquetas cortas: PrimaryAction no recorta el texto y en un
                // móvil estrecho una larga se sale del botón.
                label: isSimulation
                    ? 'Simular escritura'
                    : isSubmitting
                    ? 'Escribiendo'
                    : 'Escribir tarjeta',
                icon: Icons.nfc_rounded,
                busy: isSubmitting,
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (isSimulation) {
                          Navigator.pop(sheetContext, (
                            written: true,
                            saved: true,
                          ));
                          return;
                        }
                        setModalState(() {
                          isSubmitting = true;
                          localError = null;
                        });

                        final res = await StaffBackendService().issueSitecNfc(
                          asistente.id,
                        );
                        if (!sheetOpen || !modalContext.mounted) return;
                        final payload = res.payload?.trim() ?? '';
                        if (!res.success || payload.isEmpty) {
                          setModalState(() {
                            isSubmitting = false;
                            localError = res.success
                                ? 'El servidor no devolvió un payload NFC válido.'
                                : res.errorMessage ??
                                      'Error al emitir la tarjeta NFC.';
                          });
                          return;
                        }

                        final writeResult = await const NfcService()
                            .writeTextPayload(
                              payload,
                              webUrl: NfcService.cardUrl(
                                payload,
                                event: NfcCardEvent.sitec,
                              ),
                            );
                        if (!sheetOpen || !modalContext.mounted) return;
                        if (writeResult.success) {
                          BackendConfig.lastIssuedNfcToken = res.nfcToken ?? '';
                          // Solo ahora cuenta como tarjeta escrita en el
                          // registro. Si no se guarda, la tarjeta funciona igual.
                          final pending = StaffBackendService().issueSitecNfc(
                            asistente.id,
                            written: true,
                          );
                          confirmation = pending;
                          final confirm = await pending;
                          if (!sheetOpen || !sheetContext.mounted) return;
                          Navigator.pop(sheetContext, (
                            written: true,
                            saved: confirm.success,
                          ));
                          return;
                        }
                        setModalState(() {
                          isSubmitting = false;
                          // Cancelar la escritura no es un error que mostrar.
                          if (!writeResult.cancelled) {
                            localError =
                                writeResult.errorMessage ??
                                'No se pudo escribir la tarjeta NFC.';
                          }
                        });
                      },
              ),
            ],
          ),
        ),
      ),
    );
    sheetOpen = false;
    // El sheet se puede descartar mientras el lector espera la tarjeta. Sin
    // este cierre la sesión quedaría abierta y la siguiente tarjeta que se
    // acercara se escribiría con la credencial de este asistente. Va justo al
    // cerrarse la hoja, antes de esperar una confirmación: después podría
    // cortar otra sesión NFC que ya no es la suya.
    await const NfcService().cancel();
    if (result != null) return result;

    final pendingConfirmation = confirmation;
    if (pendingConfirmation != null) {
      final confirm = await pendingConfirmation;
      return (written: true, saved: confirm.success);
    }
    return (written: false, saved: false);
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final query = _searchController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
        backgroundColor: Colors.transparent,
        actions: const [_TopBarActions()],
      ),
      body: SafeArea(
        // Deslizar hacia abajo recarga: con dos teléfonos en la mesa, cada uno
        // ve así las tarjetas que escribió el otro.
        child: RefreshIndicator(
          color: Nothing.ink,
          onRefresh: BackendConfig.isSimulation
              ? () async {}
              : () => _load(fromRefresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              Nothing.gutter,
              8,
              Nothing.gutter,
              Nothing.gutter,
            ),
            children: [
              const Reveal(child: SectionLabel('01', 'Registro SITEC')),
              const SizedBox(height: 20),
              Reveal(
                step: 1,
                child: Text('REGISTRO', style: Nothing.display(46)),
              ),
              const SizedBox(height: 14),
              const Reveal(
                step: 2,
                child: Text(
                  'Busca al asistente por su nombre y escribe su tarjeta.',
                  style: Nothing.body,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  DisplayNumber(
                    value: '${_asistentes.length}'.padLeft(2, '0'),
                    caption: 'Asistentes',
                    size: 46,
                  ),
                  const SizedBox(width: 36),
                  DisplayNumber(
                    value: '${_issuedIds.length}'.padLeft(2, '0'),
                    caption: 'Tarjetas',
                    size: 46,
                    color:
                        _asistentes.isNotEmpty &&
                            _issuedIds.length >= _asistentes.length
                        ? Nothing.ok
                        : Nothing.ink,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              UnderlineField(
                label: 'Buscar asistente',
                controller: _searchController,
                textInputAction: TextInputAction.search,
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Nothing.ink,
                    ),
                  ),
                )
              else if (_errorMessage != null) ...[
                Notice(
                  tone: NoticeTone.danger,
                  label: 'Sin lista',
                  message: _errorMessage!,
                ),
                const SizedBox(height: 16),
                SecondaryAction(
                  label: 'Reintentar',
                  icon: Icons.refresh_rounded,
                  onPressed: _load,
                ),
              ] else if (matches.isEmpty)
                Text(
                  _asistentes.isEmpty
                      ? 'Todavía no hay asistentes cargados.'
                      : 'Nadie coincide con «$query».',
                  style: Nothing.body,
                )
              else
                // Sin separador arriba: la línea del buscador ya hace de borde.
                ...matches.indexed.map(
                  (entry) => _ParticipantRow(
                    index: '${entry.$1 + 1}'.padLeft(2, '0'),
                    name: entry.$2.fullName,
                    written: _issuedIds.contains(entry.$2.id),
                    writtenLabel: 'Tarjeta escrita',
                    onWrite: () => _writeCard(entry.$2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Día de SITEC con sus puntos de acceso.
class _SitecDay {
  const _SitecDay(this.name, this.summary, this.glyph, this.points);
  final String name;
  final String summary;
  final List<String> glyph;
  final List<_EventOption> points;
}

/// Puntos de acceso de SITEC, en el orden que pasó la organización para cada
/// día: no es el mismo el jueves que el viernes.
///
/// Cada `code` es un par de columnas en sitec_asistentes (`<code>_en` y
/// `<code>_registrado_por`) y lo valida staff-sitec-scan-nfc.
const _sitecDays = [
  _SitecDay('Jueves', 'Entrada, comida y salida.', DotGlyphs.thursday, [
    _EventOption(
      'Entrada',
      'Registra la llegada del asistente.',
      Icons.login_rounded,
      glyph: DotGlyphs.checkin,
      code: 'jueves_entrada',
      sitecDay: 'Jueves',
    ),
    _EventOption(
      'Comida',
      'Valida una entrada a la comida.',
      Icons.restaurant_outlined,
      glyph: DotGlyphs.lunch,
      code: 'jueves_comida',
      sitecDay: 'Jueves',
    ),
    _EventOption(
      'Salida',
      'Registra la salida del asistente.',
      Icons.logout_rounded,
      glyph: DotGlyphs.checkout,
      code: 'jueves_salida',
      sitecDay: 'Jueves',
    ),
  ]),
  _SitecDay('Viernes', 'Entrada, salida y comida.', DotGlyphs.friday, [
    _EventOption(
      'Entrada',
      'Registra la llegada del asistente.',
      Icons.login_rounded,
      glyph: DotGlyphs.checkin,
      code: 'viernes_entrada',
      sitecDay: 'Viernes',
    ),
    _EventOption(
      'Salida',
      'Registra la salida del asistente.',
      Icons.logout_rounded,
      glyph: DotGlyphs.checkout,
      code: 'viernes_salida',
      sitecDay: 'Viernes',
    ),
    _EventOption(
      'Comida',
      'Valida una entrada a la comida.',
      Icons.restaurant_outlined,
      glyph: DotGlyphs.lunch,
      code: 'viernes_comida',
      sitecDay: 'Viernes',
    ),
  ]),
];

class EventScanScreen extends StatefulWidget {
  const EventScanScreen({super.key, required this.event});
  final _EventOption event;
  @override
  State<EventScanScreen> createState() => _EventScanScreenState();
}

class _EventScanScreenState extends State<EventScanScreen>
    with WidgetsBindingObserver {
  _ScannedParticipant? _participant;
  bool _isLoading = false;

  /// Cierto solo mientras el lector NFC está abierto esperando una tarjeta, no
  /// durante la consulta posterior al backend. El botón usa esta distinción
  /// para ofrecer cancelar únicamente cuando cancelar tiene sentido.
  bool _isWaitingForCard = false;

  /// Evita dos bucles de lectura solapados sobre el mismo lector.
  bool _loopActive = false;

  /// Motivo por el que no se puede leer (sin NFC, NFC apagado). Mientras esté
  /// puesto, la pantalla lo muestra en vez de decir que está lista para leer.
  String? _unavailableMessage;
  bool _isDuplicate = false;
  String? _duplicateTimestamp;
  late final TextEditingController _tokenInputController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tokenInputController = TextEditingController(
      text: BackendConfig.lastIssuedNfcToken.isNotEmpty
          ? BackendConfig.lastIssuedNfcToken
          : 'valid-nfc-token-123',
    );
    // El lector se arma al entrar, no al pulsar el botón. Si esta pantalla no
    // tiene el modo lector exclusivo, Android despacha la tarjeta a cualquier
    // app registrada para NFC y saca al operador de aquí. En iOS no: armarlo
    // abriría la hoja del sistema sin que nadie la haya pedido.
    if (!BackendConfig.isSimulation && NfcService.canStayArmed) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _listenLoop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Si se abandona la pantalla mientras espera una tarjeta hay que cerrar el
    // lector; si no, seguiría capturando tarjetas fuera de esta pantalla.
    unawaited(const NfcService().cancel());
    _tokenInputController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (BackendConfig.isSimulation) return;

    if (state == AppLifecycleState.paused) {
      // Android desarma el modo lector al pausar la actividad. Se cierra la
      // sesión para que el bucle no quede esperando una tarjeta que ya nunca
      // va a llegar por ese lector muerto.
      unawaited(const NfcService().cancel());
    } else if (state == AppLifecycleState.resumed && NfcService.canStayArmed) {
      // Y se rearma al volver: sin esto la pantalla queda muda tras cualquier
      // interrupción y no vuelve a leer nada. En iOS no: la propia hoja de
      // lectura deja la app inactiva (no en pausa) y, al cerrarse, la
      // reanuda, así que rearmar aquí la reabriría sin fin.
      _listenLoop();
    }
  }

  Future<void> _cancelScan() => const NfcService().cancel();

  Future<void> _handleScan() async {
    if (BackendConfig.isSimulation) {
      setState(() {
        _participant = _ScannedParticipant(
          'Ana Torres',
          // SITEC no tiene equipos.
          widget.event.sitecDay == null ? 'Equipo Boreal' : null,
          'PART-00128',
        );
        _isDuplicate = false;
        _duplicateTimestamp = null;
      });
      return;
    }

    await _listenLoop();
  }

  /// Mantiene el lector armado mientras la pantalla siga visible, rearmándolo
  /// después de cada lectura en vez de cerrarlo. Donde el lector no puede
  /// quedarse armado (iOS) hace una sola lectura por llamada.
  Future<void> _listenLoop() async {
    if (_loopActive) return;
    _loopActive = true;
    try {
      while (mounted) {
        setState(() {
          _isLoading = true;
          _isWaitingForCard = true;
          _unavailableMessage = null;
        });

        final nfcResult = await const NfcService().readTextPayload(
          timeout: const Duration(minutes: 10),
        );
        if (!mounted) return;
        setState(() => _isWaitingForCard = false);

        if (nfcResult.cancelled) {
          setState(() => _isLoading = false);
          return;
        }

        if (!nfcResult.success) {
          setState(() {
            _isLoading = false;
            if (nfcResult.unavailable) {
              _unavailableMessage = nfcResult.errorMessage;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                nfcResult.errorMessage ?? 'No se pudo leer la tarjeta NFC.',
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
          // Sin lector no hay nada que rearmar: reintentar al momento repetiría
          // el aviso sin fin y, cuando el fallo llega sin esperar a la
          // plataforma, el bucle no suelta el hilo y congela la app. Se
          // reintenta con el botón o, en Android, al volver a la app.
          if (nfcResult.unavailable || !NfcService.canStayArmed) return;
          // Se rearma: dejar el lector cerrado devolvería la tarjeta al
          // despachador del sistema.
          continue;
        }

        await _processToken(nfcResult.payload!);
        if (!mounted || !NfcService.canStayArmed) return;
      }
    } finally {
      _loopActive = false;
    }
  }

  Future<void> _processToken(String token) async {
    _tokenInputController.text = token;
    final service = StaffBackendService();
    // SITEC valida contra su propia tabla de asistentes, no contra integrantes.
    final res = widget.event.sitecDay == null
        ? await service.scanNfc(nfcToken: token, accessType: widget.event.code)
        : await service.scanSitecNfc(
            nfcToken: token,
            accessType: widget.event.code,
          );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.success) {
        _participant = _ScannedParticipant(
          res.participantName ?? 'Participante',
          res.teamName,
          res.participantId ?? token,
        );
        _isDuplicate = false;
        _duplicateTimestamp = null;
      } else if (res.isDuplicate) {
        _participant = _ScannedParticipant(
          res.participantName ?? 'Participante',
          res.teamName,
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
      title: Text(widget.event.title),
      backgroundColor: Colors.transparent,
      actions: [_TopBarActions()],
    ),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Nothing.gutter,
          8,
          Nothing.gutter,
          Nothing.gutter,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Reveal(
              // En SITEC el día va arriba: en la puerta tiene que quedar claro
              // si se valida el jueves o el viernes.
              child: SectionLabel(
                '01',
                widget.event.sitecDay == null
                    ? 'Lectura NFC'
                    : 'SITEC · ${widget.event.sitecDay}',
              ),
            ),
            const SizedBox(height: 18),
            Reveal(
              step: 1,
              child: Text(
                widget.event.name.toUpperCase(),
                style: Nothing.display(42),
              ),
            ),
            const SizedBox(height: 12),
            Reveal(
              step: 2,
              child: Text(
                widget.event.sitecDay == null
                    ? 'Acerca la tarjeta del participante al teléfono.'
                    : 'Acerca la tarjeta del asistente al teléfono.',
                style: Nothing.body,
              ),
            ),
            if (!BackendConfig.isSimulation) ...[
              const SizedBox(height: 26),
              Reveal(
                step: 2,
                child: UnderlineField(
                  label: 'Última credencial',
                  controller: _tokenInputController,
                  readOnly: true,
                ),
              ),
            ],
            const SizedBox(height: 28),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.base,
                child: _participant == null
                    ? _readerState()
                    : _participantCard(),
              ),
            ),
            const SizedBox(height: 20),
            PrimaryAction(
              label: _isWaitingForCard
                  ? 'Cancelar lectura'
                  : BackendConfig.isSimulation
                  ? 'Simular lectura NFC'
                  : 'Leer tarjeta NFC',
              busy: _isLoading && !_isWaitingForCard,
              icon: Icons.nfc_rounded,
              onPressed: _isWaitingForCard ? _cancelScan : _handleScan,
            ),
          ],
        ),
      ),
    ),
  );

  /// Espera de tarjeta. El barrido en bucle comunica «esto sigue vivo» sin
  /// ocupar texto ni robar atención, que es justo para lo que existe.
  Widget _readerState() => Column(
    key: const ValueKey('reader'),
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // El bucle solo corre mientras se espera tarjeta de verdad. En reposo la
      // matriz va quieta: animar sin motivo gasta batería, distrae a quien
      // está leyendo y deja la pantalla sin asentarse nunca.
      if (_isWaitingForCard)
        AnimatedDotMatrix(
          widget.event.glyph,
          motion: DotMotion.sweep,
          dot: 9,
          gap: 5,
          color: Nothing.ink,
        )
      else
        DotMatrix(widget.event.glyph, dot: 9, gap: 5, color: Nothing.ink),
      const SizedBox(height: 32),
      Text(
        _unavailableMessage != null
            ? 'NFC NO\nDISPONIBLE'
            : _isWaitingForCard
            ? 'ESPERANDO\nTARJETA'
            : 'LISTO PARA\nLEER',
        style: Nothing.display(34),
      ),
      const SizedBox(height: 12),
      Text(
        _unavailableMessage ??
            (defaultTargetPlatform == TargetPlatform.iOS &&
                    !BackendConfig.isSimulation &&
                    !_isWaitingForCard
                // En iOS no se lee nada hasta abrir la hoja con el botón.
                ? 'Pulsa «Leer tarjeta NFC» y acerca la tarjeta a la parte de '
                      'arriba del iPhone.'
                : 'Mantén una sola tarjeta cerca del teléfono.'),
        style: Nothing.body,
      ),
    ],
  );

  /// Resultado de la lectura.
  ///
  /// El código de respuesta es el protagonista: en la puerta se decide por él,
  /// y en cifra grande se lee de un vistazo desde lejos.
  Widget _participantCard() {
    final participant = _participant!;
    final code = _isDuplicate ? '409' : 'OK';
    final caption = _isDuplicate ? 'Duplicado' : 'Acceso válido';
    final tone = _isDuplicate ? Nothing.accent : Nothing.ok;

    return ListView(
      key: const ValueKey('participant'),
      padding: EdgeInsets.zero,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            DotText(code, dot: 7, gap: 4, color: tone),
            const SizedBox(width: 18),
            Expanded(child: Text(caption.toUpperCase(), style: Nothing.label)),
            AnimatedDotMatrix(
              _isDuplicate ? DotGlyphs.cross : DotGlyphs.check,
              motion: DotMotion.reveal,
              dot: 3,
              gap: 1.5,
              color: tone,
            ),
          ],
        ),
        const SizedBox(height: 24),
        // El nombre no va en mayúsculas: es el dato que más rápido hay que
        // leer y las versales lo empeoran.
        Text(participant.name, style: Nothing.display(32)),
        if (participant.team case final team?) ...[
          const SizedBox(height: 6),
          Text(team, style: Nothing.body),
        ],
        const SizedBox(height: 24),
        const Hairline(),
        MetaRow('Evento', widget.event.title),
        const Hairline(),
        MetaRow('Credencial', participant.credential),
        const Hairline(),
        MetaRow(
          'Estado',
          // El literal 'Acceso válido' lo comprueba widget_test.dart.
          _isDuplicate ? 'Ya registrado (409)' : 'Acceso válido',
          valueColor: tone,
        ),
        const Hairline(),
        if (_isDuplicate && _duplicateTimestamp != null) ...[
          const SizedBox(height: 20),
          Notice(
            label: 'Registro previo',
            message: 'Registrado previamente a las $_duplicateTimestamp',
          ),
        ],
        const SizedBox(height: 24),
        SecondaryAction(
          label: 'Leer otra tarjeta',
          icon: Icons.nfc_rounded,
          onPressed: () {
            setState(() => _participant = null);
            // En Android el lector ya está armado; en iOS hay que abrir la
            // hoja del sistema para la siguiente tarjeta.
            if (!BackendConfig.isSimulation && !NfcService.canStayArmed) {
              _listenLoop();
            }
          },
        ),
      ],
    );
  }
}

class _EventOption {
  const _EventOption(
    this.name,
    this.description,
    this.icon, {
    required this.glyph,
    this.code = 'checkin',
    this.sitecDay,
  });
  final String name;
  final String description;
  final IconData icon;

  /// Glifo de puntos propio. Cada acceso se reconoce por su dibujo antes que
  /// por su nombre: en la puerta se elige de un vistazo.
  final List<String> glyph;
  final String code;

  /// Día de SITEC al que pertenece el punto; null en los accesos del
  /// hackathon. Decide también contra qué backend se valida: SITEC tiene su
  /// propia tabla de asistentes.
  final String? sitecDay;

  /// Nombre con su día cuando lo tiene: 'Jueves · Entrada'. En SITEC cada
  /// punto existe en los dos días y solo el día los distingue.
  String get title => sitecDay == null ? name : '$sitecDay · $name';
}

class _ScannedParticipant {
  const _ScannedParticipant(this.name, this.team, this.credential);
  final String name;

  /// Null en SITEC, que no tiene equipos.
  final String? team;
  final String credential;
}

/// Fila de operación. Sin tarjeta: número grande, glifo de puntos y separador,
/// igual que las filas de evento. El área pulsable es alta porque se opera de
/// pie y con prisa.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.index,
    required this.title,
    required this.description,
    required this.glyph,
    required this.onTap,
  });

  final String index;
  final String title;
  final String description;
  final List<String> glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const ink = Nothing.ink;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 54,
              child: Text(
                index,
                style: Nothing.display(34).copyWith(color: ink),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 18),
              child: DotMatrix(glyph, dot: 3, gap: 1.5, color: ink),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: Nothing.display(24).copyWith(color: ink),
                  ),
                  const SizedBox(height: 8),
                  Text(description, style: Nothing.body),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: Text(
                '→',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Integrante del equipo. Fila editorial con separador, sin tarjeta ni avatar:
/// la sección 15 de DESIGN.md desaconseja las fotos de perfil circulares.
class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.index,
    required this.name,
    required this.written,
    this.nfcToken,
    this.writtenLabel = 'Credencial activa',
    required this.onWrite,
  });

  final String index;
  final String name;
  final bool written;
  final String? nfcToken;

  /// Texto bajo el nombre cuando [written] es true.
  final String writtenLabel;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                index,
                style: Nothing.meta.copyWith(color: Nothing.muted),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Nothing.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    // Qué significa `written` lo decide quien usa la fila: en
                    // el hackathon sale de `nfc_activa` (credencial emitida);
                    // en SITEC, de una tarjeta escrita (confirmada en el
                    // backend o escrita en esta sesión).
                    written ? writtenLabel : 'Pendiente de escribir',
                    style: Nothing.label.copyWith(
                      color: written ? Nothing.ok : Nothing.muted,
                    ),
                  ),
                ],
              ),
            ),
            // El botón nunca se oculta: si alguien pierde la tarjeta hay que
            // poder reescribirla sin volver a escanear el QR del equipo.
            TextButton(
              onPressed: onWrite,
              child: Text(
                written ? 'REESCRIBIR' : 'ESCRIBIR NFC',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Nothing.ink,
                ),
              ),
            ),
          ],
        ),
      ),
      const Hairline(),
    ],
  );
}

class _Participant {
  const _Participant(this.name);
  final String name;
}

/// Estilo de los botones del sheet de escritura. El resto de la app usa
/// PrimaryAction; aquí se conserva el estilo suelto porque los botones viven
/// dentro de un StatefulBuilder con su propio estado de envío.
final _primaryButtonStyle = FilledButton.styleFrom(
  backgroundColor: Nothing.ink,
  foregroundColor: Colors.white,
  elevation: 0,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(4)),
  ),
  minimumSize: const Size.fromHeight(56),
  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
);
