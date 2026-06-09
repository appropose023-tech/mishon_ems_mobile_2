import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

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
              // Direct assignment instead of non-existent clearSession method
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
