import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// A single road or rail issue report.
class RouteReport {
  final int id;
  final String category; // 'road' or 'rail'
  final String? stationName;
  final double? latitude;
  final double? longitude;
  final String issueType;
  final String description;
  final String status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final DateTime? reviewedAt;

  RouteReport({
    required this.id,
    required this.category,
    this.stationName,
    this.latitude,
    this.longitude,
    required this.issueType,
    required this.description,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.reviewedAt,
  });

  factory RouteReport.fromJson(Map<String, dynamic> data) => RouteReport(
    id: data['id'],
    category: data['category'],
    stationName: data['station_name'],
    latitude: (data['latitude'] as num?)?.toDouble(),
    longitude: (data['longitude'] as num?)?.toDouble(),
    issueType: data['issue_type'],
    description: data['description'],
    status: data['status'],
    createdAt: DateTime.parse(data['created_at']),
    resolvedAt: data['resolved_at'] != null ? DateTime.parse(data['resolved_at']) : null,
    reviewedAt: data['reviewed_at'] != null ? DateTime.parse(data['reviewed_at']) : null,
  );
}

/// Handles everything related to road/rail issue reports — submission,
/// reviewer approval/rejection, and matching APPROVED reports to a
/// specific user's route.
///
/// Road reports are matched by real GEOGRAPHIC PROXIMITY (is the
/// report's saved location close to any point along this specific
/// route?), since unlike rail lines, there's no fixed, named list of
/// "roads" to match against — every drive is technically a unique
/// path. Rail reports are matched by STATION NAME instead, since real
/// GTFS line/station names already provide a clean, exact way to
/// group reports.
class ReportService {
  SupabaseClient get _client => Supabase.instance.client;
  final _auth = AuthService();

  // How close (in meters) a road report's location must be to any
  // point on a route for it to be considered relevant. Deliberately
  // generous (2km) since GPS/reporting isn't pinpoint-precise, and a
  // missed relevant report is a worse outcome than an occasional
  // extra one shown.
  static const _roadProximityMeters = 2000;

  // Auto-expiry — even if a reviewer forgets to manually resolve a
  // report, it stops being shown to others after this long. This is
  // a real, if simple, safety net for the honest concern of "what if
  // the problem gets fixed and nobody clears it" — a permanent
  // warning that's actually stale would be worse than no warning at
  // all.
  static const _reportLifetime = Duration(hours: 3);

  /// Submits a new report — always starts as 'pending', invisible to
  /// everyone except reviewers until approved.
  Future<void> submitReport({
    required String category,
    String? stationName,
    double? latitude,
    double? longitude,
    required String issueType,
    required String description,
  }) async {
    final userId = _auth.currentUser?.id;
    await _client.from('route_reports').insert({
      'reporter_id': userId,
      'category': category,
      'station_name': stationName,
      'latitude': latitude,
      'longitude': longitude,
      'issue_type': issueType,
      'description': description,
    });
  }

  /// Fetches all PENDING reports for a given category — used by the
  /// reviewer's approval screen.
  Future<List<RouteReport>> getPendingReports(String category) async {
    final data = await _client
        .from('route_reports')
        .select()
        .eq('category', category)
        .eq('status', 'pending')
        .order('created_at');
    return (data as List).map((row) => RouteReport.fromJson(row)).toList();
  }

  /// Counts of pending/approved/rejected reports overall — used for
  /// the reviewer dashboard's summary stats.
  Future<Map<String, int>> getReviewerStats() async {
    final pending = await _client.from('route_reports').select('id').eq('status', 'pending');
    final approved = await _client.from('route_reports').select('id').eq('status', 'approved');
    final rejected = await _client.from('route_reports').select('id').eq('status', 'rejected');
    return {
      'pending': (pending as List).length,
      'approved': (approved as List).length,
      'rejected': (rejected as List).length,
    };
  }

  Future<void> approveReport(int id) async {
    await _client.from('route_reports').update({
      'status': 'approved',
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> rejectReport(int id) async {
    await _client.from('route_reports').update({
      'status': 'rejected',
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Marks a report as resolved — this is how a reviewer clears an
  /// approved warning once the real problem is actually over, instead
  /// of it staying visible forever (or until the auto-expiry kicks in).
  Future<void> resolveReport(int id) async {
    await _client.from('route_reports').update({'resolved_at': DateTime.now().toIso8601String()}).eq('id', id);
  }

  /// Fetches a real activity feed — everything that's actually been
  /// DECIDED on (approved or rejected) or resolved recently, most
  /// recent first. This is what powers the dashboard's "Recent
  /// Activity" section, giving a genuine history of what's happened,
  /// not just what's currently pending or active.
  Future<List<RouteReport>> getRecentActivity({int limit = 10}) async {
    final data = await _client
        .from('route_reports')
        .select()
        .or('reviewed_at.not.is.null,resolved_at.not.is.null')
        .order('reviewed_at', ascending: false, nullsFirst: false)
        .limit(limit);
    return (data as List).map((row) => RouteReport.fromJson(row)).toList();
  }

  /// Fetches currently ACTIVE (approved, not yet resolved, not yet
  /// expired) reports for a category — this is what the reviewer's
  /// "Active" tab shows, letting them manually resolve something once
  /// it's genuinely fixed.
  Future<List<RouteReport>> getActiveApprovedReports(String category) async {
    final cutoff = DateTime.now().subtract(_reportLifetime).toIso8601String();
    final data = await _client
        .from('route_reports')
        .select()
        .eq('category', category)
        .eq('status', 'approved')
        .isFilter('resolved_at', null)
        .gte('created_at', cutoff)
        .order('created_at', ascending: false);
    return (data as List).map((row) => RouteReport.fromJson(row)).toList();
  }

  /// Fetches EVERY past decision (approved or rejected) for a
  /// category, most recent first — this is what powers a real
  /// "History" tab, letting a reviewer actually browse and see full
  /// details of past reports, not just a bare count in the stats.
  Future<List<RouteReport>> getReportHistory(String category) async {
    final data = await _client
        .from('route_reports')
        .select()
        .eq('category', category)
        .or('status.eq.approved,status.eq.rejected')
        .order('reviewed_at', ascending: false, nullsFirst: false);
    return (data as List).map((row) => RouteReport.fromJson(row)).toList();
  }

  /// Finds APPROVED rail reports matching any of the given station
  /// names — used to show relevant warnings on a transit route.
  /// Excludes resolved reports, and anything past the auto-expiry
  /// window — regular users should only ever see genuinely current
  /// warnings, never something already fixed or long stale.
  Future<List<RouteReport>> getApprovedRailReports(List<String> stationNames) async {
    if (stationNames.isEmpty) return [];
    final cutoff = DateTime.now().subtract(_reportLifetime).toIso8601String();
    final data = await _client
        .from('route_reports')
        .select()
        .eq('category', 'rail')
        .eq('status', 'approved')
        .isFilter('resolved_at', null)
        .gte('created_at', cutoff)
        .inFilter('station_name', stationNames);
    return (data as List).map((row) => RouteReport.fromJson(row)).toList();
  }

  /// Finds APPROVED road reports whose saved location is within
  /// [_roadProximityMeters] of ANY point along the given route —
  /// this is the real proximity-matching logic discussed: since
  /// roads have no fixed names to match against, we check real
  /// physical closeness instead. Same resolved/expiry exclusion as
  /// the rail version above.
  Future<List<RouteReport>> getApprovedRoadReports(List<LatLng> routePoints) async {
    if (routePoints.isEmpty) return [];
    final cutoff = DateTime.now().subtract(_reportLifetime).toIso8601String();
    final data = await _client
        .from('route_reports')
        .select()
        .eq('category', 'road')
        .eq('status', 'approved')
        .isFilter('resolved_at', null)
        .gte('created_at', cutoff);
    final allApproved = (data as List).map((row) => RouteReport.fromJson(row)).toList();

    final distance = Distance();
    return allApproved.where((report) {
      if (report.latitude == null || report.longitude == null) return false;
      final reportPoint = LatLng(report.latitude!, report.longitude!);
      // Check against every point on the route — if ANY point is
      // close enough, this report is relevant to this specific trip.
      for (final routePoint in routePoints) {
        if (distance(reportPoint, routePoint) <= _roadProximityMeters) return true;
      }
      return false;
    }).toList();
  }
}