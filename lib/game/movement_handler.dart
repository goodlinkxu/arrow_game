import '../models/point.dart';
import '../models/direction.dart';
import '../models/curve.dart';
import '../models/game_map.dart';

class MovementResult {
  final List<Point> finalPoints;
  final bool success;
  final List<List<Point>> animationFrames;
  final Direction exitDirection;

  const MovementResult({
    required this.finalPoints,
    required this.success,
    required this.animationFrames,
    required this.exitDirection,
  });
}

class MovementHandler {
  /// 处理曲线移动
  static MovementResult moveCurve(
    GameCurve curve,
    GameMap map,
    Set<Point> occupiedPoints,
  ) {
    final direction = curve.direction;
    final points = List<Point>.from(curve.points);
    final animationFrames = <List<Point>>[];

    var currentPoints = List<Point>.from(points);
    bool blocked = false;
    bool exited = false;

    int maxSteps = _calculateMaxSteps(currentPoints, direction, map);

    for (int step = 0; step < maxSteps; step++) {
      final head = currentPoints.last;
      final newHead = Point(head.x + direction.dx, head.y + direction.dy);

      // 检查是否遇到其他曲线
      if (_isBlockedByOther(newHead, currentPoints, occupiedPoints, map)) {
        blocked = true;
        break;
      }

      // 检查头部是否移出地图
      if (map.isOutsideMap(newHead)) {
        // 头部移出，添加新头部，移除尾部
        final newPoints = List<Point>.from(currentPoints);
        newPoints.add(newHead);
        newPoints.removeAt(0);
        currentPoints = newPoints;
        animationFrames.add(List.from(currentPoints));

        // 检查是否整个曲线都移出边界外足够距离
        bool allFarEnough = true;
        for (final p in currentPoints) {
          if (!_isFarOutside(p, map)) {
            allFarEnough = false;
            break;
          }
        }

        if (allFarEnough) {
          exited = true;
          break;
        }
      } else {
        // 在地图内移动
        final newPoints = List<Point>.from(currentPoints);
        newPoints.add(newHead);
        newPoints.removeAt(0);
        currentPoints = newPoints;
        animationFrames.add(List.from(currentPoints));
      }
    }

    if (blocked) {
      return MovementResult(
        finalPoints: points,
        success: false,
        animationFrames: _createReverseAnimation(points, animationFrames),
        exitDirection: direction,
      );
    } else if (exited) {
      return MovementResult(
        finalPoints: [],
        success: true,
        animationFrames: animationFrames,
        exitDirection: direction,
      );
    } else {
      return MovementResult(
        finalPoints: currentPoints,
        success: false,
        animationFrames: animationFrames,
        exitDirection: direction,
      );
    }
  }

  static int _calculateMaxSteps(
      List<Point> points, Direction direction, GameMap map) {
    final head = points.last;
    int stepsToEdge;

    switch (direction) {
      case Direction.right:
        stepsToEdge = map.width - head.x;
        break;
      case Direction.left:
        stepsToEdge = head.x + 1;
        break;
      case Direction.down:
        stepsToEdge = map.height - head.y;
        break;
      case Direction.up:
        stepsToEdge = head.y + 1;
        break;
    }

    // 额外步数：曲线长度 + 边界外4格
    return stepsToEdge + points.length + 4;
  }

  static bool _isBlockedByOther(
    Point newHead,
    List<Point> currentPoints,
    Set<Point> occupiedPoints,
    GameMap map,
  ) {
    // 在地图外不算阻挡
    if (map.isOutsideMap(newHead)) {
      return false;
    }

    if (occupiedPoints.contains(newHead)) {
      return true;
    }

    return false;
  }

  /// 判断点是否足够远离地图边界（扩大4格）
  static bool _isFarOutside(Point p, GameMap map) {
    const margin = 4; // 扩大4格
    return p.x < -margin ||
        p.x >= map.width + margin ||
        p.y < -margin ||
        p.y >= map.height + margin;
  }

  static List<List<Point>> _createReverseAnimation(
    List<Point> originalPoints,
    List<List<Point>> forwardAnimation,
  ) {
    final reverse = <List<Point>>[];
    for (int i = forwardAnimation.length - 1; i >= 0; i--) {
      reverse.add(forwardAnimation[i]);
    }
    reverse.add(originalPoints);
    return reverse;
  }
}
