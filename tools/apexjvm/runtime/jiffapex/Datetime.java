package jiffapex;

import java.text.SimpleDateFormat;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;

/** Shim for Apex {@code Datetime}: an instant with millisecond precision. */
public final class Datetime {
    private final long millis;

    private Datetime(long millis) {
        this.millis = millis;
    }

    static long clockMillis() {
        String fixed = java.lang.System.getProperty("apexjvm.now");
        return fixed != null ? Long.parseLong(fixed) : java.lang.System.currentTimeMillis();
    }

    public static Datetime now() {
        return new Datetime(clockMillis());
    }

    public static Datetime newInstance(long milliseconds) {
        return new Datetime(milliseconds);
    }

    /** Constructs from civil fields in the running user's time zone. */
    public static Datetime newInstance(int year, int month, int day, int hour, int minute, int second) {
        ZoneId zone = ZoneId.of(UserInfo.getTimeZone().getID());
        return new Datetime(lenient(year, month, day, hour, minute, second).atZone(zone).toInstant().toEpochMilli());
    }

    public static Datetime newInstanceGmt(int year, int month, int day, int hour, int minute, int second) {
        return new Datetime(lenient(year, month, day, hour, minute, second).toInstant(ZoneOffset.UTC).toEpochMilli());
    }

    public static Datetime newInstanceGmt(int year, int month, int day) {
        return newInstanceGmt(year, month, day, 0, 0, 0);
    }

    public static Datetime newInstanceGmt(Date date, Time time) {
        return new Datetime(
            LocalDateTime.of(date.local(), time.local()).toInstant(ZoneOffset.UTC).toEpochMilli());
    }

    private static LocalDateTime lenient(int year, int month, int day, int hour, int minute, int second) {
        return LocalDateTime.of(year, 1, 1, 0, 0, 0)
            .plusMonths(month - 1L).plusDays(day - 1L).plusHours(hour).plusMinutes(minute).plusSeconds(second);
    }

    private ZonedDateTime utc() {
        return Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC);
    }

    public long getTime() {
        return millis;
    }

    public int yearGmt() {
        return utc().getYear();
    }

    public int monthGmt() {
        return utc().getMonthValue();
    }

    public int dayGmt() {
        return utc().getDayOfMonth();
    }

    public int hourGmt() {
        return utc().getHour();
    }

    public int minuteGmt() {
        return utc().getMinute();
    }

    public int secondGmt() {
        return utc().getSecond();
    }

    public int millisecondGmt() {
        return utc().getNano() / 1_000_000;
    }

    public Date dateGmt() {
        return Date.ofLocal(utc().toLocalDate());
    }

    public Time timeGmt() {
        return Time.ofLocal(utc().toLocalTime());
    }

    public String format(String pattern, String timeZoneId) {
        SimpleDateFormat f = new SimpleDateFormat(pattern, java.util.Locale.US);
        f.setTimeZone(java.util.TimeZone.getTimeZone(timeZoneId));
        return f.format(new java.util.Date(millis));
    }

    public String formatGmt(String pattern) {
        return format(pattern, "GMT");
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof Datetime && ((Datetime) other).millis == millis;
    }

    @Override
    public int hashCode() {
        return Long.hashCode(millis);
    }

    @Override
    public String toString() {
        return formatGmt("yyyy-MM-dd HH:mm:ss");
    }
}
