package jiffapex;

/** Shim for Apex {@code System.Comparable}, which is not generic. */
public interface Comparable {
    int compareTo(Object compareTo);
}
