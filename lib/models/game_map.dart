import 'point.dart';

class GameMap {
  final int width;
  final int height;
  final Set<Point> validPoints; // 有效格子（异形地图）
  final Set<Point> holes; // 洞（可选）

  GameMap({
    required this.width,
    required this.height,
    required this.validPoints,
    this.holes = const {},
  });

  /// 检查点是否在地图内
  bool isInsideMap(Point p) {
    return p.x >= 0 && p.x < width && p.y >= 0 && p.y < height;
  }

  /// 检查点是否是有效格子
  bool isValidPoint(Point p) {
    return validPoints.contains(p);
  }

  /// 检查点是否已经移出地图
  bool isOutsideMap(Point p) {
    return !isInsideMap(p) || !isValidPoint(p);
  }
}
