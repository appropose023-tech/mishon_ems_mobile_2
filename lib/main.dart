import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => EMSStateEngine(),
      child: const MishonSolutionsEMSApplicationRoot(),
    ),
  );
}

class MishonSolutionsEMSApplicationRoot extends StatelessWidget {
  const MishonSolutionsEMSApplicationRoot({super.key}); // Modernized to super.key syntax

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mishon Solutions EMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF008080),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF008080),
          primary: const Color(0xFF008080),
          secondary: const Color(0xFF004d4d),
        ),
        useMaterial3: true,
      ),
      // Set the initial home landing gate
      home: const IdentityGatewayPortal(),
      
      // Explicit Named Routing Table to support dashboard redirection chains safely
      routes: {
        '/login': (context) => const IdentityGatewayPortal(),
        '/dashboard': (context) => const DashboardScreen(),
      },
    );
  }
}
