import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/run_state.dart';
import 'game/highway_game.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
  ]);
  runApp(const DesertApp());
}

class DesertApp extends StatelessWidget {
  const DesertApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Desert Highway',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff43b9aa), brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xff171c20),
      useMaterial3: true,
    ),
    home: const BattleScreen(),
  );
}

class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});
  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> with WidgetsBindingObserver {
  HighwayGame game = HighwayGame();
  int? pointer;
  double pressX = 0;
  double startX = 500;
  final focus = FocusNode();
  final pressed = <LogicalKeyboardKey>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void pause() {
    pointer = null;
    pressed.clear();
    game.pauseBattle();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) pause();
  }

  void restart() {
    final previous = game;
    setState(() {
      game = HighwayGame();
      pointer = null;
      pressed.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => previous.close());
    focus.requestFocus();
  }

  KeyEventResult onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final relevant = {
      LogicalKeyboardKey.keyA, LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.space, LogicalKeyboardKey.escape,
    };
    if (!relevant.contains(key)) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      pressed.remove(key);
    } else {
      pressed.add(key);
    }
    if (event is KeyDownEvent &&
        (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.escape)) {
      if (game.run.playing) {
        pause();
      } else {
        game.resumeBattle();
      }
    }
    final left = pressed.contains(LogicalKeyboardKey.keyA) ||
        pressed.contains(LogicalKeyboardKey.arrowLeft);
    final right = pressed.contains(LogicalKeyboardKey.keyD) ||
        pressed.contains(LogicalKeyboardKey.arrowRight);
    game.keyboardDirection = (right ? 1.0 : 0.0) - (left ? 1.0 : 0.0);
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    game.close();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Focus(
        focusNode: focus,
        autofocus: true,
        onKeyEvent: onKey,
        onFocusChange: (hasFocus) {
          if (!hasFocus && mounted) pause();
        },
        child: Center(
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: LayoutBuilder(builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Listener(
                    key: const ValueKey('battle-input'),
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) {
                      if (pointer != null || !game.run.playing ||
                          (event.buttons & 1) == 0) {
                        return;
                      }
                      focus.requestFocus();
                      pointer = event.pointer;
                      pressX = event.position.dx;
                      startX = game.targetX;
                    },
                    onPointerMove: (event) {
                      if (pointer != event.pointer) return;
                      game.shiftTarget(startX + game.worldDelta(
                          event.position.dx - pressX, constraints.maxWidth));
                    },
                    onPointerUp: (event) {
                      if (pointer == event.pointer) pointer = null;
                    },
                    onPointerCancel: (event) {
                      if (pointer == event.pointer) pointer = null;
                    },
                    child: GameWidget(
                      key: ObjectKey(game), game: game,
                      loadingBuilder: (_) => const Center(
                          child: CircularProgressIndicator()),
                      errorBuilder: (_, error) => const Center(
                          child: Text('Не удалось запустить игру')),
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: game.revision,
                    builder: (context, _, child) {
                      final state = game.run;
                      final seconds = state.remainingSeconds;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned(
                            top: 8, left: 12, right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              color: const Color(0xe6212b30),
                              child: Row(children: [
                                Expanded(child: Text('HP ${state.health}  ·  Бойцы ${state.soldiers}',
                                    style: const TextStyle(fontWeight: FontWeight.w700))),
                                Text('${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                                Expanded(child: Text('Цели ${state.kills}', textAlign: TextAlign.right)),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Пауза',
                                  onPressed: state.playing ? pause : null,
                                  icon: const Icon(Icons.pause),
                                ),
                              ]),
                            ),
                          ),
                          if (!state.playing)
                            ColoredBox(
                              color: const Color(0xbb10191e),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(switch (state.phase) {
                                      RunPhase.paused => 'Пауза',
                                      RunPhase.won => 'Дорога пройдена',
                                      _ => 'Отряд потерян',
                                    }, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 10),
                                    Text('Уничтожено: ${state.kills}'),
                                    const SizedBox(height: 18),
                                    Wrap(spacing: 12, runSpacing: 12,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        if (state.phase == RunPhase.paused)
                                          FilledButton.icon(
                                            onPressed: () {
                                              game.resumeBattle();
                                              focus.requestFocus();
                                            },
                                            icon: const Icon(Icons.play_arrow),
                                            label: const Text('Продолжить'),
                                          ),
                                        OutlinedButton.icon(
                                          onPressed: restart,
                                          icon: const Icon(Icons.refresh),
                                          label: const Text('Заново'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    ),
  );
}
