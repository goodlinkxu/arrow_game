import 'package:flutter/material.dart';
import 'game/level_manager.dart'; // 引入你刚建好的缓存管理器
import 'screens/game_screen.dart';

void main() async {
  // 确保 Flutter 框架底层组件在异步初始化前完全准备就绪
  WidgetsFlutterBinding.ensureInitialized();

  print('[游戏开机] 正在激活后台双流异步流水线...');
  // 核心：开机立刻开始在另一个核里织网屯关卡，不阻碍主线程
  // 这里用 async/await 是为了让第一关数据在进到 GameScreen 前至少有一个在池子里
  LevelManager().initializeSync(); 

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '挪了个箭',
      debugShowCheckedModeBanner: false, // 顺手关掉右上角的 Debug 标签，画面更清爽
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}