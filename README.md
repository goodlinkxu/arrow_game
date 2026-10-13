# 挪了个箭

一款休闲益智类手机小游戏，核心玩法是路径规划解谜。

## 游戏玩法

### 基本规则

1. **地图**：异形网格地图，由横平竖直排列的点组成
2. **曲线**：地图上有多条曲线（由网格点连接的折线），每条曲线有唯一方向箭头（显示在头部）
3. **移动**：点击曲线任意位置，曲线会沿着箭头方向"蛇形"移动
4. **碰撞**：如果移动方向遇到其他曲线，会倒放返回原位，扣除1条命
5. **胜利**：将所有曲线移出地图
6. **失败**：生命值归零

### 蛇形移动机制

- 曲线移动时，头部先探路
- 如果有转折点，后面的线条会保持原来的曲线形状移动
- 就像蛇在网格上滑动一样

### 生命系统

- 初始3条命
- 每次碰撞扣1命
- 新关卡恢复3条命

## 游戏特性

- ✅ 随机生成关卡，无上限
- ✅ 难度随关卡递增（地图变大、曲线变多）
- ✅ 记录最高关卡进度
- ✅ 支持缩放和拖拽地图
- ✅ 流畅的移动和失败动画

## 技术实现

- **框架**：Flutter
- **平台**：iOS + Android
- **状态管理**：ChangeNotifier
- **数据持久化**：SharedPreferences
- **自定义绘制**：CustomPainter

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── game/
│   ├── game_state.dart       # 游戏状态管理
│   ├── level_generator.dart  # 关卡生成器
│   └── movement_handler.dart # 移动逻辑处理
├── models/
│   ├── point.dart            # 坐标点
│   ├── direction.dart        # 方向枚举
│   ├── curve.dart            # 曲线数据
│   └── game_map.dart         # 游戏地图
├── screens/
│   └── game_screen.dart      # 游戏主界面
├── widgets/
│   └── game_painter.dart     # Canvas绘制
└── utils/
    └── storage.dart          # 数据存储
```

## 运行方式

```bash
# 安装依赖
flutter pub get

# 运行应用
flutter run

# 构建APK
flutter build apk

# 构建iOS
flutter build ios
```

## 开发计划

- [✓] 添加音效
- [✓] 优化动画效果
