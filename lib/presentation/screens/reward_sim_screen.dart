import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/noir_theme.dart';

class RewardSimScreen extends StatefulWidget {
  const RewardSimScreen({super.key});

  @override
  State<RewardSimScreen> createState() => _RewardSimScreenState();
}

class _RewardSimScreenState extends State<RewardSimScreen> {
  static const int totalSeconds = 5;
  int remaining = totalSeconds;
  Timer? _timer;
  bool completed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        remaining--;
        if (remaining <= 0) {
          completed = true;
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('FECHAR'),
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    border: Border.all(color: NoirPalette.border),
                    color: NoirPalette.surface,
                  ),
                  child: Column(
                    children: [
                      const Text('ANUNCIO PREMIADO',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 3)),
                      const SizedBox(height: 4),
                      const Text('DEMONSTRACAO - GOOGLE ADMOB TEST MODE',
                          style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.5,
                              color: NoirPalette.textDim)),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: remaining / totalSeconds,
                              strokeWidth: 3,
                            ),
                            Text('$remaining s',
                                style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        '+5 PARTIDAS E TREINOS\nAO CONCLUIR O VIDEO',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, height: 1.6),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: completed
                        ? () => Navigator.pop(context, true)
                        : null,
                    child: Text(completed
                        ? 'PULAR ANUNCIO E RECEBER'
                        : 'PULAR EM $remaining...'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
