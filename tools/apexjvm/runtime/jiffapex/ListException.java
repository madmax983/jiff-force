package jiffapex;

/** Shim for {@code System.ListException}. */
public class ListException extends ApexException {
    public ListException(String message) {
        super(message);
    }
}
