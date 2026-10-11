import 'package:flutter_test/flutter_test.dart';
import 'package:desert_zombie_survival/core/run_state.dart';

void main() {
  test('damage crosses soldier thresholds and clamps lethal damage', () {
    final run = RunState();
    run.damage(9);
    expect(run.health, 21);
    expect(run.soldiers, 3);
    run.damage(1);
    expect(run.soldiers, 2);
    run.damage(100);
    expect(run.health, 0);
    expect(run.soldiers, 0);
    expect(run.phase, RunPhase.lost);
  });
  test('pause stops time, damage and scoring', () {
    final run = RunState()..advance(12)..pause();
    run.advance(100);
    run.damage(30);
    run.recordKill();
    expect(run.elapsed, 12);
    expect(run.health, 30);
    expect(run.kills, 0);
    run.resume();
    run.advance(1);
    expect(run.elapsed, 13);
  });
  test('survival ends at 120 seconds and cannot change afterwards', () {
    final run = RunState()..advance(119.5)..advance(1);
    expect(run.phase, RunPhase.won);
    expect(run.elapsed, 120);
    run.damage(30);
    expect(run.health, 30);
  });
  test('lethal hit takes priority over final timer tick', () {
    final run = RunState()..advance(119.99)..damage(30)..advance(0.02);
    expect(run.phase, RunPhase.lost);
  });
}
