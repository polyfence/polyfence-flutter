import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../models/app_models.dart';
import '../theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  final bool isTracking;
  final LatLng? location;
  final double? accuracy;
  final int zoneCount;

  const MapScreen({
    super.key,
    required this.isTracking,
    this.location,
    this.accuracy,
    required this.zoneCount,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _hasAnimatedToUser = false;

  // Null Island fallback (0, 0) used at the lowest zoom until the first
  // GPS fix arrives. We deliberately avoid a "demo" landmark here —
  // the example app ships with no preconfigured zones, so the map
  // exists to show the user's own position once tracking starts.
  static const ll.LatLng _defaultCenter = ll.LatLng(0, 0);

  ll.LatLng? _toMapLatLng(LatLng? loc) {
    if (loc == null) return null;
    return ll.LatLng(loc.latitude, loc.longitude);
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-center to user location on first GPS fix
    if (!_hasAnimatedToUser && widget.location != null) {
      _hasAnimatedToUser = true;
      final target = _toMapLatLng(widget.location)!;
      _mapController.move(target, 15.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userLatLng = _toMapLatLng(widget.location);
    final center = userLatLng ?? _defaultCenter;
    final initialZoom = userLatLng != null ? 13.0 : 2.0;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: initialZoom,
          ),
          children: [
            // OSM raster tiles. The userAgentPackageName matches the
            // example's Android applicationId and iOS bundle id —
            // identifies this app to OSM's tile servers per their
            // attribution and usage policy.
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'io.polyfence.example.flutter',
            ),

            // User location marker (blue dot)
            if (userLatLng != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: userLatLng,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.info,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.info.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

            // OpenStreetMap attribution. Required by OSM tile usage terms.
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomRight,
              showFlutterMapAttribution: false,
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),

        // Status overlay at top
        Positioned(
          top: AppTheme.spacingMd,
          left: AppTheme.spacingLg,
          right: AppTheme.spacingLg,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: AppTheme.spacingSm,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: AppTheme.overlayShadow,
            ),
            alignment: Alignment.center,
            child: Text(
              _buildOverlayText(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.foreground,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _buildOverlayText() {
    final parts = <String>[];
    final count = widget.zoneCount;
    parts.add('$count zone${count != 1 ? 's' : ''}');
    parts.add(widget.isTracking ? 'Tracking' : 'Stopped');
    if (widget.accuracy != null) {
      parts.add('±${widget.accuracy!.round()}m');
    }
    return parts.join(' · ');
  }
}
