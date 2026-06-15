import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../app_state.dart';

class ShiftClockTerminalView extends StatefulWidget {
  const ShiftClockTerminalView({Key? key}) : super(key: key);

  @override
  State<ShiftClockTerminalView> createState() => _ShiftClockTerminalViewState();
}

class _ShiftClockTerminalViewState extends State<ShiftClockTerminalView> {
  Timer? _timer;
  int _elapsedMinutes = 0;
  bool _isProcessingPunch = false;

  // Track historical punch events locally to preserve login and logout references
  final List<Map<String, String>> _punchSessionHistory = [];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final state = Provider.of<EMSStateEngine>(context, listen: false);
      if (state.activePunchInTime != null) {
        setState(() {
          _elapsedMinutes = DateTime.now().difference(state.activePunchInTime!).inMinutes;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _triggerPunchSequence(EMSStateEngine state, bool targetPunchIn) async {
    setState(() => _isProcessingPunch = true);
    
    String currentTimestamp = DateTime.now().toLocal().toString().substring(0, 19);
    
    await state.toggleShiftPunch(targetPunchIn);
    
    setState(() {
      _isProcessingPunch = false;
      if (targetPunchIn) {
        _punchSessionHistory.add({"event": "LOGIN / PUNCH-IN", "timestamp": currentTimestamp});
      } else {
        _punchSessionHistory.add({"event": "LOGOUT / PUNCH-OUT", "timestamp": currentTimestamp});
        _elapsedMinutes = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);
    bool punchedIn = state.activePunchInTime != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      // Clean system AppBar configuration guarantees the default back-arrow navigation is active
      appBar: AppBar(
        title: const Text("Shift Clock Console"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(punchedIn ? Icons.verified_user : Icons.gavel, size: 64, color: punchedIn ? Colors.green : Colors.orange),
                      const SizedBox(height: 12),
                      Text(
                        punchedIn ? "ACTIVE DUTY CYCLE RUNNING" : "TERMINAL STATE: CLOSED",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: punchedIn ? Colors.green : Colors.orange),
                      ),
                      const Divider(height: 24),
                      Text(
                        punchedIn 
                            ? "Active Session Login: ${state.activePunchInTime!.toLocal().toString().substring(0, 19)}" 
                            : "Status: Awaiting operational attendance handshake",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      if (punchedIn) ...[
                        const SizedBox(height: 6),
                        Text("Active Run Session Duration: $_elapsedMinutes Minutes", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      ]
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              _isProcessingPunch
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF008080)))
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: punchedIn ? Colors.red : Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _triggerPunchSequence(state, !punchedIn),
                      child: Text(
                        punchedIn ? "EXECUTE SHIFT PUNCH-OUT" : "EXECUTE SHIFT PUNCH-IN", 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                    ),
              
              if (punchedIn) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFBBF24))),
                  child: const Text(
                    "ALERT: Duty cycle running. Keep processing counters logging inside industrial terminals.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                )
              ],
              
              const SizedBox(height: 24),
              const Text("🕒 Session Timeline Audit Parameters (Today)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF004d4d))),
              const SizedBox(height: 8),

              // Dynamic history dashboard tracking precise chronological operations records
              Expanded(
                child: _punchSessionHistory.isEmpty
                    ? const Center(child: Text("No clock telemetry logs reported within active application instance.", style: TextStyle(color: Colors.grey, fontSize: 12)))
                    : ListView.builder(
                        itemCount: _punchSessionHistory.length,
                        itemBuilder: (context, idx) {
                          final logItem = _punchSessionHistory[idx];
                          bool isLogin = logItem['event'] == "LOGIN / PUNCH-IN";
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: Colors.white,
                            child: ListTile(
                              dense: true,
                              leading: Icon(isLogin ? Icons.login : Icons.logout, color: isLogin ? Colors.green : Colors.red, size: 18),
                              title: Text(logItem['event']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text("Timestamp: ${logItem['timestamp']}", style: const TextStyle(fontSize: 12)),
                            ),
                          );
                        },
                      ),
              ),
              
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF008080)),
                label: const Text("RETURN TO SHOPFLOOR HUB", style: TextStyle(color: Color(0xFF008080), fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
