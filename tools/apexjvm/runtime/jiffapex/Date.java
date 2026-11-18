package jiffapex;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

/** Shim for Apex {@code Date}: a calendar date with no time or zone. */
public final class Date {
    private final LocalDate value;

    private Date(LocalDate value) {
        this.value = value;
    }

    static Date ofLocal(LocalDate value) {
        return new Date(value);
    }

    LocalDate local() {
        return value;
    }

    public static Date newInstance(int year, int month, int day) {
        return new Date(LocalDate.of(year, 1, 1).plusMonths(month - 1L).plusDays(day - 1L));
    }

    public static Date today() {
        return Datetime.now().dateGmt();
    }

    public static int daysInMonth(int year, int month) {
        return LocalDate.of(year, month, 1).lengthOfMonth();
    }

    public static boolean isLeapYear(int year) {
        return java.time.Year.isLeap(year);
    }

    public int year() {
        return value.getYear();
    }

    public int month() {
        return value.getMonthValue();
    }

    public int day() {
        return value.getDayOfMonth();
    }

    public int dayOfYear() {
        return value.getDayOfYear();
    }

    public Date addDays(int days) {
        return new Date(value.plusDays(days));
    }

    public Date addMonths(int months) {
        return new Date(value.plusMonths(months));
    }

    public Date addYears(int years) {
        return new Date(value.plusYears(years));
    }

    public int daysBetween(Date other) {
        return (int) ChronoUnit.DAYS.between(value, other.value);
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof Date && ((Date) other).value.equals(value);
    }

    @Override
    public int hashCode() {
        return value.hashCode();
    }

    @Override
    public String toString() {
        return value + " 00:00:00";
    }
}
