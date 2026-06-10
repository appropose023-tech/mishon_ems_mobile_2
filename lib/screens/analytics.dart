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

    // Only allow open batches to receive new targets inside management module
    final activeBatches = state.batches.where((b) => b.status == 'OPEN').toList();

    // Target Filtering Rule: Workers see targets matching their segment/team; Management sees all.
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Target profile committed safely."), backgroundColor: Colors.green)
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Failed to save target entry bounds securely."), backgroundColor: Colors.red)
                            );
                          } finally {
                            setState(() => _isProcessingTarget = false);
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please select a valid batch identifier and non-zero target volume."), backgroundColor: Colors.orange)
                          );
                        }
                      },
                      child: const Text("REGISTER TARGET PARAMETER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
              const Divider(height: 40, thickness: 1.5),
            ],

            // 1) PERFORMANCE MONITORING (TARGET VS LIVE YIELD WITH WARNING ALERTS)
            const Text(
              "Comparative Yield Performance vs Target Bounds", 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
            ),
            const SizedBox(height: 12),
            displayTargets.isEmpty
                ? const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No tracking targets registered within your visibility layer.", style: TextStyle(color: Colors.grey))))
                : Column(
                    children: displayTargets.map((tm) {
                      // Sum production output for this specific batch from the engine counter cache
                      int totalCompleted = 0;
                      if (state.processingCounters.containsKey(tm.batchNo)) {
                        final internalSideMap = state.processingCounters[tm.batchNo];
                        totalCompleted += (internalSideMap?['TOP'] ?? 0) + (internalSideMap?['BOTTOM'] ?? 0);
                      }

                      bool isBelowTarget = totalCompleted < tm.targetQty;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isBelowTarget ? Colors.amber.shade300 : Colors.green.shade300, width: 1)),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Batch Reference: #${tm.batchNo}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isBelowTarget ? Colors.amber.shade100 : Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isBelowTarget ? "LOW YIELD ALERT" : "TARGET SATISFIED",
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isBelowTarget ? Colors.amber.shade900 : Colors.green.shade900),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text("Target Context Scope: ${tm.segment} — ${tm.team}", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Current Output: $totalCompleted Units", style: TextStyle(fontWeight: FontWeight.w600, color: isBelowTarget ? Colors.red.shade700 : Colors.green.shade700)),
                                  Text("Target Bound: ${tm.targetQty} Units", style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: tm.targetQty > 0 ? (totalCompleted / tm.targetQty).clamp(0.0, 1.0) : 0.0,
                                color: isBelowTarget ? Colors.amber.shade700 : Colors.green,
                                backgroundColor: Colors.grey.shade200,
                                minHeight: 6,
                              )
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

            const Divider(height: 40, thickness: 1.5),

            // 2) PRODUCTION & QC HOURLY LOGS TERMINAL HUB VIEW
            const Text(
              "Live Production & QC Hourly Status Stream Logs",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
            ),
            const SizedBox(height: 12),
            state.rawHourlyLogs.isEmpty
                ? const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No live hourly records emitted from assembly lines yet.", style: TextStyle(color: Colors.grey))))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.rawHourlyLogs.length,
                    itemBuilder: (context, index) {
                      // Read items in reverse order to keep latest logs at the top
                      final log = state.rawHourlyLogs[state.rawHourlyLogs.length - 1 - index];
                      
                      String logBatch = log['batch_no']?.toString() ?? '';
                      String operator = log['operator_username']?.toString() ?? 'Unknown';
                      String side = log['side']?.toString() ?? 'TOP';
                      String qty = log['qty_done']?.toString() ?? '0';
                      String comment = log['comments']?.toString() ?? '';
                      String timestamp = log['log_timestamp']?.toString() ?? '';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.white,
                        child: ListTile(
                          leading: const Icon(Icons.history_edu, color: Color(0xFF008080)),
                          title: Text("Batch #$logBatch ➔ $qty Units ($side Layer)"),
                          subtitle: Text("Operator: $operator\nComments: $comment\nTime: $timestamp"),
                          isThreeLine: true,
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
