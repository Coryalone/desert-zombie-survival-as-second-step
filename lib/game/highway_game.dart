import 'dart:math';
import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import '../core/run_state.dart';
import 'highway_art.dart';

class HighwayGame extends FlameGame with HasCollisionDetection {
  HighwayGame({int seed = 7, this.spawnEnabled = true}) : random = Random(seed);
  final bool spawnEnabled;
  final Random random;
  final run = RunState();
  final revision = ValueNotifier<int>(0);
  final List<CombatBody> bodies = [];
  late SquadBody squad;
  double targetX = 500;
  double keyboardDirection = 0;
  double accumulator = 0;
  double shotClock = 0;
  double spawnClock = 1.5;
  double notifyClock = 0;
  double hitFlash = 0;
  bool initialized = false;
  bool _closed = false;
  static const step = 1 / 120;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    squad = SquadBody(this);
    await add(squad);
    initialized = true;
  }

  void pauseBattle() {
    run.pause();
    keyboardDirection = 0;
    accumulator = 0;
    publish();
  }

  void resumeBattle() {
    run.resume();
    accumulator = 0;
    publish();
  }

  void publish() {
    if (!_closed) revision.value++;
  }

  void shiftTarget(double value) {
    if (run.playing) targetX = value.clamp(120.0, 880.0);
  }

  double worldDelta(double pixels, double width) =>
      pixels / (width / 1000 * perspectiveScale(610));

  T addBody<T extends CombatBody>(T body) {
    bodies.add(body);
    add(body);
    return body;
  }

  void hurt(int amount) {
    if (!run.playing) return;
    run.damage(amount);
    hitFlash = 0.25;
  }

  @override
  void update(double dt) {
    if (!initialized || _closed) {
      super.update(0);
      return;
    }
    // Small fixed steps prevent fast bullets skipping Flame hitboxes.
    // Do not replay time spent in a suspended tab or after a long stall.
    if (!run.playing) return;
    if (dt > 0.5) {
      pauseBattle();
      return;
    }
    accumulator += dt.clamp(0.0, 0.1);
    while (accumulator >= step && run.playing) {
      targetX = (targetX + keyboardDirection * 430 * step).clamp(120.0, 880.0);
      final distance = targetX - squad.position.x;
      squad.position.x += distance.clamp(-1600 * step, 1600 * step);
      shotClock -= step;
      spawnClock -= step;
      if (shotClock <= 0) {
        shotClock += 0.34;
        for (var i = 0; i < run.soldiers; i++) {
          addBody(BulletBody(this,
              squad.position.x + (i - (run.soldiers - 1) / 2) * 26, 587));
        }
      }
      if (spawnEnabled && spawnClock <= 0) {
        spawnClock += 0.95 + random.nextDouble() * 0.45;
        final lane = random.nextInt(7);
        addBody(ZombieBody(this, 170 + lane * 110.0, 15));
      }
      super.update(step);
      run.advance(step);
      hitFlash = max(0, hitFlash - step);
      accumulator -= step;
      notifyClock += step;
      if (notifyClock >= 0.1 || !run.playing) {
        notifyClock = 0;
        publish();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (canvasSize.x <= 0 || canvasSize.y <= 0) return;
    paintHighway(canvas, Size(canvasSize.x, canvasSize.y),
        run.elapsed, bodies, initialized ? squad.position.x : 500,
        run.soldiers, hitFlash, shotClock);
    super.render(canvas);
  }

  void close() {
    _closed = true;
    pauseEngine();
    revision.dispose();
  }
}

abstract class CombatBody extends PositionComponent with CollisionCallbacks {
  CombatBody(this.battle, Vector2 point, Vector2 dimensions)
      : super(position: point, size: dimensions, anchor: Anchor.center);
  final HighwayGame battle;
  bool spent = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  void retire() {
    if (spent) return;
    spent = true;
    battle.bodies.remove(this);
    removeFromParent();
  }

  // Artwork is projected centrally; hitboxes remain in the simulation plane.
  @override
  void render(Canvas canvas) {}
}

class SquadBody extends PositionComponent {
  SquadBody(this.battle)
      : super(position: Vector2(500, 610),
            size: Vector2(86, 26), anchor: Anchor.center);
  final HighwayGame battle;
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }
  @override
  void update(double dt) {
    super.update(dt);
    size.x = 20 + battle.run.soldiers * 22.0;
  }
}

class ZombieBody extends CombatBody {
  ZombieBody(HighwayGame battle, double x, double y)
      : super(battle, Vector2(x, y), Vector2(30, 28));
  int health = 2;
  double flash = 0;

  void receiveBullet() {
    if (spent || !battle.run.playing) return;
    health--;
    flash = 0.09;
    if (health <= 0) {
      battle.run.recordKill();
      retire();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (spent) return;
    position.y += 64 * dt;
    flash = max(0, flash - dt);
    if (position.y > 730) retire();
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (spent || !battle.run.playing) return;
    if (other is SquadBody) {
      battle.hurt(6);
      retire();
    }
  }
}

class BulletBody extends CombatBody {
  BulletBody(HighwayGame battle, double x, double y)
      : super(battle, Vector2(x, y), Vector2(8, 18));

  @override
  void update(double dt) {
    super.update(dt);
    if (spent) return;
    position.y -= 620 * dt;
    if (position.y < -30) retire();
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (spent || !battle.run.playing) return;
    if (other is ZombieBody && !other.spent) {
      retire();
      other.receiveBullet();
    }
  }
}
