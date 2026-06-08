import 'package:flutter/material.dart';

class TargetAllocationScreen extends StatelessWidget {
  const TargetAllocationScreen({super.key}); // Fixed constructor name to match class

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Target Allocation Matrix"), // Fixed title context
      ),
      body: const Center(
        child: Text("Line Assignments & Operational Targets Initializing..."),
      ),
    );
  }
}
