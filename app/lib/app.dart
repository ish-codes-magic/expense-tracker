import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/nocturne.dart';
import 'widgets/nocturne_widgets.dart';

class SlipApp extends StatelessWidget {
  const SlipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Slip',
      debugShowCheckedModeBanner: false,
      theme: buildNocturneTheme(),
      routerConfig: router,
      scaffoldMessengerKey: messengerKey,
    );
  }
}
