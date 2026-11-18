package jiffapex;

/**
 * Shim for {@code System.AssertException}. It is an Error so that, as in
 * Apex, a {@code catch (Exception e)} block cannot swallow a failed assertion.
 */
public class AssertException extends Error {
    public AssertException(String message) {
        super(message);
    }
}
