import 'point.dart';
import 'direction.dart';

class GameCurve {
  final List<Point> points;
  final Direction direction;
  final String id;
  bool isExited;
  bool isFailed;

  GameCurve({
    required this.points,
    required this.direction,
    required this.id,
    this.isExited = false,
    this.isFailed = false,
  });

  /// 头部点（箭头所在位置）
  Point get head => points.last;

  /// 尾部点
  Point get tail => points.first;

  /// 曲线包含的所有点（用于碰撞检测）
  Set<Point> get pointSet => points.toSet();

  /// 创建失败状态的副本
  GameCurve copyWithFailed() {
    return GameCurve(
      points: List.from(points),
      direction: direction,
      id: id,
      isExited: isExited,
      isFailed: true,
    );
  }

  /// 创建成功退出的副本
  GameCurve copyWithExited() {
    return GameCurve(
      points: List.from(points),
      direction: direction,
      id: id,
      isExited: true,
      isFailed: isFailed,
    );
  }

  /// 创建移动后的副本
  GameCurve copyWithPoints(List<Point> newPoints) {
    return GameCurve(
      points: newPoints,
      direction: direction,
      id: id,
      isExited: isExited,
      isFailed: isFailed,
    );
  }
}
