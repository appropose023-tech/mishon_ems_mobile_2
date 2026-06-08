import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

// Import all your feature screens directly

import 'profile_provisioning.dart';
import 'kit_synchronizer.dart';
import 'ledger_transfer.dart';
import 'target_allocation.dart';
import 'billing_dispatch.dart';
import 'analytics.dart';
import 'execution_floor.dart';
import 'shift_clock.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stateEngine = Provider.of<EMSStateEngine>(context);
    final String role = (stateEngine.currentUser?.role ?? 'operator').trim().toLowerCase();

    // 1. If Operator or Supervisor: Route them straight to their explicit shop floor utility loop
    if (role != 'admin' && role != 'manager') {
      return const OperatorSupervisorHub();
    }

    // 2. If Management (Admin/Manager): Build the full system administration grid console
    final bool isAdmin = (role == 'admin');

    return Scaffold(
      appBar: AppBar(
        title: Text("Mishon EMS Suite [${role.toUpperCase()}]"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Gracefully wipes memory variables & targets route
              stateEngine.clearSession();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          if (isAdmin)
            _buildMenuCard(context, "1. Profile Provisioning", Icons.person_add, Colors.blue, const ProfileProvisioningScreen()),
          
          _buildMenuCard(context, "2. Kit Issue Sync", Icons.sync_alt, Colors.green, const KitSynchronizerScreen()),
          _buildMenuCard(context, "3. Routing Assignment", Icons.alt_route, Colors.orange, const InterDepartmentLedgerGatewayView()),
          _buildMenuCard(context, "4. Target Allocation", Icons.track_changes, Colors.deepPurple, const TargetAllocationScreen()),
          _buildMenuCard(context, "5. Billing & Dispatch", Icons.local_shipping, Colors.red, const BillingDispatchScreen()),
          _buildMenuCard(context, "6. System Analysis", Icons.analytics, Colors.teal, AnalyticsScreen()),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color color, Widget targetScreen) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => targetScreen)),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 44, color: color),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// Fallback layout built explicitly for Floor Operators and Supervisors
class OperatorSupervisorHub extends StatelessWidget {
  const OperatorSupervisorHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("EMS Shopfloor Console")),
      body: Padding(
        padding: const EdgeInsets.all(16.0), // Fixed the "Parry" typo here
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.timer, color: Colors.blue),
              title: const Text("Shift Attendance System"),
              subtitle: const Text("Clock In / Out of current production shift"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ShiftClockScreen())),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.precision_manufacturing, color: Colors.green),
              title: const Text("Log Hourly Production Status"),
              subtitle: const Text("Update execution quantities and yields"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ExecutionFloorAssemblyView())),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: Colors.orange),
              title: const Text("Inter-Department Transfer"),
              subtitle: const Text("Route batch components to next production sequence"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InterDepartmentLedgerGatewayView())),
            ),
          ],
        ),
      ),
    );
  }
}
