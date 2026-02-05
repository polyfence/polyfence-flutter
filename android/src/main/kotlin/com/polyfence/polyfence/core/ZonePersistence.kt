package com.polyfence.polyfence.core

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Handles zone data persistence across app restarts
 * Single responsibility: Zone storage and retrieval
 */
class ZonePersistence(private val context: Context) {
    
    companion object {
        private const val TAG = "ZonePersistence"
        private const val PREFS_NAME = "polyfence_zones"
        private const val ZONES_KEY = "saved_zones"
        private const val ZONE_STATES_KEY = "zone_states"
        private const val LAST_STATE_UPDATE_KEY = "last_state_update"
    }
    
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    // Synchronization lock to prevent race conditions in read-modify-write operations
    private val lock = Any()
    
    /**
     * Save zone data to persistent storage
     * Thread-safe: Uses synchronization to prevent data loss from concurrent writes
     */
    fun saveZone(zoneId: String, zoneName: String, zoneData: Map<String, Any>) {
        synchronized(lock) {
            try {
                val savedZones = getSavedZones().toMutableMap()
                
                val zoneJson = JSONObject().apply {
                    put("id", zoneId)
                    put("name", zoneName)
                    put("data", JSONObject(zoneData))
                    put("timestamp", System.currentTimeMillis())
                }
                
                savedZones[zoneId] = zoneJson
                persistZones(savedZones)
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save zone $zoneId: ${e.message}")
            }
        }
    }
    
    /**
     * Remove zone from persistent storage
     * Thread-safe: Uses synchronization to prevent data loss from concurrent writes
     */
    fun removeZone(zoneId: String) {
        synchronized(lock) {
            try {
                val savedZones = getSavedZones().toMutableMap()
                savedZones.remove(zoneId)
                persistZones(savedZones)
                
            } catch (e: Exception) {
                Log.e(TAG, "Failed to remove zone $zoneId: ${e.message}")
            }
        }
    }
    
    /**
     * Clear all zones from persistent storage
     * Thread-safe: Uses synchronization to prevent race conditions
     */
    fun clearAllZones() {
        synchronized(lock) {
            try {
                prefs.edit().remove(ZONES_KEY).apply()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to clear zones: ${e.message}")
            }
        }
    }
    
    /**
     * Load all saved zones
     * Thread-safe: Uses synchronization for consistent reads
     */
    fun loadAllZones(): Map<String, Triple<String, String, Map<String, Any>>> {
        synchronized(lock) {
            return try {
                val savedZones = getSavedZones()
                val result = mutableMapOf<String, Triple<String, String, Map<String, Any>>>()
                
                savedZones.forEach { (zoneId, zoneJson) ->
                    val zoneName = zoneJson.getString("name")
                    val zoneDataJson = zoneJson.getJSONObject("data")
                    val zoneData = jsonToMap(zoneDataJson)
                    
                    result[zoneId] = Triple(zoneId, zoneName, zoneData)
                }
                
                result
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load zones: ${e.message}")
                emptyMap()
            }
        }
    }
    
    /**
     * Get count of saved zones
     * Thread-safe: Uses synchronization for consistent reads
     */
    fun getZoneCount(): Int {
        synchronized(lock) {
            return try {
                getSavedZones().size
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get zone count: ${e.message}")
                0
            }
        }
    }
    
    /**
     * Check if zone exists in storage
     * Thread-safe: Uses synchronization for consistent reads
     */
    fun hasZone(zoneId: String): Boolean {
        synchronized(lock) {
            return try {
                getSavedZones().containsKey(zoneId)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to check zone existence: ${e.message}")
                false
            }
        }
    }
    
    // Private helper methods
    
    private fun getSavedZones(): Map<String, JSONObject> {
        val zonesJson = prefs.getString(ZONES_KEY, "{}") ?: "{}"
        val result = mutableMapOf<String, JSONObject>()
        
        try {
            val rootJson = JSONObject(zonesJson)
            rootJson.keys().forEach { zoneId ->
                result[zoneId] = rootJson.getJSONObject(zoneId)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse saved zones: ${e.message}")
        }
        
        return result
    }
    
    private fun persistZones(zones: Map<String, JSONObject>) {
        try {
            val rootJson = JSONObject()
            zones.forEach { (zoneId, zoneJson) ->
                rootJson.put(zoneId, zoneJson)
            }
            
            prefs.edit().putString(ZONES_KEY, rootJson.toString()).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to persist zones", e)
        }
    }
    
    private fun jsonToMap(jsonObject: JSONObject): Map<String, Any> {
        val result = mutableMapOf<String, Any>()
        
        jsonObject.keys().forEach { key ->
            val value = jsonObject.get(key)
            when (value) {
                is JSONObject -> result[key] = jsonToMap(value)
                is JSONArray -> result[key] = jsonArrayToList(value)
                else -> result[key] = value
            }
        }
        
        return result
    }
    
    private fun jsonArrayToList(jsonArray: JSONArray): List<Any> {
        val result = mutableListOf<Any>()

        for (i in 0 until jsonArray.length()) {
            val value = jsonArray.get(i)
            when (value) {
                is JSONObject -> result.add(jsonToMap(value))
                is JSONArray -> result.add(jsonArrayToList(value))
                else -> result.add(value)
            }
        }

        return result
    }

    // ============================================================================
    // ZONE STATE PERSISTENCE (Fix for exit detection after service restart)
    // ============================================================================

    /**
     * Save zone states to persistent storage (write-through)
     * Called immediately when zone state changes to prevent data loss
     * Thread-safe: Uses synchronization to prevent race conditions
     */
    fun saveZoneStates(states: Map<String, Boolean>) {
        synchronized(lock) {
            try {
                val statesJson = JSONObject()
                states.forEach { (zoneId, isInside) ->
                    statesJson.put(zoneId, isInside)
                }

                prefs.edit()
                    .putString(ZONE_STATES_KEY, statesJson.toString())
                    .putLong(LAST_STATE_UPDATE_KEY, System.currentTimeMillis())
                    .commit() // Use commit() for immediate write-through (not apply())

                Log.d(TAG, "Saved zone states: ${states.size} zones, inside=${states.count { it.value }}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save zone states: ${e.message}")
            }
        }
    }

    /**
     * Save single zone state (write-through)
     * More efficient for single state changes
     */
    fun saveZoneState(zoneId: String, isInside: Boolean) {
        synchronized(lock) {
            try {
                val existingStates = loadZoneStates().toMutableMap()
                existingStates[zoneId] = isInside

                val statesJson = JSONObject()
                existingStates.forEach { (id, state) ->
                    statesJson.put(id, state)
                }

                prefs.edit()
                    .putString(ZONE_STATES_KEY, statesJson.toString())
                    .putLong(LAST_STATE_UPDATE_KEY, System.currentTimeMillis())
                    .commit() // Use commit() for immediate write-through

                Log.d(TAG, "Saved zone state: $zoneId = ${if (isInside) "INSIDE" else "OUTSIDE"}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save zone state for $zoneId: ${e.message}")
            }
        }
    }

    /**
     * Load zone states from persistent storage
     * Returns empty map if no states saved (fresh install / data wipe)
     * Thread-safe: Uses synchronization for consistent reads
     */
    fun loadZoneStates(): Map<String, Boolean> {
        synchronized(lock) {
            return try {
                val statesJson = prefs.getString(ZONE_STATES_KEY, "{}") ?: "{}"
                val result = mutableMapOf<String, Boolean>()

                val jsonObject = JSONObject(statesJson)
                jsonObject.keys().forEach { zoneId ->
                    result[zoneId] = jsonObject.getBoolean(zoneId)
                }

                Log.d(TAG, "Loaded zone states: ${result.size} zones, inside=${result.count { it.value }}")
                result
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load zone states: ${e.message}")
                emptyMap()
            }
        }
    }

    /**
     * Remove zone state from persistent storage
     */
    fun removeZoneState(zoneId: String) {
        synchronized(lock) {
            try {
                val existingStates = loadZoneStates().toMutableMap()
                existingStates.remove(zoneId)
                saveZoneStates(existingStates)
                Log.d(TAG, "Removed zone state for: $zoneId")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to remove zone state for $zoneId: ${e.message}")
            }
        }
    }

    /**
     * Clear all zone states from persistent storage
     */
    fun clearAllZoneStates() {
        synchronized(lock) {
            try {
                prefs.edit()
                    .remove(ZONE_STATES_KEY)
                    .remove(LAST_STATE_UPDATE_KEY)
                    .commit()
                Log.d(TAG, "Cleared all zone states")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to clear zone states: ${e.message}")
            }
        }
    }

    /**
     * Check if zone states exist in storage
     * Returns false for fresh install / data wipe
     */
    fun hasPersistedZoneStates(): Boolean {
        synchronized(lock) {
            return prefs.contains(ZONE_STATES_KEY)
        }
    }

    /**
     * Get timestamp of last zone state update
     * Returns 0 if never updated
     */
    fun getLastStateUpdateTime(): Long {
        synchronized(lock) {
            return prefs.getLong(LAST_STATE_UPDATE_KEY, 0L)
        }
    }
}