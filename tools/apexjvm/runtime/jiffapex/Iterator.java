package jiffapex;

/** Shim for Apex {@code Iterator<T>}. */
public interface Iterator<T> extends java.util.Iterator<T> {
    @Override
    boolean hasNext();

    @Override
    T next();
}
