package jiffapex;

/**
 * Shim for the Apex {@code System} class (the subset jiff-force uses).
 * Assertions go through {@link Assert}; {@code System.assert} cannot be
 * shimmed because {@code assert} is a Java keyword.
 */
public final class System {
    private System() {}

    public static long currentTimeMillis() {
        return Datetime.clockMillis();
    }

    public static Datetime now() {
        return Datetime.now();
    }

    public static void debug(Object message) {
        java.lang.System.err.println("DEBUG|" + message);
    }
}
