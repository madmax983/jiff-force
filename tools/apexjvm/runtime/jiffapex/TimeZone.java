package jiffapex;

/**
 * Shim for Apex {@code System.TimeZone}. Salesforce's implementation is
 * backed by the JVM's own zone data, so delegating to java.util.TimeZone
 * reproduces platform behaviour, including falling back to GMT for an
 * unrecognised identifier.
 */
public final class TimeZone {
    private final java.util.TimeZone zone;

    private TimeZone(java.util.TimeZone zone) {
        this.zone = zone;
    }

    public static TimeZone getTimeZone(String id) {
        return new TimeZone(java.util.TimeZone.getTimeZone(id));
    }

    public String getID() {
        return zone.getID();
    }

    public String getDisplayName() {
        return zone.getDisplayName();
    }

    /** Offset from GMT, in milliseconds, in effect at the given instant. */
    public int getOffset(Datetime instant) {
        return zone.getOffset(instant.getTime());
    }

    @Override
    public String toString() {
        return zone.getID();
    }
}
