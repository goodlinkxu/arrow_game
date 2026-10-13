import 'dart:math';
import 'package:flutter/material.dart';
import '../models/curve.dart';
import '../models/game_map.dart';

class GamePainter extends CustomPainter {
  final GameMap map;
  final List<GameCurve> curves;
  final double cellSize;
  final Offset offset;
  
  // 🌟【彻底废除外部全局变量】：不再依靠单轨的 id 判定，斩断重绘缓存污染
  final Set<String> logicalExitedIds; 

  GamePainter({
    required this.map,
    required this.curves,
    required this.cellSize,
    required this.offset,
    required this.logicalExitedIds, // 👈 接收当前全盘正在飞走的蛇 ID 集合
  });

  @override
  void paint(Canvas canvas, Size size) {
    final mapPixelWidth = map.width * cellSize;
    final mapPixelHeight = map.height * cellSize;
    final centerX = (size.width - mapPixelWidth) / 2 + offset.dx;
    final centerY = (size.height - mapPixelHeight) / 2 + offset.dy;

    _drawPoints(canvas, centerX, centerY);
    _drawCurves(canvas, centerX, centerY);
  }

  void _drawPoints(Canvas canvas, double centerX, double centerY) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.fill;
    final dotRadius = cellSize * 0.06;

    for (final point in map.validPoints) {
      final cx = centerX + point.x * cellSize;
      final cy = centerY + point.y * cellSize;
      canvas.drawCircle(Offset(cx, cy), dotRadius, paint);
    }
  }

  void _drawCurves(Canvas canvas, double centerX, double centerY) {
    for (final curve in curves) {
      if (curve.isExited) continue;

      // 🌟【铁证如山判定】：只有在这条蛇确实处于飞走集合内，才绘制渐变！其他的一律实色，绝不乱套
      final isLeaving = logicalExitedIds.contains(curve.id);

      if (isLeaving) {
        _drawCurveWithTrail(canvas, curve, centerX, centerY);
      } else {
        _drawSingleCurve(canvas, curve, centerX, centerY);
      }

      _drawArrow(canvas, curve, centerX, centerY);
    }
  }

  void _drawSingleCurve(
      Canvas canvas, GameCurve curve, double centerX, double centerY) {
    final points = curve.points;
    if (points.length < 2) return;

    final paint = Paint()
      ..color = curve.isFailed ? Colors.red : Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize * 0.16 // 加粗，更饱满
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(
      centerX + points.first.x * cellSize,
      centerY + points.first.y * cellSize,
    );

    for (int i = 1; i < points.length; i++) {
      path.lineTo(
        centerX + points[i].x * cellSize,
        centerY + points[i].y * cellSize,
      );
    }

    canvas.drawPath(path, paint);
  }

  void _drawCurveWithTrail(
      Canvas canvas, GameCurve curve, double centerX, double centerY) {
    final points = curve.points;
    if (points.length < 2) return;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];

      final x1 = centerX + p1.x * cellSize;
      final y1 = centerY + p1.y * cellSize;
      final x2 = centerX + p2.x * cellSize;
      final y2 = centerY + p2.y * cellSize;

      final progress = i / (points.length - 1);
      final opacity = 0.15 + progress * 0.85;

      final paint = Paint()
        ..color = Colors.blue.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellSize * 0.16
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  void _drawArrow(
      Canvas canvas, GameCurve curve, double centerX, double centerY) {
    if (curve.points.length < 2) return;

    final head = curve.points.last;
    final prev = curve.points[curve.points.length - 2];

    final headX = centerX + head.x * cellSize;
    final headY = centerY + head.y * cellSize;

    double dx = (head.x - prev.x).toDouble();
    double dy = (head.y - prev.y).toDouble();

    final length = sqrt(dx * dx + dy * dy);
    if (length > 0) {
      dx /= length;
      dy /= length;
    }

    final arrowSize = cellSize * 0.42;
    final paint = Paint()
      ..color = curve.isFailed ? Colors.red[700]! : Colors.blue[700]!
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(headX + dx * arrowSize, headY + dy * arrowSize);
    path.lineTo(
      headX - dy * arrowSize * 0.45 - dx * arrowSize * 0.45,
      headY + dx * arrowSize * 0.45 - dy * arrowSize * 0.45,
    );
    path.lineTo(
      headX + dy * arrowSize * 0.45 - dx * arrowSize * 0.45,
      headY - dx * arrowSize * 0.45 - dy * arrowSize * 0.45,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}