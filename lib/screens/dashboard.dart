import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';



import '../app_state.dart';
import '../models.dart';

import 'profile_provisioning.dart';
import 'kit_synchronizer.dart';
import 'ledger_transfer.dart';
import 'target_allocation.dart';
import 'billing_dispatch.dart';
import 'analytics.dart';
import 'execution_floor.dart';
import 'shift_clock.dart';

// ============================================================================
// MODULE 1: DASHBOARD ENTRYPOINT WITH ROLE-BASED ACCESS CONTROL MATRIX
// ============================================================================

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // EXCEL / CSV CYCLE TIME DATA EXPORT ENGINE
  Future<void> _exportOperationalBatchReport(BuildContext context, EMSStateEngine state) async {
    List<List<dynamic>> rows = [];
    
    // SpreadSheet Column Headers Matching Requirements Exactly
    rows.add([
      "Batch Number",
      "Client Name",
      "Job Name",
      "Department/Division",
      "Total Logged Processing Minutes",
      "Completed Output Volume",
      "Anomalies & Defect Loss % Flags",
      "Delay / Halt Constraints Captured"
    ]);

    if (state.batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No operational batch data available to generate spreadsheet."), backgroundColor: Colors.orange)
      );
      return;
    }

    // Process each batch to calculate times, yields, and collect issues
    for (var batch in state.batches) {
      final relatedLogs = state.rawHourlyLogs.where((l) => l['batch_no'].toString() == batch.batchNo).toList();
      
      String raisedAnomalies = "";
      String delayComments = "";
      int totalEstimatedDuration = relatedLogs.length * 60; // Approximate processing cycle per hourly milestone chunks

      for (var log in relatedLogs) {
        if (log['comments'] != null && log['comments'].toString().trim().isNotEmpty) {
          delayComments += "[Comment]: ${log['comments']} | ";
        }
        
        // Extract and format numerical issue loss percentages
        if (log['defects'] != null && log['defects'] is Map) {
          final Map defectMap = log['defects'];
          defectMap.forEach((key, value) {
            double numericVal = double.tryParse(value.toString()) ?? 0.0;
            if (numericVal > 0) {
              raisedAnomalies += "$key: ${numericVal.toStringAsFixed(0)}% loss | ";
            }
          });
        }
      }

      // Safely read target parameters dynamically to bypass model field variations
      dynamic targetQtyValue = 0;
      try {
        final dynamic dynamicBatch = batch;
        targetQtyValue = dynamicBatch.targetQty ?? dynamicBatch.targetQuantity ?? 0;
      } catch (_) {
        targetQtyValue = 0;
      }

      rows.add([
        batch.batchNo,
        batch.clientName,
        batch.jobName,
        batch.status == 'OPEN' ? 'Active Floor Assembly Node' : 'Completed Dispatch Routing',
        totalEstimatedDuration,
        targetQtyValue,
        raisedAnomalies.isEmpty ? "No Issues Flagged" : raisedAnomalies,
        delayComments.isEmpty ? "No Delay Logs Recorded" : delayComments
      ]);
    }

    try {
      final String csvData = ListToCsvConverter().convert(rows);

      await Share.share(
         csvData,
         subject: 'Mishon EMS Automated Cycle-Time & Delay Analytics Report',
      );
    } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
          content: Text("Spreadsheet compilation error: $e"),
          backgroundColor: Colors.red,
       ),
    );
   }
   }

  @override
  Widget build(BuildContext context) {
    final stateEngine = Provider.of<EMSStateEngine>(context);
    final String role = (stateEngine.currentUser?.role ?? 'operator').trim().toLowerCase();

    // Route operators and floor supervisors directly to the simplified, contextual shopfloor UI
    if (role != 'admin' && role != 'manager') {
      return const OperatorSupervisorHub();
    }

    final bool isAdmin = (role == 'admin');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Mishon EMS Suite [${role.toUpperCase()}]"),
        backgroundColor: const Color(0xFF008080),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: "Export Excel Report",
            onPressed: () => _exportOperationalBatchReport(context, stateEngine),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              stateEngine.clearSession();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        crossAxisSpacing: 16.0,
        mainAxisSpacing: 16.0,
        children: [
          _buildMenuCard(
            context,
            title: "Shift Attendance",
            icon: Icons.timer,
            color: Colors.blue,
            destination: const ShiftClockTerminalView(),
          ),
          _buildMenuCard(
            context,
            title: "Log Production",
            icon: Icons.precision_manufacturing,
            color: Colors.green,
            destination: const ExecutionFloorAssemblyView(),
          ),
          _buildMenuCard(
            context,
            title: "Ledger Route",
            icon: Icons.swap_horiz,
            color: Colors.orange,
            destination: const InterDepartmentLedgerGatewayView(),
          ),
          _buildMenuCard(
            context,
            title: "Analytics Portal",
            icon: Icons.analytics,
            color: Colors.purple,
            destination: const OperationalAnalyticsMatrixView(),
          ),
          if (isAdmin) ...[
            _buildMenuCard(
              context,
              title: "Kit Synchronizer",
              icon: Icons.sync,
              color: Colors.teal,
              destination: const KitSynchronizerScreen(),
            ),
            _buildMenuCard(
              context,
              title: "Target Allocation",
              icon: Icons.assignment_turned_in,
              color: Colors.indigo,
              destination: const TargetAllocationScreen(),
            ),
            _buildMenuCard(
              context,
              title: "Billing & Dispatch",
              icon: Icons.local_shipping,
              color: Colors.red,
              destination: const BillingDispatchScreen(),
            ),
            _buildMenuCard(
              context,
              title: "Profile Config",
              icon: Icons.admin_panel_settings,
              color: Colors.blueGrey,
              destination: const ProfileProvisioningScreen(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget destination,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MODULE 2: SUB-DASHBOARD FOR OPERATORS & SUPERVISORS
// ============================================================================

class OperatorSupervisorHub extends StatelessWidget {
  const OperatorSupervisorHub({super.key});

  @override
  Widget build(BuildContext context) {
    final stateEngine = Provider.of<EMSStateEngine>(context);
    final user = stateEngine.currentUser;
    final String displayRole = (user?.role ?? 'Operator').trim().toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Mishon Shopfloor [$displayRole]"),
        backgroundColor: const Color(0xFF004d4d),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              stateEngine.clearSession();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: const Color(0xFFE6F2F2),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Welcome, ${user?.username ?? 'User'}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
                      const SizedBox(height: 4),
                      Text("Segment Allocation: ${user?.segment ?? 'None'} | Team: ${user?.team ?? 'None'}", style: const TextStyle(color: Colors.black87)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text("Operational Utilities", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d))),
              const SizedBox(height: 12),
              _buildListTileRoute(
                context,
                icon: Icons.timer,
                color: Colors.blue,
                title: "Shift Attendance System",
                subtitle: "Clock In / Out of current production shift",
                destination: const ShiftClockTerminalView(),
              ),
              const Divider(),
              _buildListTileRoute(
                context,
                icon: Icons.precision_manufacturing,
                color: Colors.green,
                title: "Log Hourly Production Status",
                subtitle: "Update execution quantities and yields",
                destination: const ExecutionFloorAssemblyView(),
              ),
              const Divider(),
              _buildListTileRoute(
                context,
                icon: Icons.swap_horiz,
                color: Colors.orange,
                title: "Inter-Department Transfer",
                subtitle: "Route batch components to next production sequence",
                destination: const InterDepartmentLedgerGatewayView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListTileRoute(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget destination,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destination)),
      ),
    );
  }
}

// ============================================================================
// MODULE 3: PRODUCTION ANALYTICS PORTS & YIELD DEFECT MONITOR
// ============================================================================

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
      return t.team?.trim() == state.currentUser?.team?.trim() && t.segment?.trim() == state.currentUser?.segment?.trim();
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
                            if (res.statusCode == 200 && mounted) {
                              await state.fetchAndSyncFromBackend();
                              _targetQtyController.clear();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Target profile committed safely."), backgroundColor: Colors.green)
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Failed to save target entry bounds securely."), backgroundColor: Colors.red)
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isProcessingTarget = false);
                            }
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

            const Text(
              "Comparative Yield Performance vs Target Bounds", 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
            ),
            const SizedBox(height: 12),
            displayTargets.isEmpty
                ? const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No tracking targets registered within your visibility layer.", style: TextStyle(color: Colors.grey))))
                : Column(
                    children: displayTargets.map((tm) {
                      int totalCompleted = 0;
                      if (state.processingCounters.containsKey(tm.batchNo)) {
                        final internalSideMap = state.processingCounters[tm.batchNo];
                        totalCompleted += (internalSideMap?['TOP'] ?? 0) + (internalSideMap?['BOTTOM'] ?? 0);
                      }

                      bool isBelowTarget = totalCompleted < tm.targetQty;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8), 
                          side: BorderSide(color: isBelowTarget ? Colors.amber.shade300 : Colors.green.shade300, width: 1),
                        ),
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

            const Text(
              "Live Production, QC & Shift Stream Logs",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
            ),
            const SizedBox(height: 12),
            state.rawHourlyLogs.isEmpty
                ? const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No live logs emitted from assembly lines or shift gates yet.", style: TextStyle(color: Colors.grey))))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.rawHourlyLogs.length,
                    itemBuilder: (context, index) {
                      final log = state.rawHourlyLogs[state.rawHourlyLogs.length - 1 - index];
                      
                      // 1) SHIFT ATTENDANCE TRACKING DETECTOR
                      bool isShiftPunch = log.containsKey('punch_type') || log['comments'].toString().contains('SHIFT');

                      if (isShiftPunch) {
                        String type = log['punch_type']?.toString() ?? 'SHIFT TRANSACTION';
                        String op = log['operator_username']?.toString() ?? 'System';
                        String ts = log['log_timestamp']?.toString() ?? '';
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          color: const Color(0xFFF0FDF4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Colors.greenAccent, width: 1.5),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.alarm, color: Colors.green, size: 28),
                            title: Text("Attendance: $type", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534))),
                            subtitle: Text("Operator Node: $op\nTimestamp Marker: $ts"),
                          ),
                        );
                      }

                      // 2) STANDARD PRODUCTION HOURLY LOGS WITH SECURE DEFECT PERCENT CAPTURES
                      String logBatch = log['batch_no']?.toString() ?? '';
                      String operator = log['operator_username']?.toString() ?? 'Unknown';
                      String side = log['side']?.toString() ?? 'TOP';
                      String qty = log['qty_done']?.toString() ?? '0';
                      String comment = log['comments']?.toString() ?? '';
                      String timestamp = log['log_timestamp']?.toString() ?? '';

                      List<String> activeDefectLosses = [];
                      if (log['defects'] != null && log['defects'] is Map) {
                        final Map defectMap = log['defects'];
                        defectMap.forEach((key, value) {
                          double val = double.tryParse(value.toString()) ?? 0.0;
                          if (val > 0) {
                            activeDefectLosses.add("$key: ${val.toStringAsFixed(0)}% Loss");
                          }
                        });
                      }

                      bool hasAnomalies = activeDefectLosses.isNotEmpty || 
                                          comment.toLowerCase().contains('error') || 
                                          comment.toLowerCase().contains('halt');

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: hasAnomalies ? const Color(0xFFFFF5F5) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: hasAnomalies ? Colors.red.shade300 : Colors.grey.shade200, width: hasAnomalies ? 1.5 : 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Batch #$logBatch ➔ $qty Pcs ($side Side)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  if (hasAnomalies)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                      child: const Text("ANOMALY FLAG", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text("Operator Sign-Off: $operator", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                              
                              if (activeDefectLosses.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Text("Flagged Yield Loss Rates:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: activeDefectLosses.map((defText) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
                                    child: Text(defText, style: TextStyle(fontSize: 11, color: Colors.red.shade900, fontWeight: FontWeight.w600)),
                                  )).toList(),
                                ),
                              ],

                              if (comment.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text("Operator Comments: \"$comment\"", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: hasAnomalies ? Colors.red.shade800 : Colors.black54)),
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
