// Analytics Integration Example
// File: example/lib/analytics_example.dart

import 'package:flutter/material.dart';
import 'package:polyfence/polyfence.dart';
import 'utils/logger.dart';

/// Example showing how to integrate Polyfence Analytics
class AnalyticsExample extends StatefulWidget {
  const AnalyticsExample({super.key});

  @override
  State<AnalyticsExample> createState() => _AnalyticsExampleState();
}

class _AnalyticsExampleState extends State<AnalyticsExample> {
  bool _analyticsEnabled = false;
  String _sessionData = 'No session data yet';

  @override
  void initState() {
    super.initState();
    _initializeWithAnalytics();
  }

  Future<void> _initializeWithAnalytics() async {
    try {
      // Initialize Polyfence with analytics configuration
      await Polyfence.instance.initialize(
        analyticsConfig: AnalyticsConfig(
          enabled: _analyticsEnabled,
          industryCategory: 'logistics',
          useCase: 'delivery_tracking',
          apiEndpoint: 'https://polyfence.io/api/v1/analytics/session',
        ),
      );

      // Listen to geofence events for analytics
      Polyfence.instance.onGeofenceEvent.listen((event) {
        // Analytics are automatically recorded by the service
        // You can also manually record additional metrics if needed
        _updateSessionData();
      });
    } catch (e) {
      logDebug('Failed to initialize analytics: $e');
    }
  }

  void _updateSessionData() {
    // This would typically show current session metrics
    setState(() {
      _sessionData = 'Session active - check console for analytics data';
    });
  }

  void _toggleAnalytics() async {
    setState(() {
      _analyticsEnabled = !_analyticsEnabled;
    });

    // Re-initialize with new analytics setting
    await _initializeWithAnalytics();
  }

  void _addTestZone() async {
    try {
      final zone = Zone.circle(
        id: 'test_zone_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Test Zone',
        center: PolyfenceLocation(
          latitude: 37.422,
          longitude: -122.084,
        ),
        radius: 100,
      );

      await Polyfence.instance.addZone(zone);
      logDebug('Test zone added for analytics testing');
    } catch (e) {
      logDebug('Failed to add test zone: $e');
    }
  }

  void _simulateDetection() {
    // Detection telemetry is now aggregated by native polyfence-core (D016).
    // No Dart-side recording needed — native TelemetryAggregator handles it.
    logDebug('Detection telemetry handled by native polyfence-core');
    _updateSessionData();
  }

  void _simulateError() {
    // Error telemetry is now aggregated by native polyfence-core (D016).
    logDebug('Error telemetry handled by native polyfence-core');
    _updateSessionData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Example'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analytics Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Analytics Enabled:'),
                        const SizedBox(width: 16),
                        Switch(
                          value: _analyticsEnabled,
                          onChanged: (_) => _toggleAnalytics(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: ${_analyticsEnabled ? "Enabled" : "Disabled"}',
                      style: TextStyle(
                        color: _analyticsEnabled ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Session Data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(_sessionData),
                    const SizedBox(height: 16),
                    const Text(
                      'Analytics automatically collect:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Detection timing and accuracy'),
                    const Text('• Zone type usage (circle vs polygon)'),
                    const Text('• Battery efficiency'),
                    const Text('• Error counts'),
                    const Text('• Session duration'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _addTestZone,
                          child: const Text('Add Test Zone'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _simulateDetection,
                          child: const Text('Simulate Detection'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _simulateError,
                      child: const Text('Simulate Error'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Privacy Features',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('✅ No GPS coordinates collected'),
                    Text('✅ No device IDs or personal data'),
                    Text('✅ Session-based aggregation only'),
                    Text('✅ Opt-in by default (disabled)'),
                    Text('✅ Data sent only on session end'),
                    Text('✅ Automatic deduplication'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
