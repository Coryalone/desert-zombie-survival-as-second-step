import 'dart:math';
import 'dart:ui';
import 'highway_game.dart';

double perspectiveScale(double y) => 0.14 + 0.86 * (y / 700).clamp(0.0, 1.1);
Offset projectPoint(double x, double y, Size view) {
  final depth = (y / 700).clamp(0.0, 1.1);
  return Offset(view.width / 2 + (x - 500) * view.width / 1000 * perspectiveScale(y),
      view.height * (0.18 + 0.78 * depth * depth));
}

void paintHighway(Canvas canvas, Size view, double time,
    List<CombatBody> bodies, double squadX, int soldiers,
    double hitFlash, double shotClock) {
  final p = Paint();
  void fill(Color color) => p..color = color..style = PaintingStyle.fill;
  fill(const Color(0xff79c8d6));
  canvas.drawRect(Offset.zero & view, p);
  fill(const Color(0xffd5c19a));
  canvas.drawRect(Rect.fromLTWH(0, view.height * 0.18, view.width, view.height), p);
  final mountain = Path()..moveTo(0, view.height * 0.23);
  for (var i = 0; i <= 16; i++) {
    mountain.lineTo(view.width * i / 16,
        view.height * (0.13 + ((i * 7) % 5) * 0.016));
  }
  mountain..lineTo(view.width, view.height * 0.26)
      ..lineTo(0, view.height * 0.26)..close();
  fill(const Color(0xffa99b85));
  canvas.drawPath(mountain, p);

  void polygon(List<Offset> points, Color color) {
    final path = Path()..addPolygon(points, true);
    fill(color);
    canvas.drawPath(path, p);
  }
  // Original procedural scenery: ramps are visual only in stage one.
  for (final side in [-1, 1]) {
    polygon([
      projectPoint(500 + side * 420, 290, view),
      projectPoint(500 + side * 470, 290, view),
      Offset(side < 0 ? 0 : view.width, view.height * 0.5),
      Offset(side < 0 ? 0 : view.width, view.height * 0.6),
    ], const Color(0xff777b79));
  }
  polygon([
    projectPoint(40, 0, view), projectPoint(960, 0, view),
    projectPoint(960, 770, view), projectPoint(40, 770, view),
  ], const Color(0xff656c6c));
  polygon([
    projectPoint(65, 0, view), projectPoint(935, 0, view),
    projectPoint(935, 770, view), projectPoint(65, 770, view),
  ], const Color(0xff424b4e));

  for (final x in [86.0, 914.0]) {
    p..color = const Color(0xffe5e6cb)..strokeWidth = 2;
    canvas.drawLine(projectPoint(x, 0, view), projectPoint(x, 770, view), p);
  }
  for (var i = 0; i < 16; i++) {
    final y = (i * 52 + time * 90) % 820 - 50;
    for (final x in [355.0, 645.0]) {
      final a = projectPoint(x, y, view);
      final b = projectPoint(x, y + 21, view);
      p..color = const Color(0xffe3dbad)
        ..strokeWidth = max(1, perspectiveScale(y) * view.width / 220);
      canvas.drawLine(a, b, p);
    }
    for (final x in [-10.0, 1010.0]) {
      final o = projectPoint(x, y, view);
      final s = perspectiveScale(y) * view.width / 1000;
      fill(const Color(0xff717763));
      canvas.drawOval(Rect.fromCenter(center: o, width: 15 * s, height: 6 * s), p);
      p..color = const Color(0xff547b67)..strokeWidth = 4 * s;
      canvas.drawLine(o, o.translate(0, -19 * s), p);
      canvas.drawLine(o.translate(-7 * s, -12 * s), o.translate(6 * s, -12 * s), p);
    }
  }
  final sorted = bodies.where((b) => !b.spent).toList()
    ..sort((a, b) => a.position.y.compareTo(b.position.y));
  var squadPainted = false;
  void drawSquad() {
    for (var i = 0; i < soldiers; i++) {
      final x = squadX + (i - (soldiers - 1) / 2) * 26;
      _person(canvas, projectPoint(x, 610, view),
          perspectiveScale(610) * view.width / 1000,
          time, zombie: false, flash: hitFlash > 0);
      if (shotClock > 0.29) {
        final o = projectPoint(x, 587, view);
        fill(const Color(0xffffeaa3));
        canvas.drawCircle(o.translate(0, -30 * view.width / 1000),
            4 * view.width / 1000, p);
      }
    }
  }
  for (final body in sorted) {
    if (!squadPainted && body.position.y > 610) {
      drawSquad();
      squadPainted = true;
    }
    final o = projectPoint(body.position.x, body.position.y, view);
    final s = perspectiveScale(body.position.y) * view.width / 1000;
    if (body is ZombieBody) {
      _person(canvas, o, s, time + body.position.x,
          zombie: true, flash: body.flash > 0);
    } else if (body is BulletBody) {
      p..color = const Color(0xffffe793)..strokeWidth = max(2, 3 * s);
      canvas.drawLine(o.translate(0, -28 * s), o.translate(0, -40 * s), p);
    }
  }
  if (!squadPainted) drawSquad();
  if (hitFlash > 0) {
    fill(Color.fromRGBO(210, 48, 52, hitFlash * 0.5));
    canvas.drawRect(Offset.zero & view, p);
  }
}

void _person(Canvas canvas, Offset foot, double scale, double time,
    {required bool zombie, required bool flash}) {
  canvas.save();
  canvas.translate(foot.dx, foot.dy);
  canvas.scale(scale);
  final p = Paint()..color = const Color(0x55000000);
  canvas.drawOval(const Rect.fromLTWH(-14, -4, 28, 9), p);
  final walk = sin(time * 9) * (zombie ? 4 : 1.5);
  p..color = const Color(0xff202c35)..strokeWidth = 7..strokeCap = StrokeCap.round;
  canvas.drawLine(const Offset(-5, -15), Offset(-7, walk), p);
  canvas.drawLine(const Offset(5, -15), Offset(7, -walk), p);
  p.color = flash ? const Color(0xfffaf8e7)
      : zombie ? const Color(0xff913d54) : const Color(0xff3686bc);
  canvas.drawRRect(RRect.fromRectAndRadius(
      const Rect.fromLTWH(-10, -36, 20, 24), const Radius.circular(4)), p);
  p..color = zombie ? const Color(0xff96b76d) : const Color(0xffc6d0c8)
    ..strokeWidth = 6;
  canvas.drawLine(const Offset(-10, -30),
      Offset(-15, zombie ? -21 + walk : -38), p);
  canvas.drawLine(const Offset(10, -30),
      Offset(15, zombie ? -21 - walk : -38), p);
  canvas.drawCircle(const Offset(0, -44), 9, p);
  if (zombie) {
    p.color = const Color(0xff27362f);
    canvas.drawRect(const Rect.fromLTWH(-5, -46, 3, 2), p);
    canvas.drawRect(const Rect.fromLTWH(3, -46, 3, 2), p);
  } else {
    p.color = const Color(0xff213f56);
    canvas.drawRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(-10, -53, 20, 10), const Radius.circular(4)), p);
    p..color = const Color(0xff202c35)..strokeWidth = 5;
    canvas.drawLine(const Offset(12, -34), const Offset(12, -51), p);
    p.color = const Color(0xff1f567d);
    canvas.drawRect(const Rect.fromLTWH(-6, -32, 12, 14), p);
  }
  canvas.restore();
}
