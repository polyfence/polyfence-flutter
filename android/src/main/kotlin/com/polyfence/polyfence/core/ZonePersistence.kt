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
    }
    
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    /**
     * Save zone data to persistent storage
     */
    fun saveZone(zoneId: String, zoneName: String, zoneData: Map<String, Any>) {
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
    
    /**
     * Remove zone from persistent storage
     */
    fun removeZone(zoneId: String) {
        try {
            val savedZones = getSavedZones().toMutableMap()
            savedZones.remove(zoneId)
            persistZones(savedZones)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to remove zone $zoneId: ${e.message}")
        }
    }
    
    /**
     * Clear all zones from persistent storage
     */
    fun clearAllZones() {
        try {
            prefs.edit().remove(ZONES_KEY).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clear zones: ${e.message}")
        }
    }
    
    /**
     * Load all saved zones
     */
    fun loadAllZones(): Map<String, Triple<String, String, Map<String, Any>>> {
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
    
    /**
     * Get count of saved zones
     */
    fun getZoneCount(): Int {
        return try {
            getSavedZones().size
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get zone count: ${e.message}")
            0
        }
    }
    
    /**
     * Check if zone exists in storage
     */
    fun hasZone(zoneId: String): Boolean {
        return try {
            getSavedZones().containsKey(zoneId)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check zone existence: ${e.message}")
            false
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
}