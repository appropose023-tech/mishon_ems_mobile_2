import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class KitSynchronizerScreen extends StatelessWidget {
  const KitSynchronizerScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Kit Synchronizer Matrix"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: state.isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF008080)),
                  SizedBox(height: 16),
                  Text("Synchronizing floor kit deployment configurations..."),
                ],
              ),
            )
          : const Center(
              child: Text(
                "Kit Synchronization Pipeline Operational.",
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
              ),
            ),
    );
  }
}
