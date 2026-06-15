import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_state.dart';
import '../models.dart';

class OperationalAnalyticsMatrixView extends StatefulWidget {
  const OperationalAnalyticsMatrixView({Key? key}) : super(key: key);

  @override
  State<OperationalAnalyticsMatrixView> createState() => _OperationalAnalyticsMatrixViewState();
}

class _OperationalAnalyticsMatrixViewState extends State<OperationalAnalyticsMatrixView> {
  final TextEditingController _targetQtyController = TextEditingController();
  String? _selectedBatchTarget;
  String _segmentTarget = "SMT";
  String _teamTarget = "Production";
  bool _isProcessingTarget = false;

  @override
  void dispose() {
    _targetQtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<EMSStateEngine>(context);
    final String currentRole = (state.currentUser?.role ?? 'operator').trim().toLowerCase();
    final bool isManagement = (currentRole == 'admin' || currentRole == 'manager');

    final activeBatches = state.batches.where((b) => b.status == 'OPEN').toList();

    final displayTargets = state.targetingMatrix.where((t) {
      if (isManagement) return true;
      return t.team == state.currentUser?.team && t.segment == state.currentUser?.segment;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Analytics & Quality Target Control"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // MANAGEMENT TARGET ASSIGNMENT MODULE
            if (isManagement) ...[
              const Text(
                "Establish New Shop Floor Target Constraint",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedBatchTarget,
                hint: const Text("Select active sequence batch..."),
                decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                items: activeBatches.map((b) {
                  return DropdownMenuItem(value: b.batchNo, child: Text("Batch #${b.batchNo} - ${b.jobName}"));
                }).toList(),
                onChanged: (v) => setState(() => _selectedBatchTarget = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _segmentTarget,
                      decoration: const InputDecoration(labelText: "Floor Segment Node", border: OutlineInputBorder()),
                      items: ["SMT", "Through hole", "None"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _segmentTarget = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _teamTarget,
                      decoration: const InputDecoration(labelText: "Operational Sub-Team", border: OutlineInputBorder()),
                      items: ["Production", "Quality", "None"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _teamTarget = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _targetQtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Target Quantity Threshold Bound", border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
              ),
              const SizedBox(height: 16),
              _isProcessingTarget 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF008080))) 
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008080),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      int q = int.tryParse(_targetQtyController.text) ?? 0;
                      if (_selectedBatchTarget != null && q > 0) {
                        setState(() => _isProcessingTarget = true);
                        try {
                          final res = await http.post(
                            Uri.parse('${state.baseUrl}/api/provision_target'),
                            headers: {"Content-Type": "application/json"},
                            body: json.encode({
                              "batch_no": _selectedBatchTarget,
                              "segment": _segmentTarget,
                              "team": _teamTarget,
                              "target_qty": q
                            }),
                          );
                          if (res.statusCode == 200) {
                            await state.fetchAndSyncFromBackend();
                            _targetQtyController.clear();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Target profile committed safely."), backgroundColor: Colors.green)
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Network failure: $e"), backgroundColor: Colors.red)
                            );
                          }
                        }
                        setState(() => _isProcessingTarget = false);
                      }
                    },
                    child: const Text("INJECT FACTORY FLOOR TARGET", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
              const Divider(height: 32, thickness: 1.5),
            ],

            // LIVE MONITORING: WORKER SHIFT ATTENDANCE VERIFICATION LOGS
            const Text(
              "⏱️ Worker Shift Attendance Verification Logs",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004d4d)),
            ),
            const SizedBox(height: 8),
            state.rawHourlyLogs.where((l) => l['action_type'] == 'PUNCH_IN' || l['action_type'] == 'PUNCH_OUT').isEmpty
              ? const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No attendance verification timestamps recorded on the floor yet.", style: TextStyle(color: Colors.grey, fontSize: 13))))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.rawHourlyLogs.length,
                  itemBuilder: (context, index) {
                    // Read items in reverse order to keep latest logs at the top
                    final item = state.rawHourlyLogs[state.rawHourlyLogs.length - 1 - index];
                    if (item['action_type'] == 'PUNCH_IN' || item['action_type'] == 'PUNCH_OUT') {
                      bool isPunchIn = item['action_type'] == 'PUNCH_IN';
                      return Card(
                        color: isPunchIn ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Icon(isPunchIn ? Icons.login : Icons.logout, color: isPunchIn ? Colors.emerald : Colors.red),
                          title: Text("Operator: ${item['operator_username']} — ${item['action_type']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Timestamp Structural Stamp: ${item['log_timestamp']}"),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
            const SizedBox(height: 24),

            // CURRENT TARGET TRACKING VISUALIZATION MATRIX
            const Text("Active Floor Allocation Targets Matrix", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
            const SizedBox(height: 8),
            displayTargets.isEmpty
                ? const Text("No active tracking metrics inside selected cluster parameters.", style: TextStyle(color: Colors.grey, fontSize: 13))
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.4, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: displayTargets.length,
                    itemBuilder: (context, idx) {
                      final target = displayTargets[idx];
                      return Card(
                        color: Colors.white,
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Batch #${target.batchNo}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF008080))),
                              Text("Node: ${target.segment}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              Text("Team: ${target.team}", style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Text("Bound: ${target.targetQty} Pcs", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

            const Divider(height: 32, thickness: 1.5),
            const Text("📋 Historical Process Output Metric Pipeline", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
            const SizedBox(height: 12),

            state.rawHourlyLogs.where((l) => l['action_type'] != 'PUNCH_IN' && l['action_type'] != 'PUNCH_OUT').isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text("No transaction batches emitted across shop floor layers yet.", style: TextStyle(color: Colors.grey))))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.rawHourlyLogs.length,
                    itemBuilder: (context, index) {
                      final log = state.rawHourlyLogs[state.rawHourlyLogs.length - 1 - index];
                      if (log['action_type'] == 'PUNCH_IN' || log['action_type'] == 'PUNCH_OUT') return const SizedBox.shrink();
                      
                      String logBatch = log['batch_no']?.toString() ?? '';
                      String operator = log['operator_username']?.toString() ?? 'Unknown';
                      String side = log['side']?.toString() ?? 'TOP';
                      String qty = log['qty_done']?.toString() ?? '0';
                      String comment = log['comments']?.toString() ?? '';
                      String timestamp = log['log_timestamp']?.toString() ?? '';

                      Map<String, dynamic> defsMap = {};
                      if (log['defects'] != null) {
                        if (log['defects'] is Map) {
                          defsMap = Map<String, dynamic>.from(log['defects']);
                        } else if (log['defects'] is String) {
                          try { defsMap = json.decode(log['defects']); } catch (_) {}
                        }
                      }

                      List<String> activeDefectsFormatted = [];
                      defsMap.forEach((key, val) {
                        if (val is num && val > 0) {
                          activeDefectsFormatted.add("$key ($val%)");
                        } else if (val == true || val == "true") {
                          activeDefectsFormatted.add(key);
                        }
                      });

                      bool explicitlyHasIssues = activeDefectsFormatted.isNotEmpty;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: explicitlyHasIssues ? const Color(0xFFFFF1F2) : Colors.white,
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Batch #$logBatch ➔ $qty Pcs", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Chip(
                                    label: Text(side, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    backgroundColor: const Color(0xFFE6F2F2),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  )
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text("Operator ID Profile: $operator", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                              
                              if (explicitlyHasIssues) ...[
                                const SizedBox(height: 6),
                                const Text("Registered Quality Defect Variances:", style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                                ...activeDefectsFormatted.map((def) => Padding(
                                  padding: const EdgeInsets.only(left: 6.0, top: 1.0, bottom: 1.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.label_important, size: 12, color: Colors.red),
                                      const SizedBox(width: 4),
                                      Expanded(child: Text(def, style: TextStyle(fontSize: 12, color: Colors.red.shade900, fontWeight: FontWeight.w500))),
                                    ],
                                  ),
                                )).toList(),
                              ],

                              if (comment.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text("Operator Comments: \"$comment\"", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: explicitlyHasIssues ? Colors.red.shade800 : Colors.black54)),
                              ],
                              const Divider(height: 12),
                              Text("Log Timestamp: $timestamp", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
