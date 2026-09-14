import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../services/gtfs_service.dart';
import '../theme.dart';

class ReviewerReportsScreen extends StatefulWidget {
  final String category;
  const ReviewerReportsScreen({super.key, required this.category});

  @override
  State<ReviewerReportsScreen> createState() => _ReviewerReportsScreenState();
}

class _ReviewerReportsScreenState extends State<ReviewerReportsScreen> with SingleTickerProviderStateMixin {
  final _reportService = ReportService();
  late final TabController _tabController;

  List<RouteReport> _pending = [];
  List<RouteReport> _active = [];
  List<RouteReport> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final pending = await _reportService.getPendingReports(widget.category);
    final active = await _reportService.getActiveApprovedReports(widget.category);
    final history = await _reportService.getReportHistory(widget.category);
    if (mounted) setState(() { _pending = pending; _active = active; _history = history; _loading = false; });
  }

  Future<void> _approve(int id) async {
    await _reportService.approveReport(id);
    _refresh();
  }

  Future<void> _reject(int id) async {
    await _reportService.rejectReport(id);
    _refresh();
  }

  Future<void> _resolve(int id) async {
    await _reportService.resolveReport(id);
    _refresh();
  }

  IconData _iconFor(String issueType) {
    switch (issueType) {
      case 'accident': return Icons.car_crash;
      case 'breakdown': return Icons.train;
      case 'delay': return Icons.schedule;
      default: return Icons.info_outline;
    }
  }

  Color _colorFor(String issueType) {
    switch (issueType) {
      case 'accident': return Colors.redAccent;
      case 'breakdown': return Colors.orange;
      case 'delay': return AppColors.mint;
      default: return Colors.grey;
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 1) return 'Less than a minute';
    if (d.inHours < 1) return '${d.inMinutes} min';
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return minutes > 0 ? '$hours hr $minutes min' : '$hours hr';
  }

  Widget _statusBadge(RouteReport report) {
    if (report.resolvedAt != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppColors.mintLight, borderRadius: BorderRadius.circular(10)),
        child: const Text('Resolved', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.mint)),
      );
    }
    if (report.status == 'approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
        child: Text('Approved', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
      child: Text('Rejected', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
    );
  }

  Widget _reportCard(RouteReport report, {List<Widget>? actions, Widget? badge, VoidCallback? onTap}) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(report.issueType), size: 16, color: _colorFor(report.issueType)),
              const SizedBox(width: 6),
              Text(report.issueType[0].toUpperCase() + report.issueType.substring(1),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _colorFor(report.issueType))),
              if (badge != null) ...[const SizedBox(width: 8), badge],
              const Spacer(),
              Text('${GtfsService.formatDateTime(report.createdAt)} · ${_timeAgo(report.createdAt)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 8),
          if (report.stationName != null)
            Text(report.stationName!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.teal)),
          if (report.latitude != null)
            Text('Lat ${report.latitude!.toStringAsFixed(4)}, Lng ${report.longitude!.toStringAsFixed(4)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(report.description, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          if (actions != null) ...[
            const SizedBox(height: 12),
            Row(children: actions),
          ],
          if (onTap != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Spacer(),
              Text('Tap for review details', style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
              Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
            ]),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: card);
  }

  void _showReportDetail(RouteReport report) {

    Duration? activeDuration;
    if (report.reviewedAt != null && report.resolvedAt != null) {
      activeDuration = report.resolvedAt!.difference(report.reviewedAt!);
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(_iconFor(report.issueType), color: _colorFor(report.issueType)),
                const SizedBox(width: 8),
                const Expanded(child: Text('Review Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.teal))),
                _statusBadge(report),
              ]),
              const SizedBox(height: 16),
              _detailRow('Report ID', '#${report.id}'),
              _detailRow('Category', widget.category == 'road' ? 'Road' : 'Rail'),
              _detailRow('Issue type', report.issueType[0].toUpperCase() + report.issueType.substring(1)),
              if (report.stationName != null) _detailRow('Station', report.stationName!),
              if (report.latitude != null) _detailRow('Location', '${report.latitude!.toStringAsFixed(4)}, ${report.longitude!.toStringAsFixed(4)}'),
              const Divider(height: 24),
              const Text('Description', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(report.description, style: const TextStyle(fontSize: 12, color: Colors.black87)),
              const Divider(height: 24),
              _detailRow('Submitted', '${GtfsService.formatDateTime(report.createdAt)} · ${_timeAgo(report.createdAt)}'),
              if (report.reviewedAt != null)
                _detailRow(report.status == 'approved' ? 'Approved' : 'Rejected',
                    '${GtfsService.formatDateTime(report.reviewedAt!)} · ${_timeAgo(report.reviewedAt!)}'),
              if (report.resolvedAt != null)
                _detailRow('Resolved', '${GtfsService.formatDateTime(report.resolvedAt!)} · ${_timeAgo(report.resolvedAt!)}'),
              if (activeDuration != null)
                _detailRow('Was active for', _formatDuration(activeDuration)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.category == 'road' ? 'Road Reports' : 'Rail Reports'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.mint,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.mint,
          isScrollable: true,
          tabs: [
            Tab(text: 'Pending (${_pending.length})'),
            Tab(text: 'Active (${_active.length})'),
            Tab(text: 'History (${_history.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [

          _pending.isEmpty
              ? _emptyState('No pending reports')
              : RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _pending.length,
              itemBuilder: (context, i) {
                final report = _pending[i];
                return _reportCard(report, actions: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(report.id),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approve(report.id),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600),
                      child: const Text('Approve'),
                    ),
                  ),
                ]);
              },
            ),
          ),

          _active.isEmpty
              ? _emptyState('No active warnings right now')
              : RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _active.length,
              itemBuilder: (context, i) {
                final report = _active[i];
                return _reportCard(report, actions: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _resolve(report.id),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Mark Resolved'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.mint),
                    ),
                  ),
                ]);
              },
            ),
          ),

          _history.isEmpty
              ? _emptyState('No past decisions yet')
              : RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (context, i) => _reportCard(_history[i], badge: _statusBadge(_history[i]), onTap: () => _showReportDetail(_history[i])),
            ),
          ),
        ],
      ),
    );
  }
}