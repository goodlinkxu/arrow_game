import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/game_state.dart';
import '../game/level_manager.dart'; // 👈 完美对接流水线传送带
import '../widgets/game_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  final GameState _gameState = GameState();
  double _scale = 1.0;
  Offset _panOffset = Offset.zero;
  bool _showingDialog = false;
  Timer? _timer;
  Timer? _comboTimer;
  late AnimationController _borderAnim;

  @override
  void initState() {
    super.initState();
    _gameState.addListener(_onGameStateChanged);
    
    // 1. ⚡ 游戏一开机，秒级同步生成第一关，后台起步第二关
    LevelManager().initializeSync();
    
    // 2. 初始化本地高分数据并提取第一关
    _initGame();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _gameState.tick();
    });

    _borderAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      value: 1.0,
    );

    _comboTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (_gameState.comboActive) {
        _gameState.checkComboExpiry();
        setState(() {});
      }
    });
  }

  Future<void> _initGame() async {
    // 让底层去加载最高得分关卡等本地数据
    await _gameState.initGame(); 
    
    // 3. 🚀 直接提取开机就已经织好的第 1 关，0毫秒呈现
    final firstLevel = LevelManager().getNextLevel();
    if (firstLevel != null) {
      _gameState.loadLevelData(firstLevel);
    }
  }

  @override
  void dispose() {
    _borderAnim.dispose();
    _timer?.cancel();
    _comboTimer?.cancel();
    _gameState.removeListener(_onGameStateChanged);
    _gameState.dispose();
    super.dispose();
  }

  void _onGameStateChanged() {
    if (!mounted) return;

    if (_gameState.lastFailedCurveId != null) {
      _gameState.lastFailedCurveId = null;
      _borderAnim.forward(from: 0.0);
    }

    setState(() {});

    if (_showingDialog) return;

    if (_gameState.isGameOver) {
      HapticFeedback.mediumImpact();
      _showGameOverDialog();
    } else if (_gameState.isLevelComplete) {
      HapticFeedback.mediumImpact();
      _showLevelCompleteDialog();
    }
  }

  void _showGameOverDialog() {
    _showingDialog = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('游戏结束'),
        content: Text('你到达了第 ${_gameState.currentLevel} 关'),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop();
              _showingDialog = false;
              final currentBackup = LevelManager().getCurrentLevelBackup();
              if (currentBackup != null) {
                _gameState.restartLevel();
                _gameState.loadLevelData(currentBackup);
                setState(() {
                  _scale = 1.0;
                  _panOffset = Offset.zero;
                });
                print('[重开局] 已提取备份快照，0毫秒完成原地复位。');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.blue),
            child: const Text('原地重来'),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop();
              _showingDialog = false;
              final currentLevel = _gameState.currentLevel;
              final freshLevel = LevelManager().getNextLevel();
              if (freshLevel != null) {
                _gameState.loadLevelData(freshLevel);
                _gameState.currentLevel = currentLevel;
                setState(() {
                  _scale = 1.0;
                  _panOffset = Offset.zero;
                });
              }
            },
            child: const Text('换个新阵型'),
          ),
        ],
      ),
    );
  }

  void _showLevelCompleteDialog() {
    _showingDialog = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('恭喜过关！'),
        content: Text('第 ${_gameState.currentLevel} 关完成'),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop();
              _showingDialog = false;
              final nextLevel = LevelManager().getNextLevel();
              if (nextLevel != null) {
                _gameState.nextLevel();
                _gameState.loadLevelData(nextLevel);
                setState(() {
                  _scale = 1.0;
                  _panOffset = Offset.zero;
                });
              }
              LevelManager().printCacheStatus();
            },
            child: const Text('下一关'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text('挪了个箭 - 第 ${_gameState.currentLevel} 关'),
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '最高: ${_gameState.maxLevelReached}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, color: Colors.red),
                      const SizedBox(width: 4),
                      Text(
                        '${_gameState.lives}',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            children: [
              _buildBody(),
              Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: _gameState.timeRemaining <= 10
                            ? Colors.red.withOpacity(0.7)
                            : Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_gameState.timeRemaining ~/ 60}:${(_gameState.timeRemaining % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 连击进度条
              if (_gameState.comboActive)
                Positioned(
                  bottom: 20,
                  left: 40,
                  right: 40,
                  child: IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'x${_gameState.comboCount}',
                          style: TextStyle(
                            color: Colors.amber.shade300,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _gameState.comboProgress,
                            minHeight: 6,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.amber.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _borderAnim,
            builder: (context, child) {
              final opacity = 0.15 * (1.0 - _borderAnim.value);
              if (opacity <= 0) return const SizedBox.shrink();
              return IgnorePointer(
                child: CustomPaint(
                  painter: _BorderGlowPainter(opacity),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_gameState.map == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final Set<String> exitedIds = _gameState.logicalExitedIds;

        return GestureDetector(
          onTapUp: (details) => _onTap(details, constraints),
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: RepaintBoundary(
            child: CustomPaint(
              key: ValueKey('painter_${_gameState.currentLevel}_${_gameState.curves.length}_${exitedIds.length}'),
              painter: GamePainter(
                map: _gameState.map!,
                curves: _gameState.curves,
                cellSize: _calculateCellSize(constraints),
                offset: _panOffset,
                logicalExitedIds: exitedIds,
              ),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }

  double _calculateCellSize(BoxConstraints constraints) {
    if (_gameState.map == null) return 40;
    final mapWidth = _gameState.map!.width;
    final mapHeight = _gameState.map!.height;

    final cellWidth = constraints.maxWidth / (mapWidth + 1);
    final cellHeight = constraints.maxHeight / (mapHeight + 1);

    return (cellWidth < cellHeight ? cellWidth : cellHeight) * _scale;
  }

  void _onTap(TapUpDetails details, BoxConstraints constraints) {
    if (_gameState.map == null) return;

    final cellSize = _calculateCellSize(constraints);
    final mapWidth = _gameState.map!.width;
    final mapHeight = _gameState.map!.height;

    final mapPixelWidth = mapWidth * cellSize;
    final mapPixelHeight = mapHeight * cellSize;
    final centerX = (constraints.maxWidth - mapPixelWidth) / 2 + _panOffset.dx;
    final centerY = (constraints.maxHeight - mapPixelHeight) / 2 + _panOffset.dy;

    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;

    String? closestCurveId;
    double closestDistance = double.infinity;

    for (final curve in _gameState.curves) {
      if (curve.isExited) continue;

      final distance = _getDistanceToCurve(tapX, tapY, curve, cellSize, centerX, centerY);
      if (distance < closestDistance) {
        closestDistance = distance;
        closestCurveId = curve.id;
      }
    }

    final lineWidth = cellSize * 0.16;
    if (closestCurveId != null && closestDistance < lineWidth * 3.8) {
      _gameState.onCurveTap(closestCurveId);
    }
  }

  double _getDistanceToCurve(
    double tapX, double tapY, dynamic curve, double cellSize,
    double centerX, double centerY,
  ) {
    double minDistance = double.infinity;
    if (curve.points.length < 2) return minDistance;

    for (int i = 0; i < curve.points.length - 1; i++) {
      final p1 = curve.points[i];
      final p2 = curve.points[i + 1];

      final x1 = centerX + p1.x * cellSize;
      final y1 = centerY + p1.y * cellSize;
      final x2 = centerX + p2.x * cellSize;
      final y2 = centerY + p2.y * cellSize;

      final distance = _pointToSegmentDistance(tapX, tapY, x1, y1, x2, y2);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    return minDistance;
  }

  double _pointToSegmentDistance(
      double px, double py, double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    final lengthSq = dx * dx + dy * dy;

    if (lengthSq == 0) {
      return sqrt((px - x1) * (px - x1) + (py - y1) * (py - y1));
    }

    var t = ((px - x1) * dx + (py - y1) * dy) / lengthSq;
    t = t.clamp(0.0, 1.0);

    final projX = x1 + t * dx;
    final projY = y1 + t * dy;

    return sqrt((px - projX) * (px - projX) + (py - projY) * (py - projY));
  }

  double _baseScale = 1.0;

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_baseScale * details.scale).clamp(0.5, 3.0);
      _panOffset += details.focalPointDelta;
    });
  }
}

class _BorderGlowPainter extends CustomPainter {
  final double opacity;
  _BorderGlowPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final color = Colors.red.withOpacity(opacity);
    final transparent = Colors.red.withOpacity(0);
    final edgeW = size.width * 0.08;
    final edgeH = size.height * 0.08;

    // Top
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, edgeH),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, edgeH)),
    );
    // Bottom
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - edgeH, size.width, edgeH),
      Paint()..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [color, transparent],
      ).createShader(Rect.fromLTWH(0, size.height - edgeH, size.width, edgeH)),
    );
    // Left
    canvas.drawRect(
      Rect.fromLTWH(0, 0, edgeW, size.height),
      Paint()..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [color, transparent],
      ).createShader(Rect.fromLTWH(0, 0, edgeW, size.height)),
    );
    // Right
    canvas.drawRect(
      Rect.fromLTWH(size.width - edgeW, 0, edgeW, size.height),
      Paint()..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [color, transparent],
      ).createShader(Rect.fromLTWH(size.width - edgeW, 0, edgeW, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant _BorderGlowPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}