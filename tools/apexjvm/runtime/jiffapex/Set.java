package jiffapex;

import java.util.LinkedHashSet;

/** Shim for Apex {@code Set<T>}. */
public final class Set<T> implements Iterable<T> {
    private final LinkedHashSet<T> items;

    public Set() {
        this.items = new LinkedHashSet<T>();
    }

    public Set(Set<T> other) {
        this.items = new LinkedHashSet<T>(other.items);
    }

    public Set(List<T> other) {
        this.items = new LinkedHashSet<T>();
        for (T v : other) {
            this.items.add(v);
        }
    }

    @SafeVarargs
    public static <T> Set<T> of(T... values) {
        Set<T> out = new Set<T>();
        for (T v : values) {
            out.items.add(v);
        }
        return out;
    }

    LinkedHashSet<T> backing() {
        return items;
    }

    public boolean add(T value) {
        return items.add(value);
    }

    public boolean addAll(List<T> other) {
        boolean changed = false;
        for (T v : other) {
            changed |= items.add(v);
        }
        return changed;
    }

    public boolean addAll(Set<T> other) {
        return items.addAll(other.items);
    }

    public void clear() {
        items.clear();
    }

    @Override
    public Set<T> clone() {
        return new Set<T>(this);
    }

    public boolean contains(T value) {
        return items.contains(value);
    }

    public boolean isEmpty() {
        return items.isEmpty();
    }

    @Override
    public Iterator<T> iterator() {
        final java.util.Iterator<T> it = items.iterator();
        return new Iterator<T>() {
            @Override
            public boolean hasNext() {
                return it.hasNext();
            }

            @Override
            public T next() {
                return it.next();
            }
        };
    }

    public boolean remove(T value) {
        return items.remove(value);
    }

    public int size() {
        return items.size();
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof Set && items.equals(((Set<?>) other).items);
    }

    @Override
    public int hashCode() {
        return items.hashCode();
    }

    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder("{");
        boolean first = true;
        for (T v : items) {
            if (!first) {
                sb.append(", ");
            }
            first = false;
            sb.append(String.valueOf(v));
        }
        return sb.append("}").toString();
    }
}
