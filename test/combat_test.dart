import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desert_zombie_survival/game/highway_game.dart';

Future<HighwayGame> setupGame() async {
  final game = HighwayGame(spawnEnabled: false);
  game.onGameResize(Vector2(960, 540));
  await game.toBeLoaded();
  await game.ready();
  game.shotClock = 100;
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Flame collisions consume a bullet once and kill with two hits', () async {
    final game = await setupGame();
    final zombie = game.addBody(ZombieBody(game, 500, 300));
    game.addBody(BulletBody(game, 500, 350));
    await game.ready();
    for (var i = 0; i < 30; i++) {
      game.update(1 / 120);
    }
    expect(zombie.health, 1);
    game.addBody(BulletBody(game, 500, zombie.position.y + 45));
    await game.ready();
    for (var i = 0; i < 30; i++) {
      game.update(1 / 120);
    }
    expect(zombie.spent, isTrue);
    expect(game.run.kills, 1);
    game.close();
  });
  test('overlapping zombie damages squad once', () async {
    final game = await setupGame();
    game.addBody(ZombieBody(game, 500, 600));
    await game.ready();
    for (var i = 0; i < 60; i++) {
      game.update(1 / 120);
    }
    expect(game.run.health, 24);
    expect(game.bodies.whereType<ZombieBody>(), isEmpty);
    game.close();
  });
  test('a zombie passing beside the squad causes no damage', () async {
    final game = await setupGame();
    game.addBody(ZombieBody(game, 170, 700));
    await game.ready();
    for (var i = 0; i < 120; i++) {
      game.update(1 / 120);
    }
    expect(game.run.health, 30);
    expect(game.bodies.whereType<ZombieBody>(), isEmpty);
    game.close();
  });
  test('30 and 120 fps advance the same active time', () async {
    final a = await setupGame();
    final b = await setupGame();
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
