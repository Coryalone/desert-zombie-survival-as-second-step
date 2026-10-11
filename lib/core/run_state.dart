enum RunPhase { playing, paused, won, lost }

/// Stage-one tuning only; bonuses and adaptive difficulty are not implemented.
class RunState {
  static const duration = 120.0;
  static const healthPerSoldier = 10;
  int health = 30;
  int kills = 0;
  double elapsed = 0;
  RunPhase phase = RunPhase.playing;

  int get soldiers => (health / healthPerSoldier).ceil();
  int get remainingSeconds => (duration - elapsed).clamp(0, duration).ceil();
  bool get playing => phase == RunPhase.playing;

  void damage(int amount) {
    if (!playing || amount <= 0) return;
    health = (health - amount).clamp(0, 30);
    if (health == 0) phase = RunPhase.lost;
  }

  void recordKill() {
    if (playing) kills++;
  }

  /// Called after collisions: lethal damage wins a tie with the survival timer.
  void advance(double seconds) {
    if (!playing || !seconds.isFinite || seconds <= 0) return;
    elapsed = (elapsed + seconds).clamp(0, duration);
    if (elapsed >= duration) phase = RunPhase.won;
  }

  void pause() {
    if (playing) phase = RunPhase.paused;
  }

  void resume() {
    if (phase == RunPhase.paused) phase = RunPhase.playing;
  }
}
