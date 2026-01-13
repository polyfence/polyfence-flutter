-- ============================================================================
-- POLYFENCE ANALYTICS QUERY LIBRARY
-- ============================================================================
--
-- Purpose: Self-service analytics queries for PolyFence plugin telemetry
-- Database: Supabase PostgreSQL
-- Table: telemetry_sessions (adjust if your table name differs)
--
-- HOW TO USE THIS FILE:
-- 1. Open Supabase Dashboard → SQL Editor
-- 2. Copy/paste the query you need
-- 3. Adjust the time range (default: last 30 days)
-- 4. Run and export results to CSV or copy to markdown
--
-- QUERY ORGANIZATION:
-- ├─ Section 1: Product Value Analytics (prove PolyFence is good)
-- ├─ Section 2: Operational Health Monitoring (catch issues early)
-- ├─ Section 3: Diagnostics & Root Cause Analysis (debug failures)
-- ├─ Section 4: Platform Comparison (iOS vs Android)
-- ├─ Section 5: Version Analysis (track improvements)
-- └─ Section 6: Utility Queries (data quality, exports)
--
-- RECOMMENDED CADENCE:
-- - Product Value: Monthly (update README benchmarks)
-- - Operational Health: Weekly (Monday morning review)
-- - Diagnostics: On-demand (when investigating issues)
-- - Platform/Version: After new releases
--
-- ============================================================================


-- ============================================================================
-- SECTION 1: PRODUCT VALUE ANALYTICS
-- ============================================================================
-- Purpose: Prove that PolyFence is performant, reliable, and battery-efficient
-- Audience: Potential customers, README.md, marketing materials
-- Update frequency: Monthly
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1 OVERALL PERFORMANCE SCORECARD
-- ----------------------------------------------------------------------------
-- What it does: Single-query overview of all key metrics vs targets
-- When to run: Monthly, for README.md updates
-- How to use: Copy results to README.md "Performance Benchmarks" section
-- ----------------------------------------------------------------------------
SELECT
  'Detection Speed (P95)' as metric,
  ROUND(AVG(detection_time_p95_ms), 1) as value,
  'ms' as unit,
  '<500ms' as target,
  CASE
    WHEN AVG(detection_time_p95_ms) < 500 THEN '✅ Pass'
    ELSE '❌ Fail'
  END as status
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '30 days'

UNION ALL

SELECT
  'Detection Speed (Average)',
  ROUND(AVG(detection_time_avg_ms), 1),
  'ms',
  '<200ms',
  CASE WHEN AVG(detection_time_avg_ms) < 200 THEN '✅ Pass' ELSE '❌ Fail' END
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '30 days'

UNION ALL

SELECT
  'GPS Accuracy',
  ROUND(AVG(gps_ok_ratio) * 100, 1),
  '%',
  '>90%',
  CASE WHEN AVG(gps_ok_ratio) > 0.9 THEN '✅ Pass' ELSE '❌ Fail' END
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '30 days'

UNION ALL

SELECT
  'Battery Impact',
  ROUND(AVG(battery_drain_avg_pct_per_hr), 2),
  '%/hr',
  '<2%/hr',
  CASE WHEN AVG(battery_drain_avg_pct_per_hr) < 2 THEN '✅ Pass' ELSE '❌ Fail' END
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '30 days'

UNION ALL

SELECT
  'Background Reliability',
  ROUND((1 - AVG(service_interruptions::float / NULLIF(session_duration_minutes, 0))) * 100, 1),
  '%',
  '>95%',
  CASE
    WHEN (1 - AVG(service_interruptions::float / NULLIF(session_duration_minutes, 0))) > 0.95
    THEN '✅ Pass'
    ELSE '❌ Fail'
  END
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '30 days'
  AND session_duration_minutes > 0

UNION ALL

SELECT
  'Detection Success Rate',
  ROUND(AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) * 100, 1),
  '%',
  '>80%',
  CASE
    WHEN AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) > 0.8
    THEN '✅ Pass'
    ELSE '⚠️  Review'
  END
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '30 days';

-- INTERPRETATION GUIDE:
-- ✅ All metrics passing → Update README.md with these numbers
-- ❌ Any metric failing → Investigate before promoting numbers publicly
-- ⚠️  Detection success <80% → Expected if users have short sessions, but document


-- ----------------------------------------------------------------------------
-- 1.2 PERFORMANCE BY PLATFORM (for README table)
-- ----------------------------------------------------------------------------
-- What it does: Compare iOS vs Android performance metrics
-- When to run: Monthly, alongside scorecard
-- How to use: Create side-by-side comparison table in docs
-- ----------------------------------------------------------------------------
SELECT
  platform,
  COUNT(*) as total_sessions,
  ROUND(AVG(detection_time_p95_ms), 1) as detection_p95_ms,
  ROUND(AVG(detection_time_avg_ms), 1) as detection_avg_ms,
  ROUND(AVG(gps_accuracy_avg_m), 1) as gps_accuracy_meters,
  ROUND(AVG(gps_ok_ratio) * 100, 1) as gps_ok_percentage,
  ROUND(AVG(battery_drain_avg_pct_per_hr), 2) as battery_pct_per_hr,
  ROUND(AVG(session_duration_minutes), 0) as avg_session_min,
  ROUND(AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) * 100, 1) as detection_success_pct
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY platform
ORDER BY platform;

-- EXAMPLE OUTPUT FOR README.md:
-- | Metric                  | Android | iOS   | Target   |
-- |-------------------------|---------|-------|----------|
-- | Detection Speed (P95)   | 200ms   | 180ms | <500ms ✅ |
-- | GPS Accuracy            | 15.2m   | 14.8m | <50m ✅   |
-- | Battery Impact          | 0.8%/hr | 0.9%/hr | <2%/hr ✅ |
-- | Detection Success Rate  | 16.2%   | 15.6% | >80% ⚠️   |


-- ----------------------------------------------------------------------------
-- 1.3 REAL-WORLD USAGE STATISTICS (for marketing)
-- ----------------------------------------------------------------------------
-- What it does: Generate impressive stats for marketing materials
-- When to run: Quarterly or when you hit milestones
-- How to use: Use in landing pages, blog posts, press releases
-- ----------------------------------------------------------------------------
SELECT
  COUNT(DISTINCT app_identifier) as total_apps_using_polyfence,
  COUNT(*) as total_tracking_sessions,
  SUM(detections_total) as total_zone_detections,
  ROUND(SUM(session_duration_minutes) / 60.0, 0) as total_hours_tracked,
  COUNT(DISTINCT CASE WHEN platform = 'android' THEN app_identifier END) as android_apps,
  COUNT(DISTINCT CASE WHEN platform = 'ios' THEN app_identifier END) as ios_apps,
  -- Zone usage stats
  SUM((zone_usage->>'circle')::int) as total_circle_zones_used,
  SUM((zone_usage->>'polygon')::int) as total_polygon_zones_used
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '90 days';

-- EXAMPLE MARKETING COPY:
-- "Powering location intelligence for 47 production apps"
-- "Processing over 12,000 geofence detections daily"
-- "Trusted for 3,400+ hours of background tracking"


-- ============================================================================
-- SECTION 2: OPERATIONAL HEALTH MONITORING
-- ============================================================================
-- Purpose: Monitor plugin health and catch issues before users complain
-- Audience: Internal team, weekly reviews
-- Update frequency: Weekly (every Monday morning)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1 WEEKLY HEALTH CHECK (run every Monday)
-- ----------------------------------------------------------------------------
-- What it does: Single query to assess weekly plugin health
-- When to run: Weekly, Monday morning
-- How to use: Review results, investigate any concerning trends
-- ----------------------------------------------------------------------------
SELECT
  -- Time period
  'Last 7 Days' as period,

  -- Volume metrics
  COUNT(*) as total_sessions,
  COUNT(DISTINCT app_identifier) as active_apps,

  -- Performance metrics
  ROUND(AVG(detection_time_p95_ms), 1) as avg_p95_latency_ms,
  ROUND(MAX(detection_time_p95_ms), 1) as max_p95_latency_ms,

  -- Reliability metrics
  ROUND(AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) * 100, 1) as detection_success_rate_pct,
  ROUND(AVG(gps_ok_ratio) * 100, 1) as avg_gps_quality_pct,
  ROUND(AVG(battery_drain_avg_pct_per_hr), 2) as avg_battery_drain_pct_hr,

  -- Error metrics
  SUM((error_counts->>'gps_error')::int) as total_gps_errors,
  SUM((error_counts->>'gps_timeout')::int) as total_gps_timeouts,
  SUM(service_interruptions) as total_service_interruptions,

  -- Platform breakdown
  COUNT(CASE WHEN platform = 'android' THEN 1 END) as android_sessions,
  COUNT(CASE WHEN platform = 'ios' THEN 1 END) as ios_sessions,

  -- Quality indicators
  ROUND(AVG(CASE WHEN battery_optimization_disabled THEN 1 ELSE 0 END) * 100, 1) as battery_opt_disabled_pct

FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '7 days';

-- RED FLAGS TO WATCH FOR:
-- ❌ detection_success_rate < 15% AND declining → Investigate urgently
-- ❌ avg_p95_latency_ms > 500ms → Performance regression
-- ❌ total_gps_timeouts > 10% of sessions → GPS issues
-- ❌ total_service_interruptions > 5% of sessions → Background reliability problem
-- ⚠️  avg_battery_drain > 2%/hr → Battery impact concern


-- ----------------------------------------------------------------------------
-- 2.2 DAILY TREND ANALYSIS (7-day rolling)
-- ----------------------------------------------------------------------------
-- What it does: Show daily trends to spot degradation early
-- When to run: Weekly or when investigating performance issues
-- How to use: Look for sudden drops in success rate or spikes in latency
-- ----------------------------------------------------------------------------
SELECT
  DATE_TRUNC('day', created_at)::date as day,
  COUNT(*) as sessions,
  ROUND(AVG(detection_time_p95_ms), 1) as p95_latency_ms,
  ROUND(AVG(gps_ok_ratio) * 100, 1) as gps_quality_pct,
  ROUND(AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) * 100, 1) as detection_success_pct,
  SUM((error_counts->>'gps_timeout')::int) as gps_timeouts,
  SUM(service_interruptions) as service_interruptions
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY day
ORDER BY day DESC;

-- WHAT TO LOOK FOR:
-- 📈 Increasing sessions → Good, plugin adoption growing
-- 📉 Detection success dropping day-over-day → Investigate
-- ⚡ Latency spike on specific day → Check for plugin/OS updates
-- 🔴 GPS timeouts concentrated on one day → Potential infrastructure issue


-- ----------------------------------------------------------------------------
-- 2.3 ERROR BREAKDOWN (identify most common issues)
-- ----------------------------------------------------------------------------
-- What it does: Count and categorize all errors from error_counts JSONB field
-- When to run: Weekly or when error rates are high
-- How to use: Prioritize bug fixes based on error frequency
-- ----------------------------------------------------------------------------
WITH error_expansion AS (
  SELECT
    id,
    created_at,
    platform,
    plugin_version,
    jsonb_each_text(error_counts) as error_detail
  FROM telemetry_sessions
  WHERE created_at > NOW() - INTERVAL '30 days'
    AND error_counts IS NOT NULL
    AND error_counts != '{}'::jsonb
)
SELECT
  (error_detail).key as error_type,
  SUM((error_detail).value::int) as total_occurrences,
  COUNT(DISTINCT id) as sessions_affected,
  ROUND(COUNT(DISTINCT id)::float / (SELECT COUNT(*) FROM telemetry_sessions WHERE created_at > NOW() - INTERVAL '30 days') * 100, 2) as pct_of_sessions,
  -- Platform breakdown
  COUNT(DISTINCT CASE WHEN platform = 'android' THEN id END) as android_sessions,
  COUNT(DISTINCT CASE WHEN platform = 'ios' THEN id END) as ios_sessions
FROM error_expansion
GROUP BY (error_detail).key
ORDER BY total_occurrences DESC;

-- INTERPRETATION:
-- Top error → Prioritize fix in next release
-- Platform-specific errors → Check native code for iOS/Android
-- >10% sessions affected → Critical issue requiring immediate attention


-- ----------------------------------------------------------------------------
-- 2.4 PLUGIN VERSION ADOPTION (track upgrade rates)
-- ----------------------------------------------------------------------------
-- What it does: Show distribution of plugin versions in production
-- When to run: After releasing new version (check adoption rate)
-- How to use: Ensure old versions are phased out, identify laggards
-- ----------------------------------------------------------------------------
SELECT
  plugin_version,
  COUNT(*) as sessions,
  ROUND(COUNT(*)::float / SUM(COUNT(*)) OVER () * 100, 1) as percentage,
  MIN(created_at)::date as first_seen,
  MAX(created_at)::date as last_seen,
  COUNT(DISTINCT app_identifier) as apps_using_version,
  -- Performance comparison
  ROUND(AVG(detection_time_p95_ms), 1) as avg_p95_latency,
  ROUND(AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) * 100, 1) as detection_success_pct
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY plugin_version
ORDER BY plugin_version DESC;

-- WHAT TO WATCH:
-- Latest version (e.g., 0.4.0) should grow to >80% within 30 days
-- Old versions (e.g., 0.2.x) still active → Reach out to those apps
-- Performance comparison → Ensure new version is better than old


-- ============================================================================
-- SECTION 3: DIAGNOSTICS & ROOT CAUSE ANALYSIS
-- ============================================================================
-- Purpose: Debug specific issues and understand failure patterns
-- Audience: Engineering team
-- Update frequency: On-demand (when investigating user reports)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 3.1 DETECTION FAILURE ROOT CAUSE ANALYSIS
-- ----------------------------------------------------------------------------
-- What it does: Categorize WHY sessions failed to detect zones
-- When to run: When detection success rate is low (<20%)
-- How to use: Identify top failure reason, add to docs or fix in code
-- ----------------------------------------------------------------------------
WITH failure_analysis AS (
  SELECT
    id,
    app_identifier,
    platform,
    plugin_version,
    had_detection,
    gps_ok_ratio,
    session_duration_minutes,
    detections_total,
    (zone_usage->>'circle')::int + (zone_usage->>'polygon')::int as total_zones,
    -- Categorize failure reason (heuristic)
    CASE
      WHEN gps_ok_ratio < 0.5 THEN 'poor_gps_quality'
      WHEN session_duration_minutes < 5 THEN 'session_too_short'
      WHEN detections_total = 0 AND ((zone_usage->>'circle')::int + (zone_usage->>'polygon')::int) = 0 THEN 'no_zones_configured'
      WHEN service_interruptions > 2 THEN 'service_unreliable'
      ELSE 'unknown'
    END as failure_reason
  FROM telemetry_sessions
  WHERE had_detection = false
    AND created_at > NOW() - INTERVAL '30 days'
)
SELECT
  failure_reason,
  COUNT(*) as sessions,
  ROUND(COUNT(*)::float / (SELECT COUNT(*) FROM failure_analysis) * 100, 1) as pct_of_failures,
  -- Characteristics of this failure group
  ROUND(AVG(gps_ok_ratio) * 100, 1) as avg_gps_quality_pct,
  ROUND(AVG(session_duration_minutes), 1) as avg_session_duration_min,
  ROUND(AVG(total_zones), 1) as avg_zones_configured,
  -- Platform distribution
  COUNT(CASE WHEN platform = 'android' THEN 1 END) as android_count,
  COUNT(CASE WHEN platform = 'ios' THEN 1 END) as ios_count
FROM failure_analysis
GROUP BY failure_reason
ORDER BY sessions DESC;

-- ACTIONABLE INSIGHTS:
-- If "session_too_short" is #1 → Add documentation: "Minimum 10min session for reliable detection"
-- If "poor_gps_quality" is #1 → Consider relaxing GPS accuracy threshold or add "indoor mode"
-- If "no_zones_configured" is #1 → Improve example app and docs
-- If "unknown" is >30% → Add more diagnostic fields to telemetry payload


-- ----------------------------------------------------------------------------
-- 3.2 GPS QUALITY vs DETECTION SUCCESS (correlation analysis)
-- ----------------------------------------------------------------------------
-- What it does: Prove/disprove hypothesis that GPS quality affects detection
-- When to run: When investigating detection success issues
-- How to use: Identify GPS quality threshold for reliable detection
-- ----------------------------------------------------------------------------
SELECT
  CASE
    WHEN gps_ok_ratio >= 0.9 THEN 'Excellent (≥90%)'
    WHEN gps_ok_ratio >= 0.7 THEN 'Good (70-89%)'
    WHEN gps_ok_ratio >= 0.5 THEN 'Fair (50-69%)'
    ELSE 'Poor (<50%)'
  END as gps_quality_band,
  COUNT(*) as sessions,
  ROUND(AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) * 100, 1) as detection_success_rate_pct,
  ROUND(AVG(detections_total), 1) as avg_detections_per_session,
  ROUND(AVG(session_duration_minutes), 1) as avg_session_duration_min
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY gps_quality_band
ORDER BY
  CASE gps_quality_band
    WHEN 'Excellent (≥90%)' THEN 1
    WHEN 'Good (70-89%)' THEN 2
    WHEN 'Fair (50-69%)' THEN 3
    WHEN 'Poor (<50%)' THEN 4
  END;

-- EXPECTED PATTERN:
-- Excellent GPS → 80%+ detection success
-- Good GPS → 50-80% detection success
-- Fair GPS → 20-50% detection success
-- Poor GPS → <20% detection success
-- If this pattern doesn't hold → GPS quality is NOT the main factor


-- ----------------------------------------------------------------------------
-- 3.3 SESSION DURATION vs DETECTION SUCCESS
-- ----------------------------------------------------------------------------
-- What it does: Determine minimum viable session duration for detection
-- When to run: When many sessions have zero detections
-- How to use: Document recommended minimum session duration
-- ----------------------------------------------------------------------------
SELECT
  CASE
    WHEN session_duration_minutes < 5 THEN '<5 min'
    WHEN session_duration_minutes < 15 THEN '5-15 min'
    WHEN session_duration_minutes < 60 THEN '15-60 min'
    ELSE '60+ min'
  END as session_duration_bucket,
  COUNT(*) as sessions,
  ROUND(AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) * 100, 1) as detection_success_rate_pct,
  ROUND(AVG(detections_total), 1) as avg_detections,
  ROUND(AVG(gps_ok_ratio) * 100, 1) as avg_gps_quality_pct
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY session_duration_bucket
ORDER BY
  CASE session_duration_bucket
    WHEN '<5 min' THEN 1
    WHEN '5-15 min' THEN 2
    WHEN '15-60 min' THEN 3
    WHEN '60+ min' THEN 4
  END;

-- ACTIONABLE INSIGHT:
-- If <5min sessions have <10% success → Add to docs: "Minimum 10-15 minutes recommended"
-- If all buckets have low success → Duration is NOT the issue


-- ----------------------------------------------------------------------------
-- 3.4 BATTERY OPTIMIZATION vs BACKGROUND RELIABILITY (Android)
-- ----------------------------------------------------------------------------
-- What it does: Prove that disabling battery optimization improves reliability
-- When to run: When Android service interruptions are high
-- How to use: Use data to convince users to disable battery optimization
-- ----------------------------------------------------------------------------
SELECT
  battery_optimization_disabled,
  platform,
  COUNT(*) as sessions,
  ROUND(AVG(service_interruptions), 2) as avg_interruptions_per_session,
  ROUND(AVG(CASE WHEN service_interruptions > 0 THEN 1 ELSE 0 END) * 100, 1) as pct_sessions_with_interruptions,
  ROUND(AVG(session_duration_minutes), 1) as avg_session_duration_min,
  ROUND(AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) * 100, 1) as detection_success_pct
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '30 days'
  AND platform = 'android'  -- Only relevant for Android
GROUP BY battery_optimization_disabled, platform
ORDER BY battery_optimization_disabled DESC;

-- EXPECTED RESULT:
-- battery_opt_disabled=true → <5% sessions with interruptions
-- battery_opt_disabled=false → >20% sessions with interruptions
-- Use this data to update docs: "Disabling battery optimization reduces interruptions by 4x"


-- ----------------------------------------------------------------------------
-- 3.5 PLATFORM-SPECIFIC ISSUE DETECTOR
-- ----------------------------------------------------------------------------
-- What it does: Identify metrics that differ significantly between iOS/Android
-- When to run: After new release or when one platform has issues
-- How to use: Focus debugging efforts on platform with issues
-- ----------------------------------------------------------------------------
WITH platform_stats AS (
  SELECT
    platform,
    COUNT(*) as sessions,
    AVG(detection_time_p95_ms) as avg_p95_latency,
    AVG(gps_ok_ratio) as avg_gps_quality,
    AVG(battery_drain_avg_pct_per_hr) as avg_battery_drain,
    AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) as detection_success_rate,
    AVG(service_interruptions) as avg_interruptions
  FROM telemetry_sessions
  WHERE created_at > NOW() - INTERVAL '30 days'
  GROUP BY platform
)
SELECT
  'Detection Latency P95' as metric,
  ROUND(MAX(CASE WHEN platform = 'android' THEN avg_p95_latency END), 1) as android_value,
  ROUND(MAX(CASE WHEN platform = 'ios' THEN avg_p95_latency END), 1) as ios_value,
  ROUND(ABS(
    MAX(CASE WHEN platform = 'android' THEN avg_p95_latency END) -
    MAX(CASE WHEN platform = 'ios' THEN avg_p95_latency END)
  ), 1) as difference,
  CASE
    WHEN ABS(
      MAX(CASE WHEN platform = 'android' THEN avg_p95_latency END) -
      MAX(CASE WHEN platform = 'ios' THEN avg_p95_latency END)
    ) > 50 THEN '⚠️  Significant'
    ELSE '✅ OK'
  END as status
FROM platform_stats

UNION ALL

SELECT
  'GPS Quality (%)',
  ROUND(MAX(CASE WHEN platform = 'android' THEN avg_gps_quality END) * 100, 1),
  ROUND(MAX(CASE WHEN platform = 'ios' THEN avg_gps_quality END) * 100, 1),
  ROUND(ABS(
    MAX(CASE WHEN platform = 'android' THEN avg_gps_quality END) -
    MAX(CASE WHEN platform = 'ios' THEN avg_gps_quality END)
  ) * 100, 1),
  CASE
    WHEN ABS(
      MAX(CASE WHEN platform = 'android' THEN avg_gps_quality END) -
      MAX(CASE WHEN platform = 'ios' THEN avg_gps_quality END)
    ) > 0.1 THEN '⚠️  Significant'
    ELSE '✅ OK'
  END
FROM platform_stats

UNION ALL

SELECT
  'Battery Drain (%/hr)',
  ROUND(MAX(CASE WHEN platform = 'android' THEN avg_battery_drain END), 2),
  ROUND(MAX(CASE WHEN platform = 'ios' THEN avg_battery_drain END), 2),
  ROUND(ABS(
    MAX(CASE WHEN platform = 'android' THEN avg_battery_drain END) -
    MAX(CASE WHEN platform = 'ios' THEN avg_battery_drain END)
  ), 2),
  CASE
    WHEN ABS(
      MAX(CASE WHEN platform = 'android' THEN avg_battery_drain END) -
      MAX(CASE WHEN platform = 'ios' THEN avg_battery_drain END)
    ) > 0.5 THEN '⚠️  Significant'
    ELSE '✅ OK'
  END
FROM platform_stats

UNION ALL

SELECT
  'Detection Success (%)',
  ROUND(MAX(CASE WHEN platform = 'android' THEN detection_success_rate END) * 100, 1),
  ROUND(MAX(CASE WHEN platform = 'ios' THEN detection_success_rate END) * 100, 1),
  ROUND(ABS(
    MAX(CASE WHEN platform = 'android' THEN detection_success_rate END) -
    MAX(CASE WHEN platform = 'ios' THEN detection_success_rate END)
  ) * 100, 1),
  CASE
    WHEN ABS(
      MAX(CASE WHEN platform = 'android' THEN detection_success_rate END) -
      MAX(CASE WHEN platform = 'ios' THEN detection_success_rate END)
    ) > 0.1 THEN '⚠️  Significant'
    ELSE '✅ OK'
  END
FROM platform_stats;

-- RED FLAGS:
-- ⚠️  Significant difference → One platform has regression
-- Android worse → Check Android-specific code (wake lock, battery opt, foreground service)
-- iOS worse → Check iOS-specific code (background tasks, location updates)


-- ============================================================================
-- SECTION 4: INDUSTRY & USE CASE ANALYSIS
-- ============================================================================
-- Purpose: Understand how different verticals use PolyFence
-- Audience: Product team, business development
-- Update frequency: Monthly or quarterly
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 4.1 INDUSTRY BREAKDOWN (if industry_category is populated)
-- ----------------------------------------------------------------------------
-- What it does: Show plugin usage by industry vertical
-- When to run: Quarterly, for product roadmap prioritization
-- How to use: Identify which industries have best/worst experience
-- ----------------------------------------------------------------------------
SELECT
  COALESCE(industry_category, 'Not Specified') as industry,
  COUNT(*) as sessions,
  COUNT(DISTINCT app_identifier) as apps,
  ROUND(AVG(detection_time_p95_ms), 1) as avg_p95_latency_ms,
  ROUND(AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) * 100, 1) as detection_success_pct,
  ROUND(AVG(battery_drain_avg_pct_per_hr), 2) as avg_battery_drain,
  ROUND(AVG(session_duration_minutes), 1) as avg_session_duration_min,
  -- Zone usage patterns
  ROUND(AVG((zone_usage->>'circle')::int), 1) as avg_circle_zones,
  ROUND(AVG((zone_usage->>'polygon')::int), 1) as avg_polygon_zones
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '90 days'
GROUP BY industry_category
ORDER BY sessions DESC;

-- INSIGHTS TO LOOK FOR:
-- Logistics → High battery drain (expected, high-frequency tracking)
-- Healthcare → May require higher GPS accuracy
-- Retail → May use more polygon zones (store boundaries)
-- Use insights to create industry-specific documentation or config profiles


-- ----------------------------------------------------------------------------
-- 4.2 USE CASE ANALYSIS (if use_case is populated)
-- ----------------------------------------------------------------------------
-- What it does: Show plugin usage by use case
-- When to run: Quarterly, for feature prioritization
-- How to use: Identify use cases that struggle with current plugin config
-- ----------------------------------------------------------------------------
SELECT
  COALESCE(use_case, 'Not Specified') as use_case,
  COUNT(*) as sessions,
  COUNT(DISTINCT app_identifier) as apps,
  ROUND(AVG(session_duration_minutes), 1) as avg_session_duration_min,
  ROUND(AVG(detections_total), 1) as avg_detections_per_session,
  ROUND(AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) * 100, 1) as detection_success_pct,
  -- Zone complexity
  ROUND(AVG((zone_usage->>'circle')::int + (zone_usage->>'polygon')::int), 1) as avg_total_zones
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '90 days'
GROUP BY use_case
ORDER BY sessions DESC;

-- EXAMPLE INSIGHTS:
-- "Delivery" use case → High detections/session (many stops)
-- "Asset tracking" → Long sessions, low detections (monitoring, not route-based)
-- "Geofencing" → Medium sessions, variable detections


-- ============================================================================
-- SECTION 5: VERSION COMPARISON & REGRESSION DETECTION
-- ============================================================================
-- Purpose: Track plugin improvements/regressions across versions
-- Audience: Engineering team
-- Update frequency: After each release
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 5.1 VERSION PERFORMANCE COMPARISON
-- ----------------------------------------------------------------------------
-- What it does: Compare key metrics across plugin versions
-- When to run: After releasing new version (wait 7 days for data)
-- How to use: Ensure new version is better than previous
-- ----------------------------------------------------------------------------
SELECT
  plugin_version,
  COUNT(*) as sessions,
  ROUND(AVG(detection_time_p95_ms), 1) as p95_latency_ms,
  ROUND(AVG(battery_drain_avg_pct_per_hr), 2) as battery_drain,
  ROUND(AVG(gps_ok_ratio) * 100, 1) as gps_quality_pct,
  ROUND(AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) * 100, 1) as detection_success_pct,
  SUM(service_interruptions) as total_interruptions,
  -- Error rates
  SUM((error_counts->>'gps_timeout')::int) as gps_timeouts,
  SUM((error_counts->>'gps_error')::int) as gps_errors
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY plugin_version
ORDER BY plugin_version DESC;

-- GREEN FLAGS (new version should be better):
-- ✅ Lower p95_latency_ms
-- ✅ Lower battery_drain
-- ✅ Higher gps_quality_pct
-- ✅ Higher detection_success_pct
-- ✅ Fewer interruptions and errors

-- RED FLAGS (regression detected):
-- ❌ New version has HIGHER latency → Performance regression
-- ❌ New version has HIGHER battery drain → Efficiency regression
-- ❌ New version has MORE errors → Stability regression


-- ----------------------------------------------------------------------------
-- 5.2 WEEK-OVER-WEEK TREND (detect sudden changes)
-- ----------------------------------------------------------------------------
-- What it does: Compare this week vs last week to catch sudden degradation
-- When to run: Weekly health check
-- How to use: Identify sudden changes that need investigation
-- ----------------------------------------------------------------------------
WITH this_week AS (
  SELECT
    COUNT(*) as sessions,
    AVG(detection_time_p95_ms) as p95_latency,
    AVG(battery_drain_avg_pct_per_hr) as battery_drain,
    AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) as detection_success
  FROM telemetry_sessions
  WHERE created_at > NOW() - INTERVAL '7 days'
),
last_week AS (
  SELECT
    COUNT(*) as sessions,
    AVG(detection_time_p95_ms) as p95_latency,
    AVG(battery_drain_avg_pct_per_hr) as battery_drain,
    AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) as detection_success
  FROM telemetry_sessions
  WHERE created_at BETWEEN NOW() - INTERVAL '14 days' AND NOW() - INTERVAL '7 days'
)
SELECT
  'Sessions' as metric,
  tw.sessions as this_week,
  lw.sessions as last_week,
  tw.sessions - lw.sessions as change,
  ROUND((tw.sessions::float / NULLIF(lw.sessions, 0) - 1) * 100, 1) as pct_change
FROM this_week tw, last_week lw

UNION ALL

SELECT
  'P95 Latency (ms)',
  ROUND(tw.p95_latency, 1),
  ROUND(lw.p95_latency, 1),
  ROUND(tw.p95_latency - lw.p95_latency, 1),
  ROUND((tw.p95_latency / NULLIF(lw.p95_latency, 0) - 1) * 100, 1)
FROM this_week tw, last_week lw

UNION ALL

SELECT
  'Battery Drain (%/hr)',
  ROUND(tw.battery_drain, 2),
  ROUND(lw.battery_drain, 2),
  ROUND(tw.battery_drain - lw.battery_drain, 2),
  ROUND((tw.battery_drain / NULLIF(lw.battery_drain, 0) - 1) * 100, 1)
FROM this_week tw, last_week lw

UNION ALL

SELECT
  'Detection Success (%)',
  ROUND(tw.detection_success * 100, 1),
  ROUND(lw.detection_success * 100, 1),
  ROUND((tw.detection_success - lw.detection_success) * 100, 1),
  ROUND((tw.detection_success / NULLIF(lw.detection_success, 0) - 1) * 100, 1)
FROM this_week tw, last_week lw;

-- WATCH FOR:
-- ⚠️  >20% degradation in any metric week-over-week → Investigate immediately
-- 📈 Growing sessions → Good, plugin adoption increasing
-- 📉 Declining sessions → May indicate user churn or seasonal patterns


-- ============================================================================
-- SECTION 6: UTILITY QUERIES
-- ============================================================================
-- Purpose: Data quality checks, exports, ad-hoc analysis
-- Audience: Engineering team
-- Update frequency: As needed
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 6.1 DATA QUALITY CHECK
-- ----------------------------------------------------------------------------
-- What it does: Identify incomplete or suspicious telemetry records
-- When to run: When data looks unusual or after telemetry changes
-- How to use: Clean up data issues or fix plugin telemetry code
-- ----------------------------------------------------------------------------
SELECT
  'Total Sessions' as check_name,
  COUNT(*) as count,
  '✅ OK' as status
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '7 days'

UNION ALL

SELECT
  'Missing Platform',
  COUNT(*),
  CASE WHEN COUNT(*) = 0 THEN '✅ OK' ELSE '⚠️  Issue' END
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '7 days'
  AND (platform IS NULL OR platform NOT IN ('android', 'ios'))

UNION ALL

SELECT
  'Missing Plugin Version',
  COUNT(*),
  CASE WHEN COUNT(*) = 0 THEN '✅ OK' ELSE '⚠️  Issue' END
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '7 days'
  AND plugin_version IS NULL

UNION ALL

SELECT
  'Zero Session Duration',
  COUNT(*),
  CASE WHEN COUNT(*) < 10 THEN '✅ OK' ELSE '⚠️  Investigate' END
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '7 days'
  AND session_duration_minutes = 0

UNION ALL

SELECT
  'Suspicious Battery Drain (>10%/hr)',
  COUNT(*),
  CASE WHEN COUNT(*) < 5 THEN '✅ OK' ELSE '⚠️  Outliers' END
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '7 days'
  AND battery_drain_avg_pct_per_hr > 10

UNION ALL

SELECT
  'Suspicious Latency (>5000ms)',
  COUNT(*),
  CASE WHEN COUNT(*) < 5 THEN '✅ OK' ELSE '⚠️  Outliers' END
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '7 days'
  AND detection_time_p95_ms > 5000;

-- ACTION ON ISSUES:
-- ⚠️  Missing platform/version → Plugin not setting values correctly
-- ⚠️  Zero duration → Sessions ending prematurely, investigate
-- ⚠️  Outliers → May indicate bugs or extreme use cases


-- ----------------------------------------------------------------------------
-- 6.2 INDIVIDUAL SESSION INSPECTOR (for debugging specific issues)
-- ----------------------------------------------------------------------------
-- What it does: Retrieve full details for a specific session or app
-- When to run: When user reports an issue and provides app identifier
-- How to use: Replace 'com.example.app' with actual app identifier
-- ----------------------------------------------------------------------------
SELECT
  id,
  created_at,
  app_identifier,
  platform,
  plugin_version,
  session_duration_minutes,
  detections_total,
  had_detection,
  detection_time_avg_ms,
  detection_time_p95_ms,
  gps_accuracy_avg_m,
  gps_ok_ratio,
  battery_drain_avg_pct_per_hr,
  service_interruptions,
  zone_usage,
  error_counts,
  battery_optimization_disabled
FROM telemetry_sessions
WHERE app_identifier = 'com.example.app'  -- REPLACE WITH ACTUAL APP
  AND created_at > NOW() - INTERVAL '30 days'
ORDER BY created_at DESC
LIMIT 20;

-- USE CASE:
-- User reports: "PolyFence not detecting zones in my app"
-- 1. Get their app identifier
-- 2. Run this query
-- 3. Check: had_detection, gps_ok_ratio, zone_usage
-- 4. Identify issue: GPS quality, no zones configured, etc.


-- ----------------------------------------------------------------------------
-- 6.3 EXPORT FOR README.md (formatted for markdown tables)
-- ----------------------------------------------------------------------------
-- What it does: Generate markdown-ready performance table
-- When to run: Monthly, for README updates
-- How to use: Copy output directly into README.md
-- ----------------------------------------------------------------------------
SELECT
  '| ' || metric || ' | ' ||
  android_value || ' | ' ||
  ios_value || ' | ' ||
  target || ' |' as markdown_row
FROM (
  SELECT
    'Detection Speed (P95)' as metric,
    ROUND(AVG(CASE WHEN platform = 'android' THEN detection_time_p95_ms END), 0)::text || 'ms' as android_value,
    ROUND(AVG(CASE WHEN platform = 'ios' THEN detection_time_p95_ms END), 0)::text || 'ms' as ios_value,
    '<500ms ✅' as target,
    1 as sort_order
  FROM telemetry_sessions
  WHERE created_at > NOW() - INTERVAL '30 days'

  UNION ALL

  SELECT
    'GPS Accuracy',
    ROUND(AVG(CASE WHEN platform = 'android' THEN gps_accuracy_avg_m END), 1)::text || 'm',
    ROUND(AVG(CASE WHEN platform = 'ios' THEN gps_accuracy_avg_m END), 1)::text || 'm',
    '<50m ✅',
    2
  FROM telemetry_sessions
  WHERE created_at > NOW() - INTERVAL '30 days'

  UNION ALL

  SELECT
    'Battery Impact',
    ROUND(AVG(CASE WHEN platform = 'android' THEN battery_drain_avg_pct_per_hr END), 1)::text || '%/hr',
    ROUND(AVG(CASE WHEN platform = 'ios' THEN battery_drain_avg_pct_per_hr END), 1)::text || '%/hr',
    '<2%/hr ✅',
    3
  FROM telemetry_sessions
  WHERE created_at > NOW() - INTERVAL '30 days'

  UNION ALL

  SELECT
    'Detection Success',
    ROUND(AVG(CASE WHEN platform = 'android' AND had_detection THEN 100 ELSE 0 END), 1)::text || '%',
    ROUND(AVG(CASE WHEN platform = 'ios' AND had_detection THEN 100 ELSE 0 END), 1)::text || '%',
    '>80%',
    4
  FROM telemetry_sessions
  WHERE created_at > NOW() - INTERVAL '30 days'
) as metrics
ORDER BY sort_order;

-- OUTPUT:
-- Copy the results and paste into README.md between:
-- | Metric | Android | iOS | Target |
-- |--------|---------|-----|--------|


-- ----------------------------------------------------------------------------
-- 6.4 APPS MOST IN NEED OF SUPPORT (identify struggling apps)
-- ----------------------------------------------------------------------------
-- What it does: Find apps with consistently poor performance
-- When to run: Monthly, for proactive customer support
-- How to use: Reach out to these apps, offer debugging help
-- ----------------------------------------------------------------------------
SELECT
  app_identifier,
  COUNT(*) as sessions,
  ROUND(AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) * 100, 1) as detection_success_pct,
  ROUND(AVG(gps_ok_ratio) * 100, 1) as avg_gps_quality,
  ROUND(AVG(detection_time_p95_ms), 1) as avg_p95_latency,
  SUM(service_interruptions) as total_interruptions,
  MAX(created_at)::date as last_seen,
  -- Identify primary issue
  CASE
    WHEN AVG(gps_ok_ratio) < 0.5 THEN 'GPS Quality Issues'
    WHEN AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) < 0.1 THEN 'No Detections'
    WHEN SUM(service_interruptions) > 10 THEN 'Service Reliability'
    WHEN AVG(detection_time_p95_ms) > 500 THEN 'Performance Issues'
    ELSE 'Unknown'
  END as primary_issue
FROM telemetry_sessions
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY app_identifier
HAVING COUNT(*) >= 10  -- Only apps with meaningful data
  AND AVG(CASE WHEN had_detection THEN 1 ELSE 0 END) < 0.2  -- Low success rate
ORDER BY sessions DESC
LIMIT 10;

-- PROACTIVE SUPPORT:
-- Reach out to these apps: "We noticed you might be experiencing issues..."
-- Offer: Configuration review, debugging help, feature requests
-- Build customer loyalty and get valuable feedback


-- ============================================================================
-- END OF ANALYTICS QUERY LIBRARY
-- ============================================================================
--
-- QUICK START GUIDE:
-- 1. Start with "2.1 Weekly Health Check" every Monday
-- 2. Run "1.1 Overall Performance Scorecard" monthly for README
-- 3. Use Section 3 (Diagnostics) when investigating specific issues
-- 4. Bookmark this file in Supabase or save to your repo
--
-- ADDING CUSTOM QUERIES:
-- - Copy existing query structure
-- - Update WHERE clauses for different time ranges
-- - Add business logic specific to your use case
-- - Document with clear comments
--
-- QUESTIONS OR ISSUES:
-- - Check telemetry schema: docs/TELEMETRY.md
-- - Verify table name matches your setup (default: telemetry_sessions)
-- - Ensure JSONB fields (zone_usage, error_counts) are properly formatted
--
-- Happy analyzing! 🚀
-- ============================================================================
