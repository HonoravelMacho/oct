import 'package:flutter/material.dart';

import '../../core/noir_theme.dart';

Future<bool> showCreditGate(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: NoirPalette.surfaceHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      title: const Text(
        'LIMITE GRATIS ATINGIDO',
        style: TextStyle(letterSpacing: 2, fontSize: 15),
      ),
      content: const Text(
        'Voce usou suas 5 atividades do ciclo gratuito.\n'
        'Assista a um video para liberar mais 5 partidas e treinos.',
        style: TextStyle(fontSize: 13, color: NoirPalette.textDim),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('AGORA NAO'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('ASSISTIR E LIBERAR'),
        ),
      ],
    ),
  );
  return result == true;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: NoirPalette.surfaceHigh,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
