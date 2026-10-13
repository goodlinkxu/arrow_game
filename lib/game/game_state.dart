import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/point.dart';
import '../models/curve.dart';
import '../models/game_map.dart';
import '../utils/storage.dart';
import 'level_generator.dart';
import 'movement_handler.dart';
import '../utils/tone_player.dart';

class GameState extends ChangeNotifier {
  GameMap? _map;
  List<GameCurve> _curves = [];
  int _currentLevel = 1;
  int _lives = 3;
  int _timeRemaining = 60;
  int _maxLevelReached = 1;
  bool _isGameOver = false;
  bool _isLevelComplete = false;

  // 🌟【多连击核心】：逻辑上已经判定通关、正在飞走的蛇 ID 集合
  // 它们的身躯在前端继续播放平滑帧动画，但在后端逻辑网格中已经“瞬间蒸发”，不再阻挡别的蛇
  final Set<String> _logicalExitedIds = {};

  // 正在播放“失败倒放动画”的蛇，防止玩家在它倒放时重复点击
  final Set<String> _failedAnimatingIds = {};

  // 幽灵线
  final Set<Point> _ghostPoints = {};

  // 失败信号（UI 读取后应清空）
  String? lastFailedCurveId;

  // 连击系统
  int _comboCount = 0;
  DateTime? _comboStartTime;
  static const Duration comboWindow = Duration(milliseconds: 1500);

  int get comboCount => _comboCount;
  bool get comboActive => _comboCount > 0 && _comboStartTime != null;

  double get comboProgress {
    if (!comboActive) return 0.0;
    final elapsed = DateTime.now().difference(_comboStartTime!);
    return (1.0 - elapsed.inMilliseconds / comboWindow.inMilliseconds).clamp(0.0, 1.0);
  }

  /// 检查连击是否过期，过期则重置
  void checkComboExpiry() {
    if (comboActive && comboProgress <= 0) {
      _comboCount = 0;
      _comboStartTime = null;
      TonePlayer().resetCombo();
      notifyListeners();
    }
  }

  // Getters
  GameMap? get map => _map;
  List<GameCurve> get curves => _curves;
  int get currentLevel => _currentLevel;
  set currentLevel(int value) => _currentLevel = value;
  int get lives => _lives;
  int get timeRemaining => _timeRemaining;
  int get maxLevelReached => _maxLevelReached;
  bool get isGameOver => _isGameOver;
  bool get isLevelComplete => _isLevelComplete;
  
  // 🌟 公开这个私有集合给外部（如 GamePainter），优雅替代原有的 dynamic 反射
  Set<String> get logicalExitedIds => _logicalExitedIds;

  // 兼容原有 UI 组件的动画 Getter 接口
  bool get isAnimating => _logicalExitedIds.isNotEmpty || _failedAnimatingIds.isNotEmpty;
  String? get animatingCurveId => _logicalExitedIds.isNotEmpty 
      ? _logicalExitedIds.last 
      : (_failedAnimatingIds.isNotEmpty ? _failedAnimatingIds.last : null);
  bool get isAnimatingForward => _logicalExitedIds.isNotEmpty;

  /// 获取当前活跃的蛇（既没有真正退出，也没有被列入逻辑瞬间蒸发队列的蛇）
  List<GameCurve> get activeCurves =>
      _curves.where((c) => !c.isExited && !_logicalExitedIds.contains(c.id)).toList();

  /// 🌟【连击网格刷新】：重写物理碰撞网格计算方法
  Set<Point> get occupiedPoints {
    final points = <Point>{}..addAll(_ghostPoints);
    for (final curve in activeCurves) {
      points.addAll(curve.points);
    }
    return points;
  }

  Future<void> initGame() async {
    _maxLevelReached = await Storage.getMaxLevel();
    _currentLevel = 1;
    _lives = 3;
    _isGameOver = false;
    _isLevelComplete = false;
    _ghostPoints.clear();
    _logicalExitedIds.clear();
    _failedAnimatingIds.clear();
  }

  /// ------------------------------------------------------------------
  /// 🚀【核心大门】：接收来自 LevelManager 预生成的高密度双倍传送带数据
  /// ------------------------------------------------------------------
  void loadLevelData(LevelData levelData) {
    _map = levelData.map;
    _curves = levelData.curves.map((c) => GameCurve(
      points: List.from(c.points),
      direction: c.direction,
      id: c.id,
    )).toList();
    _currentLevel = levelData.level;
    
    _isLevelComplete = false;
    _isGameOver = false;
    _lives = 3; 
    
    _ghostPoints.clear();
    _logicalExitedIds.clear();
    _failedAnimatingIds.clear();
    _timeRemaining = 60;
    _comboCount = 0;
    _comboStartTime = null;
    TonePlayer().resetCombo();

    notifyListeners();
  }

  /// 🌟 瞬间脱空连击核心点击函数
  void onCurveTap(String curveId) {
    if (_isGameOver || _isLevelComplete) return;

    if (_logicalExitedIds.contains(curveId) || _failedAnimatingIds.contains(curveId)) return;

    final curveIndex = _curves.indexWhere((c) => c.id == curveId);
    if (curveIndex == -1) return;

    final curve = _curves[curveIndex];
    if (curve.isExited) return;

    final otherOccupied = Set<Point>.from(occupiedPoints);
    otherOccupied.removeAll(curve.points);

    final result = MovementHandler.moveCurve(
      curve,
      _map!,
      otherOccupied,
    );

    if (result.success) {
      HapticFeedback.lightImpact();
      // 连击音效
      _comboCount++;
      _comboStartTime = DateTime.now();
      TonePlayer().playNextNote();
      notifyListeners();

      final successIdx = _curves.indexWhere((c) => c.id == curveId);
      if (successIdx != -1 && _curves[successIdx].isFailed) {
        _curves[successIdx] = GameCurve(
          points: List.from(_curves[successIdx].points),
          direction: _curves[successIdx].direction,
          id: _curves[successIdx].id,
        );
      }
      _logicalExitedIds.add(curveId);
      notifyListeners();
      _playSuccessAnimation(result, curveId);
    } else {
      HapticFeedback.heavyImpact();
      // 连击中断
      _comboCount = 0;
      _comboStartTime = null;
      TonePlayer().resetCombo();
      _failedAnimatingIds.add(curveId);
      lastFailedCurveId = curveId;
      final failIdx = _curves.indexWhere((c) => c.id == curveId);
      if (failIdx != -1) {
        _curves[failIdx] = _curves[failIdx].copyWithFailed();
      }
      notifyListeners();
      _playFailureAnimation(result, curveId);
    }
  }

  /// 🌟 独立的成功动画线
  Future<void> _playSuccessAnimation(MovementResult result, String curveId) async {
    for (final frame in result.animationFrames) {
      final idx = _curves.indexWhere((c) => c.id == curveId);
      if (idx == -1) break;

      if (frame.isEmpty) {
        _curves[idx] = _curves[idx].copyWithExited();
      } else {
        _curves[idx] = _curves[idx].copyWithPoints(frame);
      }
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 40));
    }

    final finalIdx = _curves.indexWhere((c) => c.id == curveId);
    if (finalIdx != -1) {
      _curves[finalIdx] = _curves[finalIdx].copyWithExited();
    }
    
    _logicalExitedIds.remove(curveId);
    _checkLevelComplete();
    notifyListeners();
  }

  /// 🌟 独立的失败倒放动画线
  Future<void> _playFailureAnimation(MovementResult result, String curveId) async {
    for (final frame in result.animationFrames) {
      final idx = _curves.indexWhere((c) => c.id == curveId);
      if (idx == -1) break;

      _curves[idx] = _curves[idx].copyWithPoints(frame);
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 40));
    }

    _failedAnimatingIds.remove(curveId);
    _lives--;
    if (_lives <= 0) {
      _isGameOver = true;
    }
    notifyListeners();
  }

  void _checkLevelComplete() {
    if (_curves.every((c) => c.isExited) && _logicalExitedIds.isEmpty) {
      _isLevelComplete = true;
      if (_currentLevel > _maxLevelReached) {
        _maxLevelReached = _currentLevel;
        Storage.saveMaxLevel(_maxLevelReached);
      }
    }
  }

  void nextLevel() {
    _currentLevel++;
    _isLevelComplete = false;
    _isGameOver = false;
    _lives = 3;
    _ghostPoints.clear();
    _logicalExitedIds.clear();
    _failedAnimatingIds.clear();
  }

  void restartLevel() {
    _isLevelComplete = false;
    _isGameOver = false;
    _lives = 3;
    _ghostPoints.clear();
    _logicalExitedIds.clear();
    _failedAnimatingIds.clear();
  }

  void resetTimer() {
    _timeRemaining = 60;
    notifyListeners();
  }

  void tick() {
    if (_isGameOver || _isLevelComplete) return;
    if (_timeRemaining <= 0) {
      _isGameOver = true;
      notifyListeners();
      return;
    }
    _timeRemaining--;
    notifyListeners();
  }

  void restartGame() {
    initGame();
  }
}