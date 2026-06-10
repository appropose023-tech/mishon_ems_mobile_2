import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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

  @override
  Widget build(BuildContext context) {
    final stateEngine = Provider.of<EMSStateEngine>(context);
    final String role = (stateEngine.currentUser?.role ?? 'operator').trim().toLowerCase();

    // Check privileges: Route operators and supervisors to the simplified shopfloor layout
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
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Direct state mutations to flush operational tokens safely
              stateEngine.currentUser = null;
              stateEngine.activePunchInTime = null;
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
// MODULE 2: RE-ARCHITECTED SUB-DASHBOARD FOR OPERATORS & SUPERVISORS
// ============================================================================

class OperatorSupervisorHub extends StatelessWidget {
  const OperatorSupervisorHub({super.key});

  @override
  Widget build(BuildContext context) {
    final stateEngine = Provider.of<EMSStateEngine>(context);
    final user = stateEngine.currentUser;
    final String displayRole = (user?.role ?? 'Operator').toUpperCase();

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
              stateEngine.currentUser = null;
              stateEngine.activePunchInTime = null;
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

    // Only allow open batches to receive new targets inside management module
    final activeBatches = state.batches.where((b) => b.status == 'OPEN').toList();

    // Visibility Scoping: Workers see targeted items matching their node assignment; Management sweeps all.
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

            // SECTION 1: COMPARATIVE PERFORMANCE METRICS & GAUGES
            const Text(
              "Comparative Yield Performance vs Target Bounds", 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF004d4d)),
            ),
            const SizedBox(height: 12),
            displayTargets.isEmpty
                ? const Card(child: Padding(padding: EdgeInsets.all(16.0), child: Text("No tracking targets registered within your visibility layer.", style: TextStyle(color: Colors.grey))))
                : Column(
                    children: displayTargets.map((tm) {
                      // Sum production output for this specific batch from the runtime engine counter cache
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
                                      style: TextStyle(
                                        fontSize: 10, 
                                        fontWeight: FontWeight.bold, 
                                        color: isBelowTarget ? Colors.amber.shade900 : Colors.green.shade900,
                                      ),
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

            // SECTION 2: LIVE STREAM TERMINAL VIEW FOR HOURLY LOG PACKETS
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
                      // Reverse structural reader index to map latest packets directly at topmost row
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
