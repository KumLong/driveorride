import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class RouteReport {
  final int id;
  final String category;
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

class ReportService {
  SupabaseClient get _client => Supabase.instance.client;
  final _auth = AuthService();

  static const _roadProximityMeters = 2000;

  static const _reportLifetime = Duration(hours: 3);

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

  Future<List<RouteReport>> getPendingReports(String category) async {
    final data = await _client
        .from('route_reports')
        .select()
        .eq('category', category)
        .eq('status', 'pending')
        .order('created_at');
    return (data as List).map((row) => RouteReport.fromJson(row)).toList();
  }

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

  Future<void> resolveReport(int id) async {
    await _client.from('route_reports').update({'resolved_at': DateTime.now().toIso8601String()}).eq('id', id);
  }

  Future<List<RouteReport>> getRecentActivity({int limit = 10}) async {
    final data = await _client
        .from('route_reports')
        .select()
        .or('reviewed_at.not.is.null,resolved_at.not.is.null')
        .order('reviewed_at', ascending: false, nullsFirst: false)
        .limit(limit);
    return (data as List).map((row) => RouteReport.fromJson(row)).toList();
  }

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

  Future<List<RouteReport>> getReportHistory(String category) async {
    final data = await _client
        .from('route_reports')
        .select()
        .eq('category', category)
        .or('status.eq.approved,status.eq.rejected')
        .order('reviewed_at', ascending: false, nullsFirst: false);
    return (data as List).map((row) => RouteReport.fromJson(row)).toList();
  }

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

      for (final routePoint in routePoints) {
        if (distance(reportPoint, routePoint) <= _roadProximityMeters) return true;
      }
      return false;
    }).toList();
  }
}