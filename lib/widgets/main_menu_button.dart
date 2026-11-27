import 'package:flutter/material.dart';

final GlobalKey<ScaffoldState> mainNavigationScaffoldKey =
    GlobalKey<ScaffoldState>();

class MainMenuButton extends StatelessWidget {
  const MainMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => mainNavigationScaffoldKey.currentState?.openDrawer(),
      icon: const Icon(Icons.menu),
      tooltip: 'Buka menu',
    );
  }
}
