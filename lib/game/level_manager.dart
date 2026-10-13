import 'dart:collection';
import '../models/curve.dart';
import 'level_generator.dart';

class LevelManager {
  static final LevelManager _instance = LevelManager._internal();
  factory LevelManager() => _instance;
  LevelManager._internal();

  // 严格的先进先出下一关缓存队列
  final Queue<LevelData> _levelCache = Queue<LevelData>();
  
  // 🌟【原地重来黑科技】：备份一份当前正在玩的关卡数据。玩家点重来时，0毫秒直接用它复位，不需要重新生成！
  LevelData? _currentPlayingLevelBackup;

  // 下一个需要放进缓存池的关卡代号
  int _nextLevelToGenerate = 1;
  final int _maxCacheSize = 1;
  bool _isGenerating = false;

  /// 📥 开机初始化：0毫秒同步生第一关，立刻放行，绝不等待！
  void initializeSync() {
    _levelCache.clear();
    _currentPlayingLevelBackup = null;
    _nextLevelToGenerate = 1;

    print('[开机秒开] 同步紧急闪电编织第 1 关...');
    final firstLevel = LevelGenerator.generate(1);
    _levelCache.addLast(firstLevel);
    
    _nextLevelToGenerate = 2; // 下一关的目标是第 2 关

    // 🚀 重点：利用延迟切片，在你盯着第一关看、挪动第一步之前，悄悄在后台启动第 2 关的编织
    Future.delayed(const Duration(milliseconds: 100), () {
      _triggerBackgroundGeneration();
    });
  }

  /// 📥 核心出库接口：下一关直接端上来
  LevelData? getNextLevel() {
    if (_levelCache.isEmpty) {
      print('[警告] 生产线断流！被迫同步催货第 $_nextLevelToGenerate 关！');
      final fallback = LevelGenerator.generate(_nextLevelToGenerate);
      _nextLevelToGenerate++;
      _currentPlayingLevelBackup = fallback;
      _triggerBackgroundGeneration();
      return fallback;
    }

    // 从传送带无延迟拉出下一关
    final levelData = _levelCache.removeFirst();
    print('[传送带出库] 0毫秒将【第 ${levelData.level} 关】端上盘子！');

    // 备份这份数据，用于当前关卡失败时“原地重来”
    _currentPlayingLevelBackup = levelData;

    // ====================================================================
    // 🔥【一边玩一边加载的灵魂】：你刚拿到这关开始玩，后台立刻空转出微任务去织下下一关
    // ====================================================================
    _triggerBackgroundGeneration();

    return levelData;
  }

  /// 📥【0毫秒重来接口】：玩家失败重来时，直接用备份数据，不耗算力
  LevelData? getCurrentLevelBackup() {
    if (_currentPlayingLevelBackup != null) {
      print('[原地复位] 提取当前关卡副本，0 毫秒瞬间重现盘面！');
      // 返回备份数据的深拷贝，防止被走乱的线影响
      return LevelData(
        map: _currentPlayingLevelBackup!.map,
        curves: _currentPlayingLevelBackup!.curves.map((c) => GameCurve(
          points: List.from(c.points),
          direction: c.direction,
          id: c.id,
        )).toList(),
        level: _currentPlayingLevelBackup!.level,
      );
    }
    return null;
  }

  /// 触发后台异步编织
  void _triggerBackgroundGeneration() {
    if (_isGenerating || _levelCache.length >= _maxCacheSize) return;
    
    _isGenerating = true;
    _fillCacheAsync();
  }

  /// 🌟 使用 Future 切片异步填充，彻底解决 Web 端的卡顿和 CanvasKit 报错
  void _fillCacheAsync() {
    // 异步执行，把生成权转交给下一个帧循环，彻底解放当前游戏画面
    Future.microtask(() {
      if (_levelCache.length < _maxCacheSize) {
        int target = _nextLevelToGenerate;
        print('[后台流水线] 玩家正在玩当前局，后台流水线开始静默编织【第 $target 关】...');

        // 🚨 彻底废除 compute！在 Web 环境用纯粹的同步单线程拆分模拟异步
        final data = LevelGenerator.generate(target);
        
        _levelCache.addLast(data);
        _nextLevelToGenerate++;
        
        print('[后台流水线] 【第 ${data.level} 关】已在备战池躺好！当前蓄水池存货: ${_levelCache.map((e) => "第${e.level}关").toList()}');
      }
      _isGenerating = false;
    });
  }

  void printCacheStatus() {
    print('[备战看板] 传送带存货: ${_levelCache.map((e) => "第${e.level}关").toList()} | 失败备用库: 第 ${_currentPlayingLevelBackup?.level} 关');
  }
}