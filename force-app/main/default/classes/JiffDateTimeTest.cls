@IsTest
private class JiffDateTimeTest {
    private static final String YEAR_RANGE = 'parameter \'year\' is not in the required range of -9999..=9999';
    private static final String EPOCH_DAY_RANGE = 'parameter \'Unix epoch days\' is not in the required range of -4371587..=2932896';

    private static JiffDateTime civil(
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        Integer minute,
        Integer second,
        Integer subsecNanosecond
    ) {
        return JiffDateTime.newInstance(year, month, day, hour, minute, second, subsecNanosecond);
    }

    private static void assertFails(String expected, JiffException e) {
        Assert.areEqual(expected, e.getMessage());
    }

    // ---- construction, conversion and comparison ------------------------

    @IsTest
    static void exposesItsComponents() {
        JiffDateTime dt = JiffDateTime.newInstance(2024, 2, 29, 15, 22, 45, 123456789);
        Assert.areEqual(2024, dt.year());
        Assert.areEqual(2, dt.month());
        Assert.areEqual(29, dt.day());
        Assert.areEqual(15, dt.hour());
        Assert.areEqual(22, dt.minute());
        Assert.areEqual(45, dt.second());
        Assert.areEqual(123, dt.millisecond());
        Assert.areEqual(456, dt.microsecond());
        Assert.areEqual(789, dt.nanosecond());
        Assert.areEqual(123456789, dt.subsecNanosecond());
        Assert.areEqual(JiffWeekday.THURSDAY, dt.weekday());
        Assert.areEqual(JiffDate.newInstance(2024, 2, 29), dt.toDate());
        Assert.areEqual(JiffTime.newInstance(15, 22, 45, 123456789), dt.toTime());
    }

    @IsTest
    static void zeroIsMidnightOnTheFirstDayOfYearZero() {
        // `DateTime::ZERO`, which is also Jiff's `DateTime::default()`.
        Assert.areEqual('0000-01-01T00:00:00', JiffDateTime.ZERO.toString());
        Assert.areEqual(JiffDate.ZERO.at(0, 0, 0, 0), JiffDateTime.ZERO);
        Assert.areEqual(JiffDate.ZERO, JiffDateTime.ZERO.toDate());
        Assert.areEqual(JiffTime.MIN, JiffDateTime.ZERO.toTime());
        Assert.isTrue(JiffDateTime.MIN.isBefore(JiffDateTime.ZERO));
        Assert.isTrue(JiffDateTime.MAX.isAfter(JiffDateTime.ZERO));
        // `DateTime::from(date)` is the date at midnight.
        Assert.areEqual(JiffDateTime.ZERO, JiffDate.ZERO.toDateTime(JiffTime.midnight()));
    }

    @IsTest
    static void buildsFromADateAndATime() {
        JiffDateTime dt = JiffDateTime.fromParts(
            JiffDate.newInstance(2024, 2, 29),
            JiffTime.newInstance(1, 2, 3, 4)
        );
        Assert.areEqual(JiffDateTime.newInstance(2024, 2, 29, 1, 2, 3, 4), dt);
        try {
            JiffDateTime.fromParts(null, JiffTime.midnight());
            Assert.fail('expected a missing date to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('a datetime needs both a date and a time', e.getMessage());
        }
        try {
            JiffDateTime.fromParts(JiffDate.ZERO, null);
            Assert.fail('expected a missing time to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('a datetime needs both a date and a time', e.getMessage());
        }
    }

    @IsTest
    static void validatesEveryField() {
        try {
            JiffDateTime.newInstance(2023, 2, 29, 0, 0, 0, 0);
            Assert.fail('expected an invalid date to be rejected');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('`2023-02`'), e.getMessage());
        }
        try {
            JiffDateTime.newInstance(2024, 2, 29, 24, 0, 0, 0);
            Assert.fail('expected an invalid time to be rejected');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('\'hour\''), e.getMessage());
        }
    }

    @IsTest
    static void convertsToAndFromEpochSeconds() {
        Assert.areEqual(0L, JiffDateTime.newInstance(1970, 1, 1, 0, 0, 0, 0).toEpochSecond());
        Assert.areEqual(
            1709220165L,
            JiffDateTime.newInstance(2024, 2, 29, 15, 22, 45, 5).toEpochSecond()
        );
        Assert.areEqual(
            -1L,
            JiffDateTime.newInstance(1969, 12, 31, 23, 59, 59, 999999999).toEpochSecond()
        );
        Assert.areEqual(-377705116800L, JiffDateTime.MIN.toEpochSecond());
        Assert.areEqual(253402300799L, JiffDateTime.MAX.toEpochSecond());

        Assert.areEqual(
            JiffDateTime.newInstance(1970, 1, 1, 0, 0, 0, 0),
            JiffDateTime.fromEpochSecond(0L, 0)
        );
        Assert.areEqual(
            JiffDateTime.newInstance(2024, 2, 29, 15, 22, 45, 5),
            JiffDateTime.fromEpochSecond(1709220165L, 5)
        );
        // Before the epoch the fraction still counts forward from the whole second.
        Assert.areEqual(
            JiffDateTime.newInstance(1969, 12, 31, 23, 59, 59, 999999999),
            JiffDateTime.fromEpochSecond(-1L, 999999999)
        );
        Assert.areEqual(JiffDateTime.MIN, JiffDateTime.fromEpochSecond(-377705116800L, 0));
        Assert.areEqual(JiffDateTime.MAX, JiffDateTime.fromEpochSecond(253402300799L, 999999999));
        for (Long second = -377705116800L; second <= 253402300799L; second += 86028121L * 997) {
            JiffDateTime dt = JiffDateTime.fromEpochSecond(second, 7);
            Assert.areEqual(second, dt.toEpochSecond(), 'round trip of ' + dt);
            Assert.areEqual(7, dt.subsecNanosecond());
        }
    }

    @IsTest
    static void rejectsEpochSecondsOutsideTheSupportedRange() {
        for (Long bad : new List<Long>{ -377705116801L, 253402300800L }) {
            try {
                JiffDateTime.fromEpochSecond(bad, 0);
                Assert.fail('expected an out of range second to be rejected');
            } catch (JiffException e) {
                Assert.isTrue(e.getMessage().contains('Unix epoch days'), e.getMessage());
            }
        }
        for (Integer bad : new List<Integer>{ -1, 1000000000 }) {
            try {
                JiffDateTime.fromEpochSecond(0L, bad);
                Assert.fail('expected an out of range fraction to be rejected');
            } catch (JiffException e) {
                Assert.isTrue(e.getMessage().contains('subsecond nanosecond'), e.getMessage());
            }
        }
    }

    @IsTest
    static void ordersChronologically() {
        JiffDateTime a = JiffDateTime.newInstance(2024, 2, 29, 12, 0, 0, 0);
        Assert.areEqual(0, a.compareTo(JiffDateTime.newInstance(2024, 2, 29, 12, 0, 0, 0)));
        Assert.areEqual(-1, a.compareTo(JiffDateTime.newInstance(2024, 2, 29, 12, 0, 0, 1)));
        Assert.areEqual(-1, a.compareTo(JiffDateTime.newInstance(2024, 3, 1, 0, 0, 0, 0)));
        Assert.areEqual(
            1,
            a.compareTo(JiffDateTime.newInstance(2024, 2, 28, 23, 59, 59, 999999999))
        );
        Assert.isTrue(JiffDateTime.MIN.isBefore(JiffDateTime.MAX));
        Assert.isTrue(JiffDateTime.MAX.isAfter(a));
        Assert.isFalse(a.isAfter(a));
        List<JiffDateTime> values = new List<JiffDateTime>{ JiffDateTime.MAX, a, JiffDateTime.MIN };
        values.sort();
        Assert.areEqual(JiffDateTime.MIN, values.get(0));
        Assert.areEqual(a, values.get(1));
        Assert.areEqual(JiffDateTime.MAX, values.get(2));
    }

    @IsTest
    static void equalsAndHashesByValue() {
        JiffDateTime a = JiffDateTime.newInstance(2024, 2, 29, 12, 0, 0, 0);
        Assert.isTrue(a.equals(JiffDateTime.newInstance(2024, 2, 29, 12, 0, 0, 0)));
        Assert.areEqual(
            a.hashCode(),
            JiffDateTime.newInstance(2024, 2, 29, 12, 0, 0, 0).hashCode()
        );
        Assert.isFalse(a.equals(JiffDateTime.newInstance(2024, 2, 29, 12, 0, 0, 1)));
        Assert.isFalse(a.equals(JiffDateTime.newInstance(2024, 2, 28, 12, 0, 0, 0)));
        Assert.isFalse(a.equals(a.toDate()));
        Map<JiffDateTime, String> names = new Map<JiffDateTime, String>{ a => 'noon' };
        Assert.areEqual('noon', names.get(JiffDateTime.newInstance(2024, 2, 29, 12, 0, 0, 0)));
    }

    @IsTest
    static void printsIso8601() {
        Assert.areEqual(
            '2024-02-29T15:22:45',
            JiffDateTime.newInstance(2024, 2, 29, 15, 22, 45, 0).toString()
        );
        Assert.areEqual(
            '2024-02-29T15:22:45.5',
            JiffDateTime.newInstance(2024, 2, 29, 15, 22, 45, 500000000).toString()
        );
        Assert.areEqual('-009999-01-01T00:00:00', JiffDateTime.MIN.toString());
        Assert.areEqual('9999-12-31T23:59:59.999999999', JiffDateTime.MAX.toString());
    }

    // ---- accessors that defer to the date -------------------------------

    @IsTest
    static void theUnixEpochWasAThursday() {
        Assert.areEqual(JiffWeekday.THURSDAY, civil(1970, 1, 1, 7, 30, 0, 0).weekday());
        Assert.areEqual(JiffWeekday.FRIDAY, JiffDateTime.MAX.weekday());
        Assert.areEqual(JiffWeekday.MONDAY, JiffDateTime.MIN.weekday());
    }

    @IsTest
    static void reportsTheYearWithinItsEra() {
        Assert.areEqual(2024, civil(2024, 10, 3, 7, 30, 0, 0).eraYear());
        Assert.areEqual(JiffEra.CE, civil(2024, 10, 3, 7, 30, 0, 0).era());
        Assert.areEqual(1, civil(1, 10, 3, 7, 30, 0, 0).eraYear());
        Assert.areEqual(JiffEra.CE, civil(1, 10, 3, 7, 30, 0, 0).era());
        Assert.areEqual(1, civil(0, 10, 3, 7, 30, 0, 0).eraYear());
        Assert.areEqual(JiffEra.BCE, civil(0, 10, 3, 7, 30, 0, 0).era());
        Assert.areEqual(2, civil(-1, 10, 3, 7, 30, 0, 0).eraYear());
        Assert.areEqual(JiffEra.BCE, civil(-1, 10, 3, 7, 30, 0, 0).era());
        Assert.areEqual(11, civil(-10, 10, 3, 7, 30, 0, 0).eraYear());
        Assert.areEqual(JiffEra.BCE, civil(-10, 10, 3, 7, 30, 0, 0).era());
        Assert.areEqual(10000, civil(-9999, 10, 3, 7, 30, 0, 0).eraYear());
        Assert.areEqual(JiffEra.BCE, civil(-9999, 10, 3, 7, 30, 0, 0).era());
    }

    @IsTest
    static void reportsThePositionOfItsDateInTheYear() {
        Assert.areEqual(236, civil(2006, 8, 24, 7, 30, 0, 0).dayOfYear());
        Assert.areEqual(365, civil(2023, 12, 31, 7, 30, 0, 0).dayOfYear());
        Assert.areEqual(366, civil(2024, 12, 31, 7, 30, 0, 0).dayOfYear());
    }

    @IsTest
    static void reportsThePositionOfItsDateInTheYearIgnoringLeapDays() {
        Assert.areEqual(236, civil(2006, 8, 24, 7, 30, 0, 0).dayOfYearNoLeap());
        Assert.areEqual(365, civil(2023, 12, 31, 7, 30, 0, 0).dayOfYearNoLeap());
        Assert.areEqual(365, civil(2024, 12, 31, 7, 30, 0, 0).dayOfYearNoLeap());
        Integer leapDay = civil(2024, 2, 29, 7, 30, 0, 0).dayOfYearNoLeap();
        Assert.isTrue(leapDay == null, 'February 29th has no position');
    }

    @IsTest
    static void countsTheDaysInItsMonthAndYear() {
        Assert.areEqual(29, civil(2024, 2, 10, 7, 30, 0, 0).daysInMonth());
        Assert.areEqual(28, civil(2023, 2, 10, 7, 30, 0, 0).daysInMonth());
        Assert.areEqual(31, civil(2024, 8, 15, 7, 30, 0, 0).daysInMonth());
        Assert.areEqual(366, civil(2024, 7, 10, 7, 30, 0, 0).daysInYear());
        Assert.areEqual(365, civil(2023, 7, 10, 7, 30, 0, 0).daysInYear());
        Assert.isTrue(civil(2024, 1, 1, 7, 30, 0, 0).inLeapYear());
        Assert.isFalse(civil(2023, 12, 31, 7, 30, 0, 0).inLeapYear());
    }

    @IsTest
    static void convertsItsDateToAnIsoWeekDate() {
        JiffIsoWeekDate weekDate = civil(1995, 1, 1, 18, 45, 0, 0).toIsoWeekDate();
        Assert.areEqual(1994, weekDate.year());
        Assert.areEqual(52, weekDate.week());
        Assert.areEqual(JiffWeekday.SUNDAY, weekDate.weekday());

        weekDate = civil(1996, 12, 31, 18, 45, 0, 0).toIsoWeekDate();
        Assert.areEqual(1997, weekDate.year());
        Assert.areEqual(1, weekDate.week());
        Assert.areEqual(JiffWeekday.TUESDAY, weekDate.weekday());

        weekDate = civil(2019, 12, 30, 18, 45, 0, 0).toIsoWeekDate();
        Assert.areEqual(2020, weekDate.year());
        Assert.areEqual(1, weekDate.week());
        Assert.areEqual(JiffWeekday.MONDAY, weekDate.weekday());

        weekDate = civil(2024, 3, 9, 18, 45, 0, 0).toIsoWeekDate();
        Assert.areEqual(2024, weekDate.year());
        Assert.areEqual(10, weekDate.week());
        Assert.areEqual(JiffWeekday.SATURDAY, weekDate.weekday());

        weekDate = JiffDateTime.MIN.toIsoWeekDate();
        Assert.areEqual(-9999, weekDate.year());
        Assert.areEqual(1, weekDate.week());
        Assert.areEqual(JiffWeekday.MONDAY, weekDate.weekday());

        weekDate = JiffDateTime.MAX.toIsoWeekDate();
        Assert.areEqual(9999, weekDate.year());
        Assert.areEqual(52, weekDate.week());
        Assert.areEqual(JiffWeekday.FRIDAY, weekDate.weekday());
    }

    // ---- neighbouring datetimes -----------------------------------------

    @IsTest
    static void findsTheStartAndTheEndOfItsDay() {
        JiffDateTime dt = civil(2024, 7, 3, 7, 30, 10, 123456789);
        Assert.areEqual(civil(2024, 7, 3, 0, 0, 0, 0), dt.startOfDay());
        Assert.areEqual(civil(2024, 7, 3, 23, 59, 59, 999999999), dt.endOfDay());
        Assert.areEqual(JiffDateTime.MIN, JiffDateTime.MIN.startOfDay());
        Assert.areEqual(JiffDateTime.MAX, JiffDateTime.MAX.endOfDay());
    }

    @IsTest
    static void findsTheFirstAndLastDayOfItsMonthKeepingTheTime() {
        Assert.areEqual(
            civil(2024, 2, 1, 7, 30, 0, 0),
            civil(2024, 2, 29, 7, 30, 0, 0).firstOfMonth()
        );
        Assert.areEqual(
            civil(2024, 2, 29, 7, 30, 0, 0),
            civil(2024, 2, 5, 7, 30, 0, 0).lastOfMonth()
        );
    }

    @IsTest
    static void findsTheFirstAndLastDayOfItsYearKeepingTheTime() {
        Assert.areEqual(
            civil(2024, 1, 1, 7, 30, 0, 0),
            civil(2024, 2, 29, 7, 30, 0, 0).firstOfYear()
        );
        Assert.areEqual(
            civil(2024, 12, 31, 7, 30, 0, 0),
            civil(2024, 2, 5, 7, 30, 0, 0).lastOfYear()
        );
    }

    @IsTest
    static void tomorrowKeepsTheTimeAndFailsOnTheLastDay() {
        Assert.areEqual(
            civil(2024, 2, 29, 7, 30, 0, 0),
            civil(2024, 2, 28, 7, 30, 0, 0).tomorrow()
        );
        // The max doesn't have a tomorrow, and neither does any other time on its date.
        for (
            JiffDateTime last : new List<JiffDateTime>{
                JiffDateTime.MAX,
                civil(9999, 12, 31, 12, 0, 0, 0)
            }
        ) {
            try {
                JiffDateTime unexpected = last.tomorrow();
                Assert.fail('expected no tomorrow for ' + last + ' but got ' + unexpected);
            } catch (JiffException e) {
                assertFails(YEAR_RANGE, e);
            }
        }
    }

    @IsTest
    static void yesterdayKeepsTheTimeAndFailsOnTheFirstDay() {
        Assert.areEqual(
            civil(2024, 2, 29, 7, 30, 0, 0),
            civil(2024, 3, 1, 7, 30, 0, 0).yesterday()
        );
        try {
            JiffDateTime unexpected = JiffDateTime.MIN.yesterday();
            Assert.fail('expected no yesterday for the minimum but got ' + unexpected);
        } catch (JiffException e) {
            assertFails(YEAR_RANGE, e);
        }
    }

    @IsTest
    static void findsTheNthWeekdayOfItsMonth() {
        Assert.areEqual(
            civil(2017, 3, 10, 7, 30, 0, 0),
            civil(2017, 3, 1, 7, 30, 0, 0).nthWeekdayOfMonth(2, JiffWeekday.FRIDAY)
        );
        JiffDateTime march = civil(2024, 3, 1, 7, 30, 0, 0);
        Assert.areEqual(
            civil(2024, 3, 28, 7, 30, 0, 0),
            march.nthWeekdayOfMonth(-1, JiffWeekday.THURSDAY)
        );
        Assert.areEqual(
            civil(2024, 3, 21, 7, 30, 0, 0),
            march.nthWeekdayOfMonth(-2, JiffWeekday.THURSDAY)
        );
        // March 2024 only has four Mondays.
        JiffDateTime dt = civil(2024, 3, 25, 7, 30, 0, 0);
        Assert.areEqual(dt, dt.nthWeekdayOfMonth(4, JiffWeekday.MONDAY));
        Map<Integer, String> failures = new Map<Integer, String>{
            5 => 'parameter \'day\' for `2024-03` is invalid, must be in range `1..=31`',
            -5 => 'parameter \'day\' is not in the required range of 1..=31',
            0 => 'parameter \'nth weekday of month\' is not in the required range of -5..=5'
        };
        for (Integer nth : failures.keySet()) {
            try {
                JiffDateTime unexpected = dt.nthWeekdayOfMonth(nth, JiffWeekday.MONDAY);
                Assert.fail('expected no Monday number ' + nth + ' but got ' + unexpected);
            } catch (JiffException e) {
                assertFails(failures.get(nth), e);
            }
        }
    }

    @IsTest
    static void findsTheNthWeekdayAfterOrBeforeItsDate() {
        // A Sunday in March.
        JiffDateTime dt = civil(2024, 3, 10, 7, 30, 0, 0);
        Assert.areEqual(JiffWeekday.SUNDAY, dt.weekday());
        // The first next Monday is tomorrow, but the next Sunday is a week away.
        Assert.areEqual(civil(2024, 3, 11, 7, 30, 0, 0), dt.nthWeekday(1, JiffWeekday.MONDAY));
        Assert.areEqual(civil(2024, 3, 17, 7, 30, 0, 0), dt.nthWeekday(1, JiffWeekday.SUNDAY));
        // "Not this Thursday, but next Thursday."
        Assert.areEqual(civil(2024, 3, 21, 7, 30, 0, 0), dt.nthWeekday(2, JiffWeekday.THURSDAY));
        // "Last Saturday" was yesterday, and "last Sunday" was a week ago.
        Assert.areEqual(civil(2024, 3, 9, 7, 30, 0, 0), dt.nthWeekday(-1, JiffWeekday.SATURDAY));
        Assert.areEqual(civil(2024, 3, 3, 7, 30, 0, 0), dt.nthWeekday(-1, JiffWeekday.SUNDAY));
        Assert.areEqual(civil(2024, 2, 29, 7, 30, 0, 0), dt.nthWeekday(-2, JiffWeekday.THURSDAY));
    }

    @IsTest
    static void theNthWeekdayFailsBeyondTheSupportedRangeAndForZero() {
        try {
            JiffDateTime unexpected = JiffDateTime.MAX.nthWeekday(1, JiffWeekday.SATURDAY);
            Assert.fail('expected no Saturday after the maximum but got ' + unexpected);
        } catch (JiffException e) {
            assertFails(EPOCH_DAY_RANGE, e);
        }
        try {
            JiffDateTime unexpected = JiffDateTime.MIN.nthWeekday(-1, JiffWeekday.SUNDAY);
            Assert.fail('expected no Sunday before the minimum but got ' + unexpected);
        } catch (JiffException e) {
            assertFails(EPOCH_DAY_RANGE, e);
        }
        try {
            JiffDateTime unexpected = JiffDateTime.MAX.nthWeekday(0, JiffWeekday.MONDAY);
            Assert.fail('expected a count of zero to be rejected but got ' + unexpected);
        } catch (JiffException e) {
            assertFails(
                'parameter \'nth weekday\' is not in the required range of -1043497..=1043497',
                e
            );
        }
    }

    @IsTest
    static void findsTheStartOfIsraeliSummerTime() {
        // The Friday before the last Sunday in March.
        JiffDateTime march = civil(2024, 3, 1, 0, 0, 0, 0);
        JiffDateTime lastSunday = march.nthWeekdayOfMonth(-1, JiffWeekday.SUNDAY);
        Assert.areEqual(
            civil(2024, 3, 29, 0, 0, 0, 0),
            lastSunday.nthWeekday(-1, JiffWeekday.FRIDAY)
        );
    }

    @IsTest
    static void findsTheStartOfTheWeek() {
        JiffDateTime dt = civil(2024, 3, 15, 7, 30, 0, 0);
        // For weeks starting with Sunday, and then with Monday.
        Assert.areEqual(
            civil(2024, 3, 10, 7, 30, 0, 0),
            dt.tomorrow().nthWeekday(-1, JiffWeekday.SUNDAY)
        );
        Assert.areEqual(
            civil(2024, 3, 11, 7, 30, 0, 0),
            dt.tomorrow().nthWeekday(-1, JiffWeekday.MONDAY)
        );
        // It works at the boundaries of a week too.
        JiffDateTime weekStart = civil(2024, 3, 10, 0, 0, 0, 0);
        Assert.areEqual(weekStart, weekStart.tomorrow().nthWeekday(-1, JiffWeekday.SUNDAY));
        JiffDateTime weekEnd = civil(2024, 3, 16, 23, 59, 59, 999999999);
        Assert.areEqual(
            weekStart,
            weekEnd.tomorrow()
                .nthWeekday(-1, JiffWeekday.SUNDAY)
                .with()
                .withTime(JiffTime.midnight())
                .build()
        );
    }

    // ---- entry points to the builder and the series ---------------------

    @IsTest
    static void startsABuilderFromItsOwnFields() {
        JiffDateTime dt1 = civil(2024, 10, 31, 0, 0, 0, 0);
        Assert.areEqual(civil(2024, 11, 30, 0, 0, 0, 0), dt1.with().month(11).day(30).build());
        Assert.areEqual(dt1, dt1.with().build());
    }

    @IsTest
    static void startsASeriesAtItself() {
        JiffDateTimeSeries series = civil(2023, 7, 15, 16, 30, 0, 0)
            .series(new JiffSpan().hours(5));
        Assert.areEqual(civil(2023, 7, 15, 16, 30, 0, 0), series.next());
        Assert.areEqual(civil(2023, 7, 15, 21, 30, 0, 0), series.next());
        Assert.areEqual(civil(2023, 7, 16, 2, 30, 0, 0), series.next());
    }

    // ---- zoned datetimes --------------------------------------------------

    @IsTest
    static void becomesAZonedDatetimeInAGivenZone() {
        JiffTimeZone tz = JiffTimeZone.fixed(JiffOffset.fromHours(-4));
        JiffZonedDateTime zdt = civil(2024, 6, 20, 17, 3, 0, 0).toZonedDateTime(tz);
        // A time zone annotation is still included in the printable version of the zoned
        // datetime, but it is fixed to a particular offset.
        Assert.areEqual('2024-06-20T17:03:00-04:00[-04:00]', zdt.toString());
        Assert.areEqual(
            '2024-06-20T17:03:00-04:00[America/New_York]',
            civil(2024, 6, 20, 17, 3, 0, 0).inTz('America/New_York').toString()
        );
        Assert.areEqual(civil(2024, 6, 20, 17, 3, 0, 0), zdt.toDateTime());
    }

    @IsTest
    static void aZonedDatetimeResolvesGapsAndFoldsCompatibly() {
        JiffTimeZone newYork = JiffTimeZone.get('America/New_York');
        Assert.areEqual(
            '2024-03-10T03:30:00-04:00[America/New_York]',
            civil(2024, 3, 10, 2, 30, 0, 0).toZonedDateTime(newYork).toString()
        );
        Assert.areEqual(
            '2024-11-03T01:30:00-04:00[America/New_York]',
            civil(2024, 11, 3, 1, 30, 0, 0).toZonedDateTime(newYork).toString()
        );
        Assert.areEqual(
            '2024-03-31T02:30:00+01:00[Europe/London]',
            civil(2024, 3, 31, 1, 30, 0, 0).inTz('Europe/London').toString()
        );
        Assert.areEqual(
            '2024-04-07T02:30:00+11:00[Australia/Sydney]',
            civil(2024, 4, 7, 2, 30, 0, 0).inTz('Australia/Sydney').toString()
        );
    }

    @IsTest
    static void aZonedDatetimeMustBeAnInstantInRange() {
        // All errors because the combination of the offset and the datetime isn't enough to
        // fit into timestamp limits.
        try {
            JiffDateTime.MAX.inTz('UTC');
            Assert.fail('expected the maximum datetime to have no instant in UTC');
        } catch (JiffException e) {
            Assert.areEqual(
                'converting datetime with time zone offset `+00` to timestamp overflowed: ' +
                    'parameter \'Unix timestamp seconds\' is not in the required range of ' +
                    '-377705023201..=253402207200',
                e.getMessage()
            );
        }
        // In fact, the only valid offset one can use to turn the maximum civil datetime into
        // a zoned datetime is the maximum offset:
        JiffTimeZone tz = JiffOffset.fromSeconds(93599).toTimeZone();
        Assert.areEqual(
            '9999-12-31T23:59:59.999999999+25:59[+25:59]',
            JiffDateTime.MAX.toZonedDateTime(tz).toString()
        );
        // One second less than the maximum offset results in a failure at the maximum
        // datetime boundary.
        try {
            JiffDateTime.MAX.toZonedDateTime(JiffOffset.fromSeconds(93598).toTimeZone());
            Assert.fail('expected the maximum datetime to need the maximum offset');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('`+25:59:58`'), e.getMessage());
        }
        Assert.areEqual(
            '-009999-01-01T00:00:00-25:59[-25:59]',
            JiffDateTime.MIN.toZonedDateTime(JiffOffset.fromSeconds(-93599).toTimeZone()).toString()
        );
    }

    @IsTest
    static void aZonedDatetimeNeedsAKnownZone() {
        try {
            civil(2024, 6, 20, 15, 6, 0, 0).inTz('does not exist');
            Assert.fail('expected an unknown time zone to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to find time zone `does not exist` in time zone database',
                e.getMessage()
            );
        }
    }

    // ---- platform interop -----------------------------------------------

    @IsTest
    static void readsAPlatformDatetimeOnTheWallClockOfAZone() {
        Datetime value = Datetime.newInstanceGmt(2024, 7, 4, 12, 39, 0);
        Assert.areEqual(
            civil(2024, 7, 4, 8, 39, 0, 0),
            JiffDateTime.fromSystemDatetime(value, JiffTimeZone.get('America/New_York'))
        );
        Assert.areEqual(
            civil(2024, 7, 4, 18, 9, 0, 0),
            JiffDateTime.fromSystemDatetime(value, JiffTimeZone.get('Asia/Kolkata'))
        );
        Assert.areEqual(
            civil(2024, 7, 4, 12, 39, 0, 0),
            JiffDateTime.fromSystemDatetime(value, JiffTimeZone.UTC)
        );
        Assert.areEqual(
            civil(2024, 7, 4, 7, 39, 0, 0),
            JiffDateTime.fromSystemDatetime(value, JiffTimeZone.fixed(JiffOffset.fromHours(-5)))
        );
        // Milliseconds are kept.
        Assert.areEqual(
            civil(2024, 7, 4, 8, 39, 0, 123000000),
            JiffDateTime.fromSystemDatetime(
                Datetime.newInstance(1720096740123L),
                JiffTimeZone.get('America/New_York')
            )
        );
    }

    @IsTest
    static void aNullPlatformDatetimeGivesNull() {
        Datetime missing = null;
        Assert.isNull(JiffDateTime.fromSystemDatetime(missing, JiffTimeZone.UTC));
        try {
            JiffDateTime.fromSystemDatetime(Datetime.newInstance(0L), null);
            Assert.fail('expected a missing time zone to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('the time zone to read a Datetime in must not be null', e.getMessage());
        }
    }

    @IsTest
    static void convertsToAPlatformDatetimeInAZone() {
        JiffTimeZone newYork = JiffTimeZone.get('America/New_York');
        Assert.areEqual(
            Datetime.newInstanceGmt(2024, 7, 4, 12, 39, 0),
            civil(2024, 7, 4, 8, 39, 0, 0).toSystemDatetime(newYork)
        );
        // A skipped time moves forward by the length of the gap: 03:30 at -04.
        Assert.areEqual(
            1710055800000L,
            civil(2024, 3, 10, 2, 30, 0, 0).toSystemDatetime(newYork).getTime()
        );
        // A repeated time means its first occurrence: 01:30 at -04.
        Assert.areEqual(
            1730611800000L,
            civil(2024, 11, 3, 1, 30, 0, 0).toSystemDatetime(newYork).getTime()
        );
        // Anything finer than a millisecond is dropped, truncating toward the epoch.
        Assert.areEqual(
            1720096740123L,
            civil(2024, 7, 4, 8, 39, 0, 123456789).toSystemDatetime(newYork).getTime()
        );
        Assert.areEqual(
            0L,
            civil(1969, 12, 31, 23, 59, 59, 999999999).toSystemDatetime(JiffTimeZone.UTC).getTime()
        );
        // It is the inverse of reading a platform Datetime in the same zone.
        Datetime original = Datetime.newInstance(1720096740123L);
        Assert.areEqual(
            original,
            JiffDateTime.fromSystemDatetime(original, newYork).toSystemDatetime(newYork)
        );
    }

    @IsTest
    static void convertingToAPlatformDatetimeCanFail() {
        try {
            civil(2024, 7, 4, 8, 39, 0, 0).toSystemDatetime(null);
            Assert.fail('expected a missing time zone to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'the time zone to resolve a datetime in must not be null',
                e.getMessage()
            );
        }
        try {
            JiffDateTime.MAX.toSystemDatetime(JiffTimeZone.UTC);
            Assert.fail('expected the maximum datetime to have no instant in UTC');
        } catch (JiffException e) {
            Assert.areEqual(
                'converting datetime with time zone offset `+00` to timestamp overflowed: ' +
                    'parameter \'Unix timestamp seconds\' is not in the required range of ' +
                    '-377705023201..=253402207200',
                e.getMessage()
            );
        }
    }
}
