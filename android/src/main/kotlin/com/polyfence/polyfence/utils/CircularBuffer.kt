package com.polyfence.polyfence.utils

/**
 * Fixed-size circular buffer for memory-efficient location storage
 * Single responsibility: Bounded memory usage for location history
 */
class CircularBuffer<T>(private val capacity: Int) {
    private val buffer = arrayOfNulls<Any>(capacity)
    private var head = 0
    private var size = 0
    
    fun add(item: T) {
        buffer[head] = item
        head = (head + 1) % capacity
        if (size < capacity) {
            size++
        }
    }
    
    fun getLast(count: Int): List<T> {
        val result = mutableListOf<T>()
        val actualCount = minOf(count, size)
        
        for (i in 0 until actualCount) {
            val index = (head - 1 - i + capacity) % capacity
            @Suppress("UNCHECKED_CAST")
            result.add(buffer[index] as T)
        }
        
        return result
    }
    
    fun size(): Int = size
    
    fun clear() {
        for (i in buffer.indices) {
            buffer[i] = null
        }
        head = 0
        size = 0
    }
}