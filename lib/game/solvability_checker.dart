import '../models/point.dart';
import '../models/curve.dart';
import '../models/game_map.dart';
import 'movement_handler.dart';

class SolvabilityChecker {
  static bool debugMode = true; // 开启调试

  /// 检查关卡是否满足所有要求
  static bool isSolvable(GameMap map, List<GameCurve> curves) {
    if (debugMode) {
      print('\n========== 可解性验证开始 ==========');
      print('地图大小: ${map.width} x ${map.height}');
      print('曲线数量: ${curves.length}');
      for (final curve in curves) {
        print('  ${curve.id}: points=${curve.points}, direction=${curve.direction}');
      }
    }

    // 要求2：检查每条曲线自身能否移出
    for (final curve in curves) {
      if (!_canCurveExitAlone(curve, map)) {
        if (debugMode) print('❌ ${curve.id} 单独无法移出');
        return false;
      }
    }

    // 要求1：检查整体是否可解
    final result = _checkSolvable(map, curves);
    if (debugMode) {
      print('整体可解: $result');
      print('========== 可解性验证结束 ==========\n');
    }
    return result;
  }

  static bool _canCurveExitAlone(GameCurve curve, GameMap map) {
    final emptyOccupied = <Point>{};
    final result = MovementHandler.moveCurve(curve, map, emptyOccupied);
    if (debugMode) {
      print('${curve.id} 单独移出: ${result.success}');
    }
    return result.success;
  }

  static bool _checkSolvable(GameMap map, List<GameCurve> curves) {
    return _tryAllOrders(map, curves, <String>{}, []);
  }

  static bool _tryAllOrders(
    GameMap map,
    List<GameCurve> curves,
    Set<String> exitedIds,
    List<String> path,
  ) {
    if (exitedIds.length == curves.length) {
      if (debugMode) {
        print('✅ 找到解路径: ${path.join(" -> ")}');
      }
      return true;
    }

    for (final curve in curves) {
      if (exitedIds.contains(curve.id)) continue;

      final occupied = <Point>{};
      for (final c in curves) {
        if (c.id != curve.id && !exitedIds.contains(c.id)) {
          occupied.addAll(c.points);
        }
      }

      if (debugMode) {
        print('\n尝试移动 ${curve.id}:');
        print('  曲线位置: ${curve.points}');
        print('  方向: ${curve.direction}');
        print('  occupiedPoints数量: ${occupied.length}');
        // 打印周围的occupied点
        final head = curve.points.last;
        final nearbyOccupied = occupied.where((p) =>
          (p.x - head.x).abs() <= 3 && (p.y - head.y).abs() <= 3
        ).toList();
        print('  头部附近的occupied: $nearbyOccupied');
      }

      final result = MovementHandler.moveCurve(curve, map, occupied);

      if (debugMode) {
        print('  移动结果: success=${result.success}');
        if (result.success) {
          print('  ✅ ${curve.id} 可以先移出');
        } else {
          print('  ❌ ${curve.id} 被阻挡');
          // 打印失败原因
          if (result.animationFrames.isNotEmpty) {
            print('  最后一帧: ${result.animationFrames.last}');
          }
        }
      }

      if (result.success) {
        final newExitedIds = Set<String>.from(exitedIds)..add(curve.id);
        final newPath = [...path, curve.id];
        if (_tryAllOrders(map, curves, newExitedIds, newPath)) {
          return true;
        }
      }
    }

    return false;
  }
}
