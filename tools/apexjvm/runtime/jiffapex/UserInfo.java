package jiffapex;

/** Shim for Apex {@code UserInfo}. The user's zone comes from a system property. */
public final class UserInfo {
    private UserInfo() {}

    public static TimeZone getTimeZone() {
        return TimeZone.getTimeZone(java.lang.System.getProperty("apexjvm.userTimeZone", "America/Los_Angeles"));
    }
}
