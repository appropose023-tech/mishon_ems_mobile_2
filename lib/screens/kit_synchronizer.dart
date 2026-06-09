import 'package:flutter/material.dart';

class KitSynchronizerScreen extends StatelessWidget {
  const KitSynchronizerScreen({super.key}); // Constructor matches class name now
  
@override
Widget build(BuildContext context) {
  final state = Provider.of<EMSStateEngine>(context);
  if (state.isLoading) {
    return const Scaffold(
      body: Center(child: Text("Kit Synchronizer feature is synchronizing ......")),
    ); 
  }
  return Scaffold( ... );
}
}
