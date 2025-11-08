package com.polyfence.polyfence.utils

/**
 * LRU Cache implementation for zone result caching
 * Single responsibility: Bounded cache with automatic eviction
 */
class LRUCache<K, V>(private val maxSize: Int) : LinkedHashMap<K, V>(16, 0.75f, true) {
    
    override fun removeEldestEntry(eldest: Map.Entry<K, V>?): Boolean {
        return size > maxSize
    }
    
    fun evictAll() {
        clear()
    }
}