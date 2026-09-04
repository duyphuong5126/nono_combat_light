import 'package:flutter/material.dart';
import 'package:flame/game.dart';

import 'main_game.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: GameWidget(game: DotaGame())),
    ),
  );
}
