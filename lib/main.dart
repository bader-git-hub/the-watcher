import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(
    GameWidget(
      game: TheWatcherGame(),
      overlayBuilderMap: {
        'HUD': (context, game) => HudOverlay(game: game as TheWatcherGame),
        'Profile': (context, game) =>
            ProfileOverlay(game: game as TheWatcherGame),
        'GameOver': (context, game) =>
            GameOverOverlay(game: game as TheWatcherGame),
      },
    ),
  );
}

// ─── DATA ───────────────────────────────────────────────────────────────────

class CitizenData {
  final String name;
  final int age;
  final String job;
  final List<String> inventory;
  final bool isTrulySuspicious; // the hidden truth
  final String suspicionReason; // what the system SAYS
  final String trueReason; // what's actually happening

  CitizenData({
    required this.name,
    required this.age,
    required this.job,
    required this.inventory,
    required this.isTrulySuspicious,
    required this.suspicionReason,
    required this.trueReason,
  });
}

final List<CitizenData> allCitizens = [
  CitizenData(
    name: 'Mara Voss',
    age: 34,
    job: 'Schoolteacher',
    inventory: ['Chalk', 'Children\'s books', 'Red pen'],
    isTrulySuspicious: false,
    suspicionReason: 'Carrying unmarked materials. Unusual route.',
    trueReason: 'Walking to school. Innocent.',
  ),
  CitizenData(
    name: 'Deon Park',
    age: 28,
    job: 'Delivery Driver',
    inventory: ['Packages', 'Scanner', 'Water bottle'],
    isTrulySuspicious: false,
    suspicionReason: 'Repeated stops. Possible dead drops.',
    trueReason: 'His delivery route. Innocent.',
  ),
  CitizenData(
    name: 'Ines Sorel',
    age: 52,
    job: 'Florist',
    inventory: ['Flowers', 'Wire cutters', 'Apron'],
    isTrulySuspicious: false,
    suspicionReason: 'Sharp tools. Frequents public spaces.',
    trueReason: 'Opening her shop. Innocent.',
  ),
  CitizenData(
    name: 'Tomás Reyes',
    age: 19,
    job: 'Student',
    inventory: ['Textbooks', 'Headphones', 'Coffee'],
    isTrulySuspicious: false,
    suspicionReason: 'Loitering. Behavioral pattern flagged.',
    trueReason: 'Waiting for a bus. Innocent.',
  ),
  CitizenData(
    name: 'Vera Kline',
    age: 41,
    job: 'Nurse',
    inventory: ['Medical bag', 'ID badge', 'Pills'],
    isTrulySuspicious: false,
    suspicionReason: 'Carrying controlled substances.',
    trueReason: 'Going to work. Innocent.',
  ),
  CitizenData(
    name: 'Otto Braun',
    age: 67,
    job: 'Retired',
    inventory: ['Newspaper', 'Reading glasses', 'Bread'],
    isTrulySuspicious: false,
    suspicionReason: 'Observing surroundings. Possible lookout.',
    trueReason: 'Morning walk to the bakery. Innocent.',
  ),
];

// ─── GAME ───────────────────────────────────────────────────────────────────

class TheWatcherGame extends FlameGame with TapDetector {
  // Camera feeds (districts)
  final List<String> cameraNames = [
    'CAM 01 — Market District',
    'CAM 02 — Residential Block',
    'CAM 03 — Transit Hub',
    'CAM 04 — Park & Commons',
  ];

  int currentCamera = 0;
  int flaggedCount = 0;
  int correctFlags = 0;
  int wrongFlags = 0;
  int totalFlags = 0;
  double accuracy = 100.0;
  bool isGameOver = false;

  // Citizens on current camera
  List<CitizenComponent> citizens = [];
  CitizenData? selectedCitizen;

  // Colors per camera (atmosphere)
  final List<Color> cameraColors = [
    const Color(0xFF0a1628),
    const Color(0xFF0f1a0f),
    const Color(0xFF1a0f0f),
    const Color(0xFF1a1a0a),
  ];

  static const int maxWrongFlags = 3;
  static const int requiredFlags = 4;

  @override
  Color backgroundColor() => cameraColors[currentCamera];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _spawnCitizens();
    overlays.add('HUD');
  }

  void _spawnCitizens() {
    // Remove old citizens
    for (final c in citizens) {
      c.removeFromParent();
    }
    citizens.clear();

    final rng = Random();
    final shuffled = List<CitizenData>.from(allCitizens)..shuffle(rng);
    final count = 2 + rng.nextInt(2); // 2-3 citizens per camera

    for (int i = 0; i < count; i++) {
      final citizen = CitizenComponent(
        data: shuffled[i],
        startPos: Vector2(
          100 + rng.nextDouble() * (size.x - 200),
          150 + rng.nextDouble() * (size.y - 250),
        ),
        game: this,
      );
      add(citizen);
      citizens.add(citizen);
    }
  }

  void switchCamera(int index) {
    currentCamera = index;
    selectedCitizen = null;
    overlays.remove('Profile');
    _spawnCitizens();
  }

  void selectCitizen(CitizenData data) {
    selectedCitizen = data;
    overlays.add('Profile');
  }

  void closeProfile() {
    selectedCitizen = null;
    overlays.remove('Profile');
  }

  void flagCitizen(CitizenData data, bool flagAsSuspicious) {
    totalFlags++;
    if (flagAsSuspicious) {
      flaggedCount++;
      if (!data.isTrulySuspicious) {
        wrongFlags++;
      } else {
        correctFlags++;
      }
    }

    accuracy = totalFlags == 0
        ? 100.0
        : ((totalFlags - wrongFlags) / totalFlags * 100);

    closeProfile();

    // Remove flagged citizen from scene
    citizens.removeWhere((c) {
      if (c.data == data) {
        c.removeFromParent();
        return true;
      }
      return false;
    });

    if (wrongFlags >= maxWrongFlags) {
      _triggerGameOver();
      return;
    }

    if (flaggedCount >= requiredFlags) {
      _triggerGameOver();
    }
  }

  void _triggerGameOver() {
    isGameOver = true;
    overlays.remove('HUD');
    overlays.remove('Profile');
    overlays.add('GameOver');
  }

  void restart() {
    flaggedCount = 0;
    correctFlags = 0;
    wrongFlags = 0;
    totalFlags = 0;
    accuracy = 100.0;
    isGameOver = false;
    currentCamera = 0;
    selectedCitizen = null;
    overlays.remove('GameOver');
    overlays.add('HUD');
    _spawnCitizens();
  }
}

// ─── CITIZEN COMPONENT ──────────────────────────────────────────────────────

class CitizenComponent extends PositionComponent
    with TapCallbacks, HasGameRef<TheWatcherGame> {
  final CitizenData data;
  final TheWatcherGame game;

  // Walking
  Vector2 velocity = Vector2.zero();
  double _directionTimer = 0;
  bool _highlighted = false;

  static const double speed = 35.0;
  static final Random _rng = Random();

  CitizenComponent({
    required this.data,
    required Vector2 startPos,
    required this.game,
  }) : super(position: startPos, size: Vector2(28, 48), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    _pickNewDirection();
  }

  void _pickNewDirection() {
    final angle = _rng.nextDouble() * 2 * pi;
    velocity = Vector2(cos(angle), sin(angle)) * speed;
    _directionTimer = 2 + _rng.nextDouble() * 3;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _directionTimer -= dt;
    if (_directionTimer <= 0) _pickNewDirection();

    position += velocity * dt;

    // Bounce off edges
    final bounds = game.size;
    if (position.x < 40 || position.x > bounds.x - 40) {
      velocity.x *= -1;
      position.x = position.x.clamp(40, bounds.x - 40);
    }
    if (position.y < 120 || position.y > bounds.y - 60) {
      velocity.y *= -1;
      position.y = position.y.clamp(120, bounds.y - 60);
    }
  }

  @override
  void render(Canvas canvas) {
    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(14, 46), width: 20, height: 6),
      Paint()..color = Colors.black.withOpacity(0.3),
    );

    // Body
    final bodyColor = _highlighted
        ? const Color(0xFFff4d00)
        : const Color(0xFF8888aa);

    // Legs
    canvas.drawRect(
      const Rect.fromLTWH(6, 30, 6, 16),
      Paint()..color = bodyColor.withOpacity(0.8),
    );
    canvas.drawRect(
      const Rect.fromLTWH(16, 30, 6, 16),
      Paint()..color = bodyColor.withOpacity(0.8),
    );

    // Torso
    canvas.drawRect(
      const Rect.fromLTWH(5, 16, 18, 16),
      Paint()..color = bodyColor,
    );

    // Head
    canvas.drawCircle(
      const Offset(14, 10),
      9,
      Paint()..color = const Color(0xFFe8c9a0),
    );

    // Suspicion glow
    if (_highlighted) {
      canvas.drawCircle(
        const Offset(14, 10),
        13,
        Paint()
          ..color = const Color(0xFFff4d00).withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Click indicator dot
    canvas.drawCircle(
      const Offset(14, -8),
      4,
      Paint()..color = const Color(0xFFff4d00).withOpacity(0.7),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    _highlighted = true;
    game.selectCitizen(data);
  }

  void deselect() {
    _highlighted = false;
  }
}

// ─── HUD OVERLAY ────────────────────────────────────────────────────────────

class HudOverlay extends StatefulWidget {
  final TheWatcherGame game;
  const HudOverlay({super.key, required this.game});

  @override
  State<HudOverlay> createState() => _HudOverlayState();
}

class _HudOverlayState extends State<HudOverlay> {
  @override
  Widget build(BuildContext context) {
    final game = widget.game;

    return SafeArea(
      child: Column(
        children: [
          // Top bar
          Container(
            color: Colors.black.withOpacity(0.85),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Title
                const Text(
                  'THE WATCHER',
                  style: TextStyle(
                    color: Color(0xFFff4d00),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: 16),
                // Current camera
                Expanded(
                  child: Text(
                    game.cameraNames[game.currentCamera],
                    style: const TextStyle(
                      color: Color(0xFF666688),
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                // Accuracy
                _StatChip(
                  label: 'ACCURACY',
                  value: '${game.accuracy.toStringAsFixed(0)}%',
                  color: game.accuracy > 60
                      ? const Color(0xFF39ff6a)
                      : const Color(0xFFff3355),
                ),
                const SizedBox(width: 12),
                _StatChip(
                  label: 'FLAGGED',
                  value: '${game.flaggedCount}',
                  color: const Color(0xFFff4d00),
                ),
                const SizedBox(width: 12),
                // Wrong flags warning
                Row(
                  children: List.generate(
                    TheWatcherGame.maxWrongFlags,
                    (i) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.warning_rounded,
                        size: 16,
                        color: i < game.wrongFlags
                            ? const Color(0xFFff3355)
                            : const Color(0xFF333344),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Camera switcher
          Container(
            color: Colors.black.withOpacity(0.7),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: List.generate(
                game.cameraNames.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => game.switchCamera(i));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: game.currentCamera == i
                            ? const Color(0xFFff4d00).withOpacity(0.2)
                            : Colors.transparent,
                        border: Border.all(
                          color: game.currentCamera == i
                              ? const Color(0xFFff4d00)
                              : const Color(0xFF333344),
                        ),
                      ),
                      child: Text(
                        'CAM ${(i + 1).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: game.currentCamera == i
                              ? const Color(0xFFff4d00)
                              : const Color(0xFF555566),
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: game.currentCamera == i
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const Spacer(),

          // Bottom hint
          Container(
            color: Colors.black.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Icon(Icons.mouse, color: Color(0xFF444455), size: 14),
                SizedBox(width: 6),
                Text(
                  'CLICK A CITIZEN TO VIEW PROFILE',
                  style: TextStyle(
                    color: Color(0xFF444455),
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF444455), fontSize: 8, letterSpacing: 2)),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
      ],
    );
  }
}

// ─── PROFILE OVERLAY ────────────────────────────────────────────────────────

class ProfileOverlay extends StatelessWidget {
  final TheWatcherGame game;
  const ProfileOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final citizen = game.selectedCitizen;
    if (citizen == null) return const SizedBox();

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 0, top: 90, bottom: 40),
        decoration: BoxDecoration(
          color: const Color(0xFF0a0a0e).withOpacity(0.97),
          border: const Border(
            left: BorderSide(color: Color(0xFFff4d00), width: 2),
            top: BorderSide(color: Color(0xFF1e1e28)),
            bottom: BorderSide(color: Color(0xFF1e1e28)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: Color(0xFF1e1e28))),
              ),
              child: Row(
                children: [
                  const Text('CITIZEN DOSSIER',
                      style: TextStyle(
                          color: Color(0xFFff4d00),
                          fontSize: 10,
                          letterSpacing: 3)),
                  const Spacer(),
                  GestureDetector(
                    onTap: game.closeProfile,
                    child: const Icon(Icons.close,
                        color: Color(0xFF555566), size: 16),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    citizen.name.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFe8e8f0),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AGE ${citizen.age}  ·  ${citizen.job.toUpperCase()}',
                    style: const TextStyle(
                        color: Color(0xFF666688),
                        fontSize: 10,
                        letterSpacing: 2),
                  ),

                  const SizedBox(height: 16),
                  const _ProfileLabel('INVENTORY'),
                  const SizedBox(height: 6),
                  ...citizen.inventory.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Text('▸ ',
                                style: TextStyle(
                                    color: Color(0xFFff4d00), fontSize: 11)),
                            Text(item,
                                style: const TextStyle(
                                    color: Color(0xFFaaaacc),
                                    fontSize: 12)),
                          ],
                        ),
                      )),

                  const SizedBox(height: 16),
                  const _ProfileLabel('SYSTEM ANALYSIS'),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFff4d00).withOpacity(0.06),
                      border: Border.all(
                          color: const Color(0xFFff4d00).withOpacity(0.2)),
                    ),
                    child: Text(
                      citizen.suspicionReason,
                      style: const TextStyle(
                          color: Color(0xFFff8c66),
                          fontSize: 11,
                          height: 1.5),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'FLAG',
                          sublabel: 'SUSPICIOUS',
                          color: const Color(0xFFff3355),
                          onTap: () => game.flagCitizen(citizen, true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          label: 'CLEAR',
                          sublabel: 'INNOCENT',
                          color: const Color(0xFF39ff6a),
                          onTap: () => game.flagCitizen(citizen, false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileLabel extends StatelessWidget {
  final String text;
  const _ProfileLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          color: Color(0xFF444455), fontSize: 9, letterSpacing: 3),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            Text(sublabel,
                style: TextStyle(
                    color: color.withOpacity(0.6),
                    fontSize: 8,
                    letterSpacing: 2)),
          ],
        ),
      ),
    );
  }
}

// ─── GAME OVER OVERLAY ──────────────────────────────────────────────────────

class GameOverOverlay extends StatelessWidget {
  final TheWatcherGame game;
  const GameOverOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final bool systemWon = game.wrongFlags >= TheWatcherGame.maxWrongFlags;

    return Container(
      color: Colors.black.withOpacity(0.92),
      child: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: const Color(0xFF0a0a0e),
            border: Border.all(
              color: systemWon
                  ? const Color(0xFFff3355)
                  : const Color(0xFF39ff6a),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                systemWon ? 'SYSTEM OVERRIDE' : 'QUOTA MET',
                style: TextStyle(
                  color: systemWon
                      ? const Color(0xFFff3355)
                      : const Color(0xFF39ff6a),
                  fontSize: 11,
                  letterSpacing: 5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                systemWon
                    ? 'TOO MANY\nINNOCENTS\nFLAGGED'
                    : 'SURVEILLANCE\nCOMPLETE',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFe8e8f0),
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                systemWon
                    ? '"You flagged ${game.wrongFlags} innocent citizens.\nThe system has been recalibrated.\nYou have been replaced."'
                    : '"${game.flaggedCount} citizens flagged.\n${game.wrongFlags} were innocent.\nThe system considers this acceptable."',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF666688),
                  fontSize: 12,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 32),

              // Stats
              _StatRow('Total reviewed', '${game.totalFlags}'),
              _StatRow('Flagged', '${game.flaggedCount}'),
              _StatRow('Wrong flags', '${game.wrongFlags}',
                  color: const Color(0xFFff3355)),
              _StatRow('Final accuracy', '${game.accuracy.toStringAsFixed(1)}%',
                  color: game.accuracy > 60
                      ? const Color(0xFF39ff6a)
                      : const Color(0xFFff3355)),

              const SizedBox(height: 32),
              GestureDetector(
                onTap: game.restart,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFff4d00)),
                    color: const Color(0xFFff4d00).withOpacity(0.1),
                  ),
                  child: const Text(
                    'REINITIALIZE SYSTEM',
                    style: TextStyle(
                      color: Color(0xFFff4d00),
                      fontSize: 11,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatRow(this.label, this.value,
      {this.color = const Color(0xFFaaaacc)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: Color(0xFF444455), fontSize: 10, letterSpacing: 2)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
