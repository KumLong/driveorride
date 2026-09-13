import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../services/auth_service.dart';
import '../services/gtfs_service.dart';
import '../theme.dart';
import 'splash_screen.dart';
import 'reviewer_reports_screen.dart';

/// The DEDICATED landing screen for reviewer accounts — genuinely
/// separate from MainShell, with no access to saved locations,
/// trips, or savings goals, since a reviewer's role has no real need
/// for any of that (principle of least privilege — give access to
/// exactly what a role needs, nothing more).
class ReviewerHomeScreen extends StatefulWidget {
  const ReviewerHomeScreen({super.key});

  @override
  State<ReviewerHomeScreen> createState() => _ReviewerHomeScreenState();
}

class _ReviewerHomeScreenState extends State<ReviewerHomeScreen> {
  final _reportService = ReportService();
  final _auth = AuthService();

  Map<String, int> _stats = {'pending': 0, 'approved': 0, 'rejected': 0};
  int _pendingRoad = 0;
  int _pendingRail = 0;
  List<RouteReport> _activeRoad = [];
  List<RouteReport> _activeRail = [];
  List<RouteReport> _recentActivity = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final stats = await _reportService.getReviewerStats();
    final pendingRoad = await _reportService.getPendingReports('road');
    final pendingRail = await _reportService.getPendingReports('rail');
    final activeRoad = await _reportService.getActiveApprovedReports('road');
    final activeRail = await _reportService.getActiveApprovedReports('rail');
    final recentActivity = await _reportService.getRecentActivity();
    if (mounted) {
      setState(() {
        _stats = stats;
        _pendingRoad = pendingRoad.length;
        _pendingRail = pendingRail.length;
        _activeRoad = activeRoad;
        _activeRail = activeRail;
        _recentActivity = recentActivity;
        _loading = false;
      });
    }
  }

  Future<void> _resolve(int id) async {
    await _reportService.resolveReport(id);
    _loadData();
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashScreen()), (route) => false);
    }
  }

  IconData _iconFor(String issueType) {
    switch (issueType) {
      case 'accident': return Icons.car_crash;
      case 'breakdown': return Icons.train;
      case 'delay': return Icons.schedule;
      default: return Icons.info_outline;
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }

  /// Describes what actually happened to a report, and when — a
  /// resolved report takes priority in the description (it's the
  /// most recent thing that happened to it), otherwise falls back to
  /// whether it was approved or rejected.
  (String, IconData, Color, DateTime) _activityDescription(RouteReport report) {
    if (report.resolvedAt != null) {
      return ('Resolved', Icons.check_circle, AppColors.mint, report.resolvedAt!);
    }
    if (report.status == 'approved') {
      return ('Approved', Icons.check, Colors.green, report.reviewedAt ?? report.createdAt);
    }
    return ('Rejected', Icons.close, Colors.redAccent, report.reviewedAt ?? report.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final allActive = [..._activeRoad, ..._activeRail]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Reviewer dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.teal)),
              const Text('Signed in as reviewer', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),

              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else ...[
                // Two category boxes — now show BOTH pending AND
                // active counts, so it's clear at a glance whether
                // something needs review AND whether something is
                // currently live and showing to real users.
                Row(
                  children: [
                    Expanded(child: _categoryBox(
                      icon: Icons.directions_car,
                      label: 'Road reports',
                      pendingCount: _pendingRoad,
                      activeCount: _activeRoad.length,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewerReportsScreen(category: 'road')))
                          .then((_) => _loadData()),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _categoryBox(
                      icon: Icons.train,
                      label: 'Rail reports',
                      pendingCount: _pendingRail,
                      activeCount: _activeRail.length,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewerReportsScreen(category: 'rail')))
                          .then((_) => _loadData()),
                    )),
                  ],
                ),
                const SizedBox(height: 24),

                // Stats row
                const Text('TODAY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _statCard('${_stats['pending']}', 'Pending', AppColors.teal)),
                    const SizedBox(width: 8),
                    Expanded(child: _statCard('${_stats['approved']}', 'Approved', Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _statCard('${_stats['rejected']}', 'Rejected', Colors.redAccent)),
                  ],
                ),
                const SizedBox(height: 24),

                // Real, detailed, currently-active reports — directly
                // visible here, not buried inside a tab you have to
                // navigate into. This is what actually shows "is
                // there something live right now that hasn't been
                // resolved yet" at a glance, with full details.
                Row(
                  children: [
                    const Text('ACTIVE NOW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                    const Spacer(),
                    if (allActive.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Text('${allActive.length} live', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                if (allActive.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Icon(Icons.check_circle_outline, color: Colors.grey.shade400, size: 20),
                      const SizedBox(width: 10),
                      Text('No active warnings right now', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ]),
                  )
                else
                  ...allActive.map((report) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(report.category == 'road' ? Icons.directions_car : Icons.train, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(report.category == 'road' ? 'Road' : 'Rail', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Icon(_iconFor(report.issueType), size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(report.issueType[0].toUpperCase() + report.issueType.substring(1),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                          const Spacer(),
                          Text('${GtfsService.formatDateTime(report.createdAt)} · ${_timeAgo(report.createdAt)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ]),
                        const SizedBox(height: 6),
                        if (report.stationName != null)
                          Text(report.stationName!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.teal)),
                        if (report.latitude != null)
                          Text('Lat ${report.latitude!.toStringAsFixed(4)}, Lng ${report.longitude!.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(report.description, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _resolve(report.id),
                            icon: const Icon(Icons.check, size: 14),
                            label: const Text('Mark Resolved', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.mint, side: const BorderSide(color: AppColors.mint)),
                          ),
                        ),
                      ],
                    ),
                  )),

                const SizedBox(height: 20),

                // Real activity history — what's actually been
                // decided recently, not just what's pending or active.
                const Text('RECENT ACTIVITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                if (_recentActivity.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Icon(Icons.history, color: Colors.grey.shade400, size: 20),
                      const SizedBox(width: 10),
                      Text('No activity yet', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ]),
                  )
                else
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: _recentActivity.map((report) {
                        final (label, icon, color, activityTime) = _activityDescription(report);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, size: 14, color: color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$label · ${report.issueType[0].toUpperCase()}${report.issueType.substring(1)}'
                                          '${report.stationName != null ? ' at ${report.stationName}' : ''}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.teal),
                                    ),
                                    Text('${GtfsService.formatDateTime(activityTime)} · ${_timeAgo(activityTime)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Log Out'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.grey.shade700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryBox({required IconData icon, required String label, required int pendingCount, required int activeCount, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: AspectRatio(
          aspectRatio: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30, color: AppColors.mint),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.teal), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              // Two separate badges — pending (needs a decision) vs
              // active (already live, currently showing to users) —
              // these mean genuinely different things and shouldn't
              // be merged into one ambiguous number.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4, runSpacing: 4,
                children: [
                  if (pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Text('$pendingCount pending', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                    ),
                  if (activeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Text('$activeCount active', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                    ),
                  if (pendingCount == 0 && activeCount == 0)
                    Text('All clear', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}