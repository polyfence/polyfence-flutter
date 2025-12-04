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
} 