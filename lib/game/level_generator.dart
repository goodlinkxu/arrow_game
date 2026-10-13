import 'dart:math';
import '../models/point.dart';
import '../models/direction.dart';
import '../models/curve.dart';
import '../models/game_map.dart';

class LevelData {
  final GameMap map;
  final List<GameCurve> curves;
  final int level;
  const LevelData({required this.map, required this.curves, required this.level});
}

class LevelGenerator {
  static final Random _random = Random();

  static LevelData generate(int level) {
    // ------------------------------------------------------------------
    // 【核心改动】：棋盘面积直接扩充至原本的 2 倍 (长宽分别按等比例系数 ~1.4 放大)
    // ------------------------------------------------------------------
    final int width = 14 + (level ~/ 4).clamp(0, 6);   // 原基础 10 -> 现 14 (放大 ~1.4 倍)
    final int height = 17 + (level ~/ 3).clamp(0, 6);  // 原基础 12 -> 现 17 (放大 ~1.4 倍)
    
    int attempts = 0;
    while (true) {
      attempts++;
      print('\n======================================================');
      print('[巨型两倍流场填充] 正在构建第 $level 关 (第 $attempts 次编织) 棋盘: ${width}x${height}');
      print('======================================================');
      
      final gameMap = _generateMap(width, height);
      final List<GameCurve>? generatedCurves = _generateViaPotentialField(gameMap);

      // 面积翻倍后，最低保底吞吐蛇数等比例提升到 16 条
      if (generatedCurves != null && generatedCurves.length >= 16) {
        int totalBodyPoints = 0;
        for (var c in generatedCurves) totalBodyPoints += c.points.length;
        double mapUsage = (totalBodyPoints / (width * height)) * 100;

        // 巨型地图下，保持 55% 以上的绝对占用率才算及格的高难度满载
        if (mapUsage < 55.0) {
          print('[广阔度不达标] 当前巨型阵型占用率仅 ${mapUsage.toStringAsFixed(1)}%，空间太松散，扔掉重刷。');
          continue;
        }

        print('\n[机器人质检官] 巨型阵型密度达标 (${mapUsage.toStringAsFixed(1)}%)，启动 100% 拓扑推演...');
        if (_isLevel100PercentSolvableWithLogs(generatedCurves, gameMap)) {
          print('\n[巨型关卡完美收货] 历经 $attempts 次流场重构，超级迷宫编织成功！');
          print('巨型统计: 成功铺设蛇数: ${generatedCurves.length} 条 | 棋盘绝对空间占用率: ${mapUsage.toStringAsFixed(1)}%');
          print('======================================================\n');
          
          return LevelData(
            map: gameMap,
            curves: generatedCurves,
            level: level,
          );
        } else {
          print('[熔断] 巨型阵型陷入多向环形死锁，无情抛弃，重新编织！');
        }
      }
    }
  }

  static GameMap _generateMap(int width, int height) {
    final validPoints = <Point>{};
    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        validPoints.add(Point(x, y));
      }
    }
    return GameMap(width: width, height: height, validPoints: validPoints);
  }

  static List<GameCurve>? _generateViaPotentialField(GameMap map) {
    final List<GameCurve> placedCurves = [];
    final Set<Point> physicalOccupied = {};
    final Map<Point, double> potentialField = {};
    final Map<Point, int> addCan = {};

    for (final p in map.validPoints) {
      potentialField[p] = 1000.0; 
      addCan[p] = 1;              
    }

    // 1. 放置基础始祖蛇 (在大地图中心奠定十字波纹基调)
    final Point center = Point(map.width ~/ 2, map.height ~/ 2);
    List<Point> ancestorPoints = [
      Point(center.x - 1, center.y),
      Point(center.x, center.y),
      Point(center.x + 1, center.y),
    ];
    
    final ancestor = GameCurve(
      points: ancestorPoints,
      direction: Direction.right,
      id: 'curve_0',
    );
    placedCurves.add(ancestor);
    for (final p in ancestorPoints) {
      physicalOccupied.add(p);
      addCan[p] = 0;
    }
    _radiatePotential(ancestor, map, potentialField);

    // 极限压榨分母 4.0，在大棋盘下这意味着目标铺设数量将达到 50-70 条蛇左右！
    final int targetSnakeCount = ((map.width * map.height) / 4.0).floor();
    
    int successCount = 1;
    int discardCount = 0;
    int totalAttempts = 0;

    // 2. 巨型图有效填充循环：大地图下试探上限提高至 800 次，确保极佳的骨骼衔接
    while (successCount < targetSnakeCount && totalAttempts < 800) {
      totalAttempts++;
      Point? bestHead;
      double minPotential = double.infinity;
      List<Point> availableHeads = map.validPoints.where((p) => addCan[p] == 1).toList();
      
      if (availableHeads.isEmpty) {
        print('[空间榨干] 巨型棋盘已无任何可用蛇头刷新点。');
        break; 
      }

      for (final p in availableHeads) {
        double noise = (_random.nextDouble() - 0.5) * 160.0; 
        double currentVal = potentialField[p]! + noise;
        if (currentVal < minPotential) {
          minPotential = currentVal;
          bestHead = p;
        }
      }

      if (bestHead == null) break;

      List<Direction> dirs = Direction.values.toList()..shuffle(_random);
      Direction startBackwardDir = dirs.first;
      double maxNeighborPotential = -double.infinity;
      for (final d in dirs) {
        final np = Point(bestHead.x + d.dx, bestHead.y + d.dy);
        if (map.isValidPoint(np) && !physicalOccupied.contains(np)) {
          if (potentialField[np]! > maxNeighborPotential) {
            maxNeighborPotential = potentialField[np]!;
            startBackwardDir = d;
          }
        }
      }

      // 巨型图蜿蜒长度设计：在中后期加入短蛇填补大量碎片空格
      List<int> lengthChoices = [7, 6, 5, 4];
      if (successCount > targetSnakeCount * 0.5) {
        lengthChoices = [5, 4, 6]; 
      }
      lengthChoices.shuffle(_random);
      
      List<Point>? bodyPoints;
      for (int targetLength in lengthChoices) {
        bodyPoints = _growSnakeInValley(
          bestHead, startBackwardDir, targetLength, map, physicalOccupied, potentialField
        );
        if (bodyPoints != null && bodyPoints.length >= 4) break;
      }

      if (bodyPoints != null && bodyPoints.length >= 4) {
        final Point head = bodyPoints.last;
        final Point neck = bodyPoints[bodyPoints.length - 2];
        
        Direction physicalDir = Direction.right;
        if (head.x > neck.x) physicalDir = Direction.right;
        if (head.x < neck.x) physicalDir = Direction.left;
        if (head.y > neck.y) physicalDir = Direction.down;
        if (head.y < neck.y) physicalDir = Direction.up;

        // 强力射线拦截、自残骑脸质检
        bool hasConflict = false;
        Point checkP = Point(head.x + physicalDir.dx, head.y + physicalDir.dy);
        while (map.isInsideMap(checkP)) {
          if (physicalOccupied.contains(checkP)) {
            if (checkP.x == head.x + physicalDir.dx && checkP.y == head.y + physicalDir.dy) {
              hasConflict = true; 
            }
            break; 
          }
          if (bodyPoints.contains(checkP)) {
            hasConflict = true;
            break;
          }
          checkP = Point(checkP.x + physicalDir.dx, checkP.y + physicalDir.dy);
        }

        if (hasConflict) {
          addCan[bestHead] = 0;
          discardCount++;
          continue; 
        }

        final newCurve = GameCurve(
          points: bodyPoints,
          direction: physicalDir,
          id: 'curve_$successCount',
        );

        placedCurves.add(newCurve);
        for (final p in bodyPoints) {
          physicalOccupied.add(p);
          addCan[p] = 0;
        }

        _radiatePotential(newCurve, map, potentialField);
        if (successCount % 5 == 0 || successCount > targetSnakeCount * 0.8) {
          // 避免千行日志刷屏，巨型图下每 5 条蛇或者后期收尾阶段打印一次铺设进度
          print('[流场铺设] 成功塞入第 $successCount 条蛇 (${newCurve.id}) -> 朝向: ${physicalDir.toString().split('.').last.toUpperCase()}');
        }
        successCount++;
      } else {
        addCan[bestHead] = 0; 
        discardCount++;
      }
    }

    print('[生厂纪要] 物理尝试总计: $totalAttempts 次 | 成功落盘: ${placedCurves.length} 条 | 冲突裁切: $discardCount 次');
    return placedCurves;
  }

  static bool _isLevel100PercentSolvableWithLogs(List<GameCurve> sourceCurves, GameMap map) {
    List<GameCurve> simulatingCurves = List.from(sourceCurves);
    int stepCount = 0;
    bool progress = true;

    while (simulatingCurves.isNotEmpty && progress) {
      progress = false;
      GameCurve? snakeToRemove;

      for (final snake in simulatingCurves) {
        final Point head = snake.points.last;
        final Direction dir = snake.direction;
        bool isBlocked = false;

        Point checkP = Point(head.x + dir.dx, head.y + dir.dy);
        while (map.isInsideMap(checkP)) {
          bool hitOther = simulatingCurves.any((other) => other.id != snake.id && other.points.contains(checkP));
          if (hitOther) {
            isBlocked = true;
            break;
          }
          checkP = Point(checkP.x + dir.dx, checkP.y + dir.dy);
        }

        if (!isBlocked) {
          snakeToRemove = snake;
          break;
        }
      }

      if (snakeToRemove != null) {
        stepCount++;
        simulatingCurves.remove(snakeToRemove);
        if (stepCount % 5 == 0 || simulatingCurves.length < 5) {
          print('   [推演 Step $stepCount]: 蛇 ${snakeToRemove.id} 前方空旷，解密成功！(剩余 ${simulatingCurves.length} 条)');
        }
        progress = true; 
      }
    }

    return simulatingCurves.isEmpty;
  }

  static void _radiatePotential(GameCurve snake, GameMap map, Map<Point, double> field) {
    final Point head = snake.points.last;
    final Direction dir = snake.direction;

    Point curr = Point(head.x + dir.dx, head.y + dir.dy);
    int step = 1;
    while (map.isInsideMap(curr)) {
      if (field.containsKey(curr)) {
        field[curr] = field[curr]! - (850.0 / step);
      }
      curr = Point(curr.x + dir.dx, curr.y + dir.dy);
      step++;
    }

    List<Direction> crossDirs = (dir == Direction.up || dir == Direction.down) 
        ? [Direction.left, Direction.right] 
        : [Direction.up, Direction.down];

    for (final cDir in crossDirs) {
      for (int offset = 1; offset <= 3; offset++) {
        final sideP = Point(head.x + cDir.dx * offset, head.y + cDir.dy * offset);
        if (field.containsKey(sideP)) {
          field[sideP] = field[sideP]! - 550.0; 
        }
      }
    }

    final Set<Point> visited = {};
    List<Point> queue = List.from(snake.points);
    for (final p in queue) visited.add(p);

    double rippleImpact = 260.0; 
    for (int layer = 0; layer < 3; layer++) {
      if (queue.isEmpty) break;
      List<Point> nextLayer = [];
      for (final p in queue) {
        for (final d in Direction.values) {
          final np = Point(p.x + d.dx, p.y + d.dy);
          if (map.isInsideMap(np) && !visited.contains(np)) {
            visited.add(np);
            nextLayer.add(np);
            if (field.containsKey(np)) {
              field[np] = field[np]! - rippleImpact;
            }
          }
        }
      }
      queue = nextLayer;
      rippleImpact /= 2.0; 
    }
  }

  static List<Point>? _growSnakeInValley(
    Point head, Direction backwardDir, int targetLength, GameMap map, Set<Point> occupied, Map<Point, double> field
  ) {
    List<Point> snakePoints = [head];
    Point curr = head;
    Direction currentBackwardDir = backwardDir;

    for (int i = 1; i < targetLength; i++) {
      List<Direction> dirs = [currentBackwardDir];
      dirs.addAll(_getTurnDirections(currentBackwardDir)..shuffle(_random));

      Point? nextPoint;
      Direction? nextDir;
      double minValleyVal = double.infinity;

      for (final d in dirs) {
        final np = Point(curr.x + d.dx, curr.y + d.dy);
        if (map.isValidPoint(np) && !occupied.contains(np) && !snakePoints.contains(np)) {
          double pVal = field[np] ?? 1000.0;
          if (pVal < minValleyVal) {
            minValleyVal = pVal;
            nextPoint = np;
            nextDir = d;
          }
        }
      }

      if (nextPoint != null && nextDir != null) {
        snakePoints.insert(0, nextPoint); 
        curr = nextPoint;
        currentBackwardDir = nextDir;
      } else {
        if (snakePoints.length >= 4) return snakePoints;
        return null;
      }
    }
    return snakePoints;
  }

  static List<Direction> _getTurnDirections(Direction curr) {
    switch (curr) {
      case Direction.up:
      case Direction.down:
        return [Direction.left, Direction.right];
      case Direction.left:
      case Direction.right:
        return [Direction.up, Direction.down];
    }
  }
}