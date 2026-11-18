package jiffapex;

import java.util.ArrayList;

/** Shim for Apex {@code List<T>}. Only methods that exist in Apex are exposed. */
public final class List<T> implements Iterable<T> {
    private final ArrayList<T> items;

    public List() {
        this.items = new ArrayList<T>();
    }

    public List(List<T> other) {
        this.items = new ArrayList<T>(other.items);
    }

    public List(Set<T> other) {
        this.items = new ArrayList<T>(other.backing());
    }

    @SafeVarargs
    public static <T> List<T> of(T... values) {
        List<T> out = new List<T>();
        for (T v : values) {
            out.items.add(v);
        }
        return out;
    }

    public void add(T value) {
        items.add(value);
    }

    public void add(int index, T value) {
        if (index < 0 || index > items.size()) {
            throw new ListException("List index out of bounds: " + index);
        }
        items.add(index, value);
    }

    public void addAll(List<T> other) {
        items.addAll(other.items);
    }

    public void addAll(Set<T> other) {
        items.addAll(other.backing());
    }

    public void clear() {
        items.clear();
    }

    @Override
    public List<T> clone() {
        return new List<T>(this);
    }

    public boolean contains(T value) {
        return items.contains(value);
    }

    public T get(int index) {
        check(index);
        return items.get(index);
    }

    public int indexOf(T value) {
        return items.indexOf(value);
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

    public T remove(int index) {
        check(index);
        return items.remove(index);
    }

    public void set(int index, T value) {
        check(index);
        items.set(index, value);
    }

    public int size() {
        return items.size();
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    public void sort() {
        items.sort((a, b) -> {
            if (a instanceof Comparable) {
                return ((Comparable) a).compareTo(b);
            }
            return ((java.lang.Comparable) a).compareTo(b);
        });
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof List && items.equals(((List<?>) other).items);
    }

    @Override
    public int hashCode() {
        return items.hashCode();
    }

    @Override
    public String toString() {
        StringBuilder sb = new StringBuilder("(");
        for (int i = 0; i < items.size(); i++) {
            if (i > 0) {
                sb.append(", ");
            }
            sb.append(String.valueOf(items.get(i)));
        }
        return sb.append(")").toString();
    }

    private void check(int index) {
        if (index < 0 || index >= items.size()) {
            throw new ListException("List index out of bounds: " + index);
        }
    }
}
