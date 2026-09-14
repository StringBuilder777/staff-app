import 'package:flutter/material.dart';

void main() => runApp(const StaffApp());

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
    home: const HomeScreen(),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
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
            const SizedBox(height: 32),
            _ActionCard(
              title: 'Registro',
              description:
                  'Escanea el QR del equipo y escribe sus tarjetas NFC.',
              icon: Icons.group_outlined,
              primary: true,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RegistrationScreen(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ActionCard(
              title: 'Eventos',
              description: 'Valida asistentes en check-in, comida y desayuno.',
              icon: Icons.event_available_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const EventsScreen()),
              ),
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
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final List<_Participant> _participants = const [
    _Participant('Ana Torres'),
    _Participant('Luis Herrera'),
    _Participant('María López'),
    _Participant('Diego Ramírez'),
  ];
  final Set<int> _written = <int>{};
  bool _teamLoaded = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Registro de equipo'),
      backgroundColor: Colors.transparent,
    ),
    body: SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _teamLoaded ? _teamDetails() : _qrStep(),
      ),
    ),
  );

  Widget _qrStep() => Padding(
    key: const ValueKey('qr-step'),
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Escanea el QR del equipo',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: _Colors.navy,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'El código identifica el equipo y permite confirmar a todos sus integrantes.',
          style: TextStyle(fontSize: 16, color: _Colors.muted),
        ),
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                size: 112,
                color: _Colors.navy,
              ),
              SizedBox(height: 22),
              Text(
                'Cámara lista para leer QR',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ],
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          style: _primaryButtonStyle,
          onPressed: () => setState(() => _teamLoaded = true),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Simular lectura de QR'),
        ),
      ],
    ),
  );

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
        child: const Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Color(0xFFE4F6F3),
              child: Icon(Icons.groups_rounded, color: _Colors.teal, size: 28),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Equipo Boreal',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _Colors.navy,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '4 participantes confirmados',
                    style: TextStyle(color: _Colors.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.verified_rounded, color: _Colors.success),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const Text(
        'Tarjetas de participantes',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _Colors.navy,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Escribe una tarjeta individual por cada integrante.',
        style: TextStyle(color: _Colors.muted),
      ),
      const SizedBox(height: 12),
      ..._participants.indexed.map(
        (entry) => _ParticipantRow(
          participant: entry.$2,
          written: _written.contains(entry.$1),
          onWrite: () => _writeCard(entry.$1),
        ),
      ),
      const SizedBox(height: 18),
      if (_written.length == _participants.length)
        const _SuccessBanner(
          message: 'Equipo registrado y tarjetas verificadas',
        ),
    ],
  );

  Future<void> _writeCard(int index) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.nfc_rounded, size: 52, color: _Colors.teal),
          const SizedBox(height: 12),
          Text(
            'Escribir tarjeta de ${_participants[index].name}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Acerca una tarjeta NFC vacía al teléfono.'),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.pop(sheetContext);
              setState(() => _written.add(index));
            },
            child: const Text('Confirmar escritura simulada'),
          ),
        ],
      ),
    ),
  );
}

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  static const _events = [
    _EventOption(
      'Check-in',
      'Registra la llegada del participante.',
      Icons.login_rounded,
    ),
    _EventOption(
      'Desayuno',
      'Valida una entrada al desayuno.',
      Icons.breakfast_dining_outlined,
    ),
    _EventOption(
      'Comida',
      'Valida una entrada a la comida.',
      Icons.restaurant_outlined,
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.event.name),
      backgroundColor: Colors.transparent,
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
            'Acerca la tarjeta del participante al teléfono.',
            style: TextStyle(color: _Colors.muted, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _participant == null ? _readerState() : _participantCard(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: _primaryButtonStyle,
            onPressed: () => setState(
              () => _participant = const _ScannedParticipant(
                'Ana Torres',
                'Equipo Boreal',
                'PART-00128',
              ),
            ),
            icon: const Icon(Icons.nfc_rounded),
            label: const Text('Simular lectura NFC'),
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
              _InfoRow(label: 'Estado', value: 'Acceso válido', success: true),
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
  const _EventOption(this.name, this.description, this.icon);
  final String name;
  final String description;
  final IconData icon;
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
    required this.participant,
    required this.written,
    required this.onWrite,
  });
  final _Participant participant;
  final bool written;
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
                participant.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _Colors.navy,
                ),
              ),
              Text(
                written ? 'Tarjeta NFC escrita' : 'Pendiente de escribir',
                style: TextStyle(
                  color: written ? _Colors.success : _Colors.muted,
                ),
              ),
            ],
          ),
        ),
        if (written)
          const Icon(Icons.check_circle_rounded, color: _Colors.success)
        else
          TextButton(onPressed: onWrite, child: const Text('Escribir NFC')),
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
