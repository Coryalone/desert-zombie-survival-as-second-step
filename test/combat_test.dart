import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flame/game.dart';
import 'package:desert_zombie_survival/game/highway_game.dart';

Future<HighwayGame> setupGame(WidgetTester tester) async {
  final game = HighwayGame(spawnEnabled: false);
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: GameWidget(game: game),
  ));
  await tester.runAsync(() async { await game.toBeLoaded(); });
  await tester.pump();
  await tester.runAsync(() => game.ready());
  game.pauseEngine();
  game.shotClock = 100;
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Flame collisions consume a bullet once and kill with two hits', (tester) async {
    final game = await setupGame(tester);
    final zombie = game.addBody(ZombieBody(game, 500, 300));
    game.addBody(BulletBody(game, 500, 350));
    await tester.runAsync(() => game.ready());
    for (var i = 0; i < 30; i++) {
      game.update(1 / 120);
    }
    expect(zombie.health, 1);
    game.addBody(BulletBody(game, 500, zombie.position.y + 45));
    await tester.runAsync(() => game.ready());
    for (var i = 0; i < 30; i++) {
      game.update(1 / 120);
    }
    expect(zombie.spent, isTrue);
    expect(game.run.kills, 1);
    game.close();
  });
  testWidgets('overlapping zombie damages squad once', (tester) async {
    final game = await setupGame(tester);
    game.addBody(ZombieBody(game, 500, 600));
    await tester.runAsync(() => game.ready());
    for (var i = 0; i < 60; i++) {
      game.update(1 / 120);
    }
    expect(game.run.health, 24);
    expect(game.bodies.whereType<ZombieBody>(), isEmpty);
    game.close();
  });
  testWidgets('a zombie passing beside the squad causes no damage', (tester) async {
    final game = await setupGame(tester);
    game.addBody(ZombieBody(game, 170, 700));
    await tester.runAsync(() => game.ready());
    for (var i = 0; i < 120; i++) {
      game.update(1 / 120);
    }
    expect(game.run.health, 30);
    expect(game.bodies.whereType<ZombieBody>(), isEmpty);
    game.close();
  });
  testWidgets('30 and 120 fps advance the same active time', (tester) async {
    final a = await setupGame(tester);
    final b = await setupGame(tester);
    for (var i = 0; i < 300; i++) {
      a.update(1 / 30);
    }
    for (var i = 0; i < 1200; i++) {
      b.update(1 / 120);
    }
    expect(a.run.elapsed, closeTo(b.run.elapsed, 0.01));
    a.shiftTarget(-10000);
    expect(a.targetX, 120);
    a.shiftTarget(10000);
    expect(a.targetX, 880);
    a.close();
    b.close();
  });
}
