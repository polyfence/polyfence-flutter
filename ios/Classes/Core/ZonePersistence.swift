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
    
    // MARK: - Public Methods
    
    /**
     * Save zone to persistent storage
     */
    func saveZone(zoneId: String, zoneName: String, zoneData: [String: Any]) {
        do {
            // Save zone data
            let zoneDataKey = "\(ZonePersistence.ZONES_KEY)_\(zoneId)"
            let zoneDataData = try JSONSerialization.data(withJSONObject: zoneData)
            userDefaults.set(zoneDataData, forKey: zoneDataKey)
            
            // Save zone name
            let zoneNameKey = "\(ZonePersistence.ZONE_NAMES_KEY)_\(zoneId)"
            userDefaults.set(zoneName, forKey: zoneNameKey)
            
            // Add to zone list
            var zoneIds = userDefaults.stringArray(forKey: ZonePersistence.ZONES_KEY) ?? []
            if !zoneIds.contains(zoneId) {
                zoneIds.append(zoneId)
                userDefaults.set(zoneIds, forKey: ZonePersistence.ZONES_KEY)
            }
            
            // Zone saved successfully
        } catch {
            // Failed to save zone
        }
    }
    
    /**
     * Remove zone from persistent storage
     */
    func removeZone(zoneId: String) {
        // Remove zone data
        let zoneDataKey = "\(ZonePersistence.ZONES_KEY)_\(zoneId)"
        userDefaults.removeObject(forKey: zoneDataKey)
        
        // Remove zone name
        let zoneNameKey = "\(ZonePersistence.ZONE_NAMES_KEY)_\(zoneId)"
        userDefaults.removeObject(forKey: zoneNameKey)
        
        // Remove from zone list
        var zoneIds = userDefaults.stringArray(forKey: ZonePersistence.ZONES_KEY) ?? []
        zoneIds.removeAll { $0 == zoneId }
        userDefaults.set(zoneIds, forKey: ZonePersistence.ZONES_KEY)
        
        // Zone removed successfully
    }
    
    /**
     * Clear all zones from persistent storage
     */
    func clearAllZones() {
        let zoneIds = userDefaults.stringArray(forKey: ZonePersistence.ZONES_KEY) ?? []
        
        for zoneId in zoneIds {
            let zoneDataKey = "\(ZonePersistence.ZONES_KEY)_\(zoneId)"
            let zoneNameKey = "\(ZonePersistence.ZONE_NAMES_KEY)_\(zoneId)"
            
            userDefaults.removeObject(forKey: zoneDataKey)
            userDefaults.removeObject(forKey: zoneNameKey)
        }
        
        userDefaults.removeObject(forKey: ZonePersistence.ZONES_KEY)
        
        // All zones cleared successfully
    }
    
    /**
     * Load all zones from persistent storage
     */
    func loadAllZones() throws -> [String: (String, String, [String: Any])] {
        let zoneIds = userDefaults.stringArray(forKey: ZonePersistence.ZONES_KEY) ?? []
        var zones: [String: (String, String, [String: Any])] = [:]
        
        for zoneId in zoneIds {
            do {
                let zoneDataKey = "\(ZonePersistence.ZONES_KEY)_\(zoneId)"
                let zoneNameKey = "\(ZonePersistence.ZONE_NAMES_KEY)_\(zoneId)"
                
                guard let zoneDataData = userDefaults.data(forKey: zoneDataKey),
                      let zoneName = userDefaults.string(forKey: zoneNameKey) else {
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
    
    /**
     * Check if zone exists in storage
     */
    func zoneExists(zoneId: String) -> Bool {
        let zoneIds = userDefaults.stringArray(forKey: ZonePersistence.ZONES_KEY) ?? []
        return zoneIds.contains(zoneId)
    }
    
    /**
     * Get zone count
     */
    func getZoneCount() -> Int {
        let zoneIds = userDefaults.stringArray(forKey: ZonePersistence.ZONES_KEY) ?? []
        return zoneIds.count
    }
} 