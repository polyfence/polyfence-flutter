import Foundation

/**
 * Zone persistence using UserDefaults (iOS equivalent to Android SharedPreferences)
 * Single responsibility: Save/load zones across app restarts
 */
class ZonePersistence {
    
    // MARK: - Constants
    internal static let TAG = "ZonePersistence"
    internal static let ZONES_KEY = "polyfence_zones"
    internal static let ZONE_NAMES_KEY = "polyfence_zone_names"
    internal static let ZONE_STATES_KEY = "polyfence_zone_states"
    internal static let LAST_STATE_UPDATE_KEY = "polyfence_last_state_update"
    
    // MARK: - Properties
    private let userDefaults = UserDefaults.standard
    
    // Synchronization queue for thread-safe read-modify-write operations
    // Concurrent queue allows parallel reads, barrier flag serializes writes
    private let persistenceQueue = DispatchQueue(
        label: "com.polyfence.zonePersistence",
        attributes: .concurrent
    )
    
    // MARK: - Public Methods
    
    /**
     * Save zone to persistent storage
     * Thread-safe: Uses barrier queue to prevent race conditions in concurrent writes
     */
    func saveZone(zoneId: String, zoneName: String, zoneData: [String: Any]) {
        persistenceQueue.async(flags: .barrier) {
            do {
                // Save zone data
                let zoneDataKey = "\(ZonePersistence.ZONES_KEY)_\(zoneId)"
                let zoneDataData = try JSONSerialization.data(withJSONObject: zoneData)
                self.userDefaults.set(zoneDataData, forKey: zoneDataKey)
                
                // Save zone name
                let zoneNameKey = "\(ZonePersistence.ZONE_NAMES_KEY)_\(zoneId)"
                self.userDefaults.set(zoneName, forKey: zoneNameKey)
                
                // Add to zone list (read-modify-write protected by barrier)
                var zoneIds = self.userDefaults.stringArray(forKey: ZonePersistence.ZONES_KEY) ?? []
                if !zoneIds.contains(zoneId) {
                    zoneIds.append(zoneId)
                    self.userDefaults.set(zoneIds, forKey: ZonePersistence.ZONES_KEY)
                }
                
                // Zone saved successfully
            } catch {
                // Failed to save zone
            }
        }
    }
    
    /**
     * Remove zone from persistent storage
     * Thread-safe: Uses barrier queue to prevent race conditions in concurrent writes
     */
    func removeZone(zoneId: String) {
        persistenceQueue.async(flags: .barrier) {
            // Remove zone data
            let zoneDataKey = "\(ZonePersistence.ZONES_KEY)_\(zoneId)"
            self.userDefaults.removeObject(forKey: zoneDataKey)
            
            // Remove zone name
            let zoneNameKey = "\(ZonePersistence.ZONE_NAMES_KEY)_\(zoneId)"
            self.userDefaults.removeObject(forKey: zoneNameKey)
            
            // Remove from zone list (read-modify-write protected by barrier)
            var zoneIds = self.userDefaults.stringArray(forKey: ZonePersistence.ZONES_KEY) ?? []
            zoneIds.removeAll { $0 == zoneId }
            self.userDefaults.set(zoneIds, forKey: ZonePersistence.ZONES_KEY)
            
            // Zone removed successfully
        }
    }
    
    /**
     * Clear all zones from persistent storage
     * Thread-safe: Uses barrier queue to prevent race conditions
     */
    func clearAllZones() {
        persistenceQueue.async(flags: .barrier) {
            let zoneIds = self.userDefaults.stringArray(forKey: ZonePersistence.ZONES_KEY) ?? []
            
            for zoneId in zoneIds {
                let zoneDataKey = "\(ZonePersistence.ZONES_KEY)_\(zoneId)"
                let zoneNameKey = "\(ZonePersistence.ZONE_NAMES_KEY)_\(zoneId)"
                
                self.userDefaults.removeObject(forKey: zoneDataKey)
                self.userDefaults.removeObject(forKey: zoneNameKey)
            }
            
            self.userDefaults.removeObject(forKey: ZonePersistence.ZONES_KEY)
            
            // All zones cleared successfully
        }
    }
    
    /**
     * Load all zones from persistent storage
     * Thread-safe: Uses sync to ensure consistent reads
     */
    func loadAllZones() throws -> [String: (String, String, [String: Any])] {
        return try persistenceQueue.sync {
            let zoneIds = self.userDefaults.stringArray(forKey: ZonePersistence.ZONES_KEY) ?? []
            var zones: [String: (String, String, [String: Any])] = [:]
            
            for zoneId in zoneIds {
                do {
                    let zoneDataKey = "\(ZonePersistence.ZONES_KEY)_\(zoneId)"
                    let zoneNameKey = "\(ZonePersistence.ZONE_NAMES_KEY)_\(zoneId)"
                    
                    guard let zoneDataData = self.userDefaults.data(forKey: zoneDataKey),
                          let zoneName = self.userDefaults.string(forKey: zoneNameKey) else {
                        // Missing data for zone
                        continue
                    }
                    
                    let zoneData = try JSONSerialization.jsonObject(with: zoneDataData) as? [String: Any] ?? [:]
                    
                    zones[zoneId] = (zoneId, zoneName, zoneData)
                    
                } catch {
                    // Failed to load zone
                }
            }
            
            // Zones loaded from storage
            return zones
        }
    }
    
    /**
     * Check if zone exists in storage
     * Thread-safe: Uses sync to ensure consistent reads
     */
    func zoneExists(zoneId: String) -> Bool {
        return persistenceQueue.sync {
            let zoneIds = self.userDefaults.stringArray(forKey: ZonePersistence.ZONES_KEY) ?? []
            return zoneIds.contains(zoneId)
        }
    }
    
    /**
     * Get zone count
     * Thread-safe: Uses sync to ensure consistent reads
     */
    func getZoneCount() -> Int {
        return persistenceQueue.sync {
            let zoneIds = self.userDefaults.stringArray(forKey: ZonePersistence.ZONES_KEY) ?? []
            return zoneIds.count
        }
    }

    // ============================================================================
    // ZONE STATE PERSISTENCE (Fix for exit detection after service restart)
    // ============================================================================

    /**
     * Save zone states to persistent storage (write-through)
     * Called immediately when zone state changes to prevent data loss
     * Thread-safe: Uses barrier queue to prevent race conditions
     */
    func saveZoneStates(_ states: [String: Bool]) {
        persistenceQueue.async(flags: .barrier) {
            self.userDefaults.set(states, forKey: ZonePersistence.ZONE_STATES_KEY)
            self.userDefaults.set(Date().timeIntervalSince1970, forKey: ZonePersistence.LAST_STATE_UPDATE_KEY)
            self.userDefaults.synchronize() // Force immediate write (iOS equivalent of commit())

            let insideCount = states.values.filter { $0 }.count
            NSLog("[\(ZonePersistence.TAG)] Saved zone states: \(states.count) zones, inside=\(insideCount)")
        }
    }

    /**
     * Save single zone state (write-through)
     * More efficient for single state changes
     */
    func saveZoneState(zoneId: String, isInside: Bool) {
        persistenceQueue.async(flags: .barrier) {
            var existingStates = self.userDefaults.dictionary(forKey: ZonePersistence.ZONE_STATES_KEY) as? [String: Bool] ?? [:]
            existingStates[zoneId] = isInside

            self.userDefaults.set(existingStates, forKey: ZonePersistence.ZONE_STATES_KEY)
            self.userDefaults.set(Date().timeIntervalSince1970, forKey: ZonePersistence.LAST_STATE_UPDATE_KEY)
            self.userDefaults.synchronize() // Force immediate write

            NSLog("[\(ZonePersistence.TAG)] Saved zone state: \(zoneId) = \(isInside ? "INSIDE" : "OUTSIDE")")
        }
    }

    /**
     * Load zone states from persistent storage
     * Returns empty dictionary if no states saved (fresh install / data wipe)
     * Thread-safe: Uses sync for consistent reads
     */
    func loadZoneStates() -> [String: Bool] {
        return persistenceQueue.sync {
            let states = self.userDefaults.dictionary(forKey: ZonePersistence.ZONE_STATES_KEY) as? [String: Bool] ?? [:]
            let insideCount = states.values.filter { $0 }.count
            NSLog("[\(ZonePersistence.TAG)] Loaded zone states: \(states.count) zones, inside=\(insideCount)")
            return states
        }
    }

    /**
     * Remove zone state from persistent storage
     */
    func removeZoneState(zoneId: String) {
        persistenceQueue.async(flags: .barrier) {
            var existingStates = self.userDefaults.dictionary(forKey: ZonePersistence.ZONE_STATES_KEY) as? [String: Bool] ?? [:]
            existingStates.removeValue(forKey: zoneId)
            self.userDefaults.set(existingStates, forKey: ZonePersistence.ZONE_STATES_KEY)
            self.userDefaults.synchronize()
            NSLog("[\(ZonePersistence.TAG)] Removed zone state for: \(zoneId)")
        }
    }

    /**
     * Clear all zone states from persistent storage
     */
    func clearAllZoneStates() {
        persistenceQueue.async(flags: .barrier) {
            self.userDefaults.removeObject(forKey: ZonePersistence.ZONE_STATES_KEY)
            self.userDefaults.removeObject(forKey: ZonePersistence.LAST_STATE_UPDATE_KEY)
            self.userDefaults.synchronize()
            NSLog("[\(ZonePersistence.TAG)] Cleared all zone states")
        }
    }

    /**
     * Check if zone states exist in storage
     * Returns false for fresh install / data wipe
     */
    func hasPersistedZoneStates() -> Bool {
        return persistenceQueue.sync {
            return self.userDefaults.object(forKey: ZonePersistence.ZONE_STATES_KEY) != nil
        }
    }

    /**
     * Get timestamp of last zone state update
     * Returns 0 if never updated
     */
    func getLastStateUpdateTime() -> TimeInterval {
        return persistenceQueue.sync {
            return self.userDefaults.double(forKey: ZonePersistence.LAST_STATE_UPDATE_KEY)
        }
    }
} 