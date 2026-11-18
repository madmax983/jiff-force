package jiffapex;

import java.util.LinkedHashMap;

/** Shim for Apex {@code Map<K, V>}. String keys are case-sensitive, as in Apex. */
public final class Map<K, V> {
    private final LinkedHashMap<K, V> items;

    public Map() {
        this.items = new LinkedHashMap<K, V>();
    }

    public Map(Map<K, V> other) {
        this.items = new LinkedHashMap<K, V>(other.items);
    }

    @SuppressWarnings("unchecked")
    public static <K, V> Map<K, V> of(Object... keysAndValues) {
        Map<K, V> out = new Map<K, V>();
        for (int i = 0; i < keysAndValues.length; i += 2) {
            out.items.put((K) keysAndValues[i], (V) keysAndValues[i + 1]);
        }
        return out;
    }

    public void clear() {
        items.clear();
    }

    @Override
    public Map<K, V> clone() {
        return new Map<K, V>(this);
    }

    public boolean containsKey(K key) {
        return items.containsKey(key);
    }

    public V get(K key) {
        return items.get(key);
    }

    public boolean isEmpty() {
        return items.isEmpty();
    }

    public Set<K> keySet() {
        Set<K> out = new Set<K>();
        for (K k : items.keySet()) {
            out.add(k);
        }
        return out;
    }

    public V put(K key, V value) {
        return items.put(key, value);
    }

    public void putAll(Map<K, V> other) {
        items.putAll(other.items);
    }

    public V remove(K key) {
        return items.remove(key);
    }

    public int size() {
        return items.size();
    }

    public List<V> values() {
        List<V> out = new List<V>();
        for (V v : items.values()) {
            out.add(v);
        }
        return out;
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof Map && items.equals(((Map<?, ?>) other).items);
    }

    @Override
    public int hashCode() {
        return items.hashCode();
    }

    @Override
    public String toString() {
        return items.toString();
    }
}
