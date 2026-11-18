package jiffapex;

import java.time.LocalTime;

/** Shim for Apex {@code Time}: a wall clock time with millisecond precision. */
public final class Time {
    private final LocalTime value;

    private Time(LocalTime value) {
        this.value = value;
    }

    static Time ofLocal(LocalTime value) {
        return new Time(value);
    }

    LocalTime local() {
        return value;
    }

    public static Time newInstance(int hour, int minute, int second, int millisecond) {
        return new Time(LocalTime.MIDNIGHT
            .plusHours(hour).plusMinutes(minute).plusSeconds(second).plusNanos(millisecond * 1_000_000L));
    }

    public int hour() {
        return value.getHour();
    }

    public int minute() {
        return value.getMinute();
    }

    public int second() {
        return value.getSecond();
    }

    public int millisecond() {
        return value.getNano() / 1_000_000;
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof Time && ((Time) other).value.equals(value);
    }

    @Override
    public int hashCode() {
        return value.hashCode();
    }

    @Override
    public String toString() {
        return String.format("%02d:%02d:%02d.%03dZ", hour(), minute(), second(), millisecond());
    }
}
