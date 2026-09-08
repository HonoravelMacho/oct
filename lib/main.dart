import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Tela cheia imersiva: esconde a barra de navegação do Android
  // (voltar/home/recentes). Ela só reaparece com gesto de borda e some
  // sozinha em seguida.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final prefs = await SharedPreferences.getInstance();
  runApp(OctApp(prefs: prefs));
}
