@IsTest
private class JiffDateTest {
    private static void assertRejected(Integer year, Integer month, Integer day, String expected) {
        try {
            JiffDate.newInstance(year, month, day);
            Assert.fail('expected ' + year + '-' + month + '-' + day + ' to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    @IsTest
    static void exposesItsComponents() {
        JiffDate d = JiffDate.newInstance(2024, 2, 29);
        Assert.areEqual(2024, d.year());
        Assert.areEqual(2, d.month());
        Assert.areEqual(29, d.day());
        Assert.areEqual(JiffWeekday.THURSDAY, d.weekday());
    }

    @IsTest
    static void rejectsOutOfRangeComponentsWithJiffsWording() {
        assertRejected(
            10000,
            1,
            1,
            'parameter \'year\' is not in the required range of -9999..=9999'
        );
        assertRejected(
            -10000,
            1,
            1,
            'parameter \'year\' is not in the required range of -9999..=9999'
        );
        assertRejected(2024, 0, 1, 'parameter \'month\' is not in the required range of 1..=12');
        assertRejected(2024, 13, 1, 'parameter \'month\' is not in the required range of 1..=12');
        assertRejected(2024, 1, 0, 'parameter \'day\' is not in the required range of 1..=31');
        assertRejected(
            2024,
            1,
            32,
            'parameter \'day\' for `2024-01` is invalid, must be in range `1..=31`'
        );
        assertRejected(
            2023,
            2,
            29,
            'parameter \'day\' for `2023-02` is invalid, must be in range `1..=28`'
        );
        assertRejected(
            2024,
            2,
            30,
            'parameter \'day\' for `2024-02` is invalid, must be in range `1..=29`'
        );
        assertRejected(
            2024,
            4,
            31,
            'parameter \'day\' for `2024-04` is invalid, must be in range `1..=30`'
        );
        assertRejected(
            -5,
            2,
            30,
            'parameter \'day\' for `-005-02` is invalid, must be in range `1..=28`'
        );
    }

    @IsTest
    static void constrainPullsTheDayBackToTheEndOfTheMonth() {
        Assert.areEqual(JiffDate.newInstance(2024, 2, 29), JiffDate.constrain(2024, 2, 31));
        Assert.areEqual(JiffDate.newInstance(2023, 2, 28), JiffDate.constrain(2023, 2, 31));
        Assert.areEqual(JiffDate.newInstance(2024, 4, 30), JiffDate.constrain(2024, 4, 31));
        Assert.areEqual(JiffDate.newInstance(2024, 1, 31), JiffDate.constrain(2024, 1, 31));
        Assert.areEqual(JiffDate.newInstance(2024, 1, 15), JiffDate.constrain(2024, 1, 15));
        try {
            JiffDate.constrain(2024, 13, 1);
            Assert.fail('expected an invalid month to be rejected');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('month'), e.getMessage());
        }
        try {
            JiffDate.constrain(2024, 1, 0);
            Assert.fail('expected day zero to be rejected');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('day'), e.getMessage());
        }
    }

    @IsTest
    static void knowsLeapYearsAndMonthLengths() {
        for (Integer year : new List<Integer>{ 2024, 2000, 1600, 0, -4, -400 }) {
            Assert.isTrue(JiffDate.isLeapYear(year), year + ' is a leap year');
            Assert.areEqual(29, JiffDate.daysInMonth(year, 2));
        }
        for (Integer year : new List<Integer>{ 2023, 1900, 2100, 1, -1, -100, 9999, -9999 }) {
            Assert.isFalse(JiffDate.isLeapYear(year), year + ' is not a leap year');
            Assert.areEqual(28, JiffDate.daysInMonth(year, 2));
        }
        List<Integer> lengths = new List<Integer>{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
        for (Integer month = 1; month <= 12; month++) {
            Assert.areEqual(lengths.get(month - 1), JiffDate.daysInMonth(2023, month));
        }
    }

    @IsTest
    static void convertsToAndFromEpochDays() {
        Map<Long, JiffDate> known = new Map<Long, JiffDate>{
            0L => JiffDate.newInstance(1970, 1, 1),
            -1L => JiffDate.newInstance(1969, 12, 31),
            19782L => JiffDate.newInstance(2024, 2, 29),
            11017L => JiffDate.newInstance(2000, 3, 1),
            10957L => JiffDate.newInstance(2000, 1, 1),
            -719528L => JiffDate.newInstance(0, 1, 1),
            -719162L => JiffDate.newInstance(1, 1, 1),
            -4371587L => JiffDate.newInstance(-9999, 1, 1),
            2932896L => JiffDate.newInstance(9999, 12, 31)
        };
        for (Long epochDay : known.keySet()) {
            Assert.areEqual(epochDay, known.get(epochDay).toEpochDay());
            Assert.areEqual(known.get(epochDay), JiffDate.fromEpochDay(epochDay));
        }
        Assert.areEqual(JiffDate.MIN, JiffDate.fromEpochDay(-4371587L));
        Assert.areEqual(JiffDate.MAX, JiffDate.fromEpochDay(2932896L));
        for (Long bad : new List<Long>{ -4371588L, 2932897L }) {
            try {
                JiffDate.fromEpochDay(bad);
                Assert.fail('expected an out of range epoch day to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(
                    'parameter \'Unix epoch days\' is not in the required range of -4371587..=2932896',
                    e.getMessage()
                );
            }
        }
    }

    @IsTest
    static void epochDaysRoundTripAcrossTheWholeRange() {
        JiffDate previous = null;
        for (Long epochDay = -4371587L; epochDay <= 2932896L; epochDay += 997) {
            JiffDate d = JiffDate.fromEpochDay(epochDay);
            Assert.areEqual(epochDay, d.toEpochDay(), 'round trip of ' + d);
            // Re-validating through the public constructor proves the fields are a real date.
            Assert.areEqual(d, JiffDate.newInstance(d.year(), d.month(), d.day()));
            if (previous != null) {
                Assert.isTrue(previous.isBefore(d), previous + ' should precede ' + d);
            }
            previous = d;
        }
    }

    @IsTest
    static void consecutiveDaysCrossMonthAndYearBoundariesCorrectly() {
        // Walk day by day through a leap year, a century non-leap year, and across year zero.
        for (Integer startYear : new List<Integer>{ 2024, 1900, 2000, -1 }) {
            Long epochDay = JiffDate.newInstance(startYear, 1, 1).toEpochDay();
            Integer expectedDays = JiffDate.isLeapYear(startYear) ? 366 : 365;
            Integer count = 0;
            for (Integer month = 1; month <= 12; month++) {
                for (Integer day = 1; day <= JiffDate.daysInMonth(startYear, month); day++) {
                    Assert.areEqual(
                        JiffDate.newInstance(startYear, month, day),
                        JiffDate.fromEpochDay(epochDay + count)
                    );
                    count++;
                }
            }
            Assert.areEqual(expectedDays, count);
            Assert.areEqual(
                JiffDate.newInstance(startYear + 1, 1, 1),
                JiffDate.fromEpochDay(epochDay + count)
            );
        }
    }

    @IsTest
    static void computesTheWeekday() {
        Assert.areEqual(JiffWeekday.THURSDAY, JiffDate.newInstance(1970, 1, 1).weekday());
        Assert.areEqual(JiffWeekday.WEDNESDAY, JiffDate.newInstance(1969, 12, 31).weekday());
        Assert.areEqual(JiffWeekday.SATURDAY, JiffDate.newInstance(2000, 1, 1).weekday());
        Assert.areEqual(JiffWeekday.MONDAY, JiffDate.newInstance(2024, 1, 1).weekday());
        Assert.areEqual(JiffWeekday.SUNDAY, JiffDate.newInstance(2024, 3, 10).weekday());
        Assert.areEqual(JiffWeekday.MONDAY, JiffDate.MIN.weekday());
        Assert.areEqual(JiffWeekday.FRIDAY, JiffDate.MAX.weekday());
        Assert.areEqual(JiffWeekday.SATURDAY, JiffDate.ZERO.weekday());
    }

    @IsTest
    static void ordersChronologically() {
        JiffDate a = JiffDate.newInstance(2024, 2, 29);
        Assert.areEqual(0, a.compareTo(JiffDate.newInstance(2024, 2, 29)));
        Assert.areEqual(-1, a.compareTo(JiffDate.newInstance(2024, 3, 1)));
        Assert.areEqual(1, a.compareTo(JiffDate.newInstance(2024, 2, 28)));
        Assert.areEqual(-1, a.compareTo(JiffDate.newInstance(2025, 1, 1)));
        Assert.areEqual(1, a.compareTo(JiffDate.newInstance(2023, 12, 31)));
        Assert.isTrue(JiffDate.MIN.isBefore(JiffDate.MAX));
        Assert.isTrue(JiffDate.MAX.isAfter(JiffDate.MIN));
        Assert.isFalse(a.isBefore(a));
        Assert.isFalse(a.isAfter(a));
        List<JiffDate> dates = new List<JiffDate>{ JiffDate.MAX, a, JiffDate.MIN, JiffDate.ZERO };
        dates.sort();
        Assert.areEqual(JiffDate.MIN, dates.get(0));
        Assert.areEqual(JiffDate.ZERO, dates.get(1));
        Assert.areEqual(a, dates.get(2));
        Assert.areEqual(JiffDate.MAX, dates.get(3));
    }

    @IsTest
    static void equalsAndHashesByValue() {
        JiffDate a = JiffDate.newInstance(2024, 2, 29);
        Assert.isTrue(a.equals(JiffDate.newInstance(2024, 2, 29)));
        Assert.areEqual(a.hashCode(), JiffDate.newInstance(2024, 2, 29).hashCode());
        Assert.isFalse(a.equals(JiffDate.newInstance(2024, 2, 28)));
        Assert.isFalse(a.equals(JiffDate.newInstance(2024, 3, 29)));
        Assert.isFalse(a.equals(JiffDate.newInstance(2023, 2, 28)));
        Assert.isFalse(a.equals('2024-02-29'));
        Map<JiffDate, String> names = new Map<JiffDate, String>{ a => 'leap day' };
        Assert.areEqual('leap day', names.get(JiffDate.newInstance(2024, 2, 29)));
    }

    @IsTest
    static void printsIso8601() {
        Assert.areEqual('2024-03-10', JiffDate.newInstance(2024, 3, 10).toString());
        Assert.areEqual('-002024-03-10', JiffDate.newInstance(-2024, 3, 10).toString());
        Assert.areEqual('0000-01-01', JiffDate.ZERO.toString());
        Assert.areEqual('0001-01-01', JiffDate.newInstance(1, 1, 1).toString());
        Assert.areEqual('-000001-12-31', JiffDate.newInstance(-1, 12, 31).toString());
        Assert.areEqual('-009999-01-01', JiffDate.MIN.toString());
        Assert.areEqual('9999-12-31', JiffDate.MAX.toString());
    }

    private static JiffDate ymd(Integer year, Integer month, Integer day) {
        return JiffDate.newInstance(year, month, day);
    }

    // ---- era ------------------------------------------------------------

    @IsTest
    static void reportsTheYearWithinItsEra() {
        Assert.areEqual(2024, ymd(2024, 10, 3).eraYear());
        Assert.areEqual(JiffEra.CE, ymd(2024, 10, 3).era());
        Assert.areEqual(1, ymd(1, 10, 3).eraYear());
        Assert.areEqual(JiffEra.CE, ymd(1, 10, 3).era());
        Assert.areEqual(1, ymd(0, 10, 3).eraYear());
        Assert.areEqual(JiffEra.BCE, ymd(0, 10, 3).era());
        Assert.areEqual(2, ymd(-1, 10, 3).eraYear());
        Assert.areEqual(JiffEra.BCE, ymd(-1, 10, 3).era());
        Assert.areEqual(11, ymd(-10, 10, 3).eraYear());
        Assert.areEqual(JiffEra.BCE, ymd(-10, 10, 3).era());
        Assert.areEqual(10000, ymd(-9999, 10, 3).eraYear());
        Assert.areEqual(JiffEra.BCE, ymd(-9999, 10, 3).era());
        Assert.areEqual(9999, JiffDate.MAX.eraYear());
        Assert.areEqual(JiffEra.CE, JiffDate.MAX.era());
    }

    // ---- position in the year and month ---------------------------------

    @IsTest
    static void countsTheDayOfTheYear() {
        Assert.areEqual(236, ymd(2006, 8, 24).dayOfYear());
        Assert.areEqual(365, ymd(2023, 12, 31).dayOfYear());
        Assert.areEqual(366, ymd(2024, 12, 31).dayOfYear());
        Assert.areEqual(1, ymd(2024, 1, 1).dayOfYear());
        Assert.areEqual(60, ymd(2024, 2, 29).dayOfYear());
        Assert.areEqual(60, ymd(2023, 3, 1).dayOfYear());
        Assert.areEqual(61, ymd(2024, 3, 1).dayOfYear());
        Assert.areEqual(366, ymd(-4, 12, 31).dayOfYear());
        Assert.areEqual(61, ymd(0, 3, 1).dayOfYear());
        Assert.areEqual(1, JiffDate.MIN.dayOfYear());
        Assert.areEqual(365, JiffDate.MAX.dayOfYear());
        Assert.areEqual(365, ymd(1900, 12, 31).dayOfYear());
        Assert.areEqual(366, ymd(2000, 12, 31).dayOfYear());
    }

    @IsTest
    static void countsTheDayOfTheYearIgnoringLeapDays() {
        Assert.areEqual(236, ymd(2006, 8, 24).dayOfYearNoLeap());
        Assert.areEqual(365, ymd(2023, 12, 31).dayOfYearNoLeap());
        Assert.areEqual(365, ymd(2024, 12, 31).dayOfYearNoLeap());
        Assert.isNull(ymd(2024, 2, 29).dayOfYearNoLeap());
        Assert.areEqual(59, ymd(2024, 2, 28).dayOfYearNoLeap());
        Assert.areEqual(60, ymd(2024, 3, 1).dayOfYearNoLeap());
        Assert.areEqual(60, ymd(2023, 3, 1).dayOfYearNoLeap());
        Assert.areEqual(365, ymd(-4, 12, 31).dayOfYearNoLeap());
        Assert.areEqual(60, ymd(0, 3, 1).dayOfYearNoLeap());
        Assert.isNull(ymd(0, 2, 29).dayOfYearNoLeap());
        Assert.areEqual(1, JiffDate.MIN.dayOfYearNoLeap());
        Assert.areEqual(365, JiffDate.MAX.dayOfYearNoLeap());
        // A caller that needs to test for null assigns the result to a local first.
        Integer leapDay = ymd(2024, 2, 29).dayOfYearNoLeap();
        Assert.isTrue(leapDay == null);
        Integer lastDay = ymd(2024, 12, 31).dayOfYearNoLeap();
        Assert.isTrue(lastDay != null);
        Assert.areEqual(366, lastDay + 1);
    }

    @IsTest
    static void buildsADateFromItsDayOfTheYear() {
        Assert.areEqual(ymd(2024, 2, 29), JiffDate.fromDayOfYear(2024, 60));
        Assert.areEqual(ymd(2023, 3, 1), JiffDate.fromDayOfYear(2023, 60));
        Assert.areEqual(ymd(2024, 12, 31), JiffDate.fromDayOfYear(2024, 366));
        Assert.areEqual(ymd(2024, 3, 1), JiffDate.fromDayOfYearNoLeap(2024, 60));
        Assert.areEqual(ymd(2024, 2, 28), JiffDate.fromDayOfYearNoLeap(2024, 59));
        Assert.areEqual(ymd(2024, 12, 31), JiffDate.fromDayOfYearNoLeap(2024, 365));
        Assert.areEqual(JiffDate.MAX, JiffDate.fromDayOfYear(9999, 365));
        Assert.areEqual(JiffDate.MIN, JiffDate.fromDayOfYearNoLeap(-9999, 1));
        try {
            JiffDate.fromDayOfYear(9999, 366);
            Assert.fail('expected day 366 of a common year to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'number of days for `9999` is invalid, must be in range `1..=365`',
                e.getMessage()
            );
        }
        try {
            JiffDate.fromDayOfYear(10000, 1);
            Assert.fail('expected an out of range year to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'year\' is not in the required range of -9999..=9999',
                e.getMessage()
            );
        }
        try {
            JiffDate.fromDayOfYearNoLeap(2024, 366);
            Assert.fail('expected day 366 to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'day-of-year (skipping Feb 29)\' is not in the required range of 1..=365',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void findsTheEndsOfItsMonthAndYear() {
        Assert.areEqual(ymd(2024, 2, 1), ymd(2024, 2, 29).firstOfMonth());
        Assert.areEqual(ymd(2024, 2, 29), ymd(2024, 2, 5).lastOfMonth());
        Assert.areEqual(ymd(2023, 2, 28), ymd(2023, 2, 5).lastOfMonth());
        Assert.areEqual(ymd(2024, 1, 1), ymd(2024, 2, 29).firstOfYear());
        Assert.areEqual(ymd(2024, 12, 31), ymd(2024, 2, 5).lastOfYear());
        Assert.areEqual(JiffDate.MIN, JiffDate.MIN.firstOfMonth());
        Assert.areEqual(JiffDate.MIN, ymd(-9999, 12, 31).firstOfYear());
        Assert.areEqual(JiffDate.MAX, JiffDate.MAX.lastOfMonth());
        Assert.areEqual(JiffDate.MAX, ymd(9999, 1, 1).lastOfYear());
    }

    @IsTest
    static void firstAndLastOfAgreeForEveryDayOfSampledYears() {
        for (Integer year : new List<Integer>{ -9999, -4, 0, 1900, 2023, 2024, 9999 }) {
            for (Integer month = 1; month <= 12; month++) {
                Integer length = JiffDate.daysInMonth(year, month);
                for (Integer day = 1; day <= length; day += 9) {
                    JiffDate d = ymd(year, month, day);
                    Assert.areEqual(ymd(year, month, 1), d.firstOfMonth());
                    Assert.areEqual(ymd(year, month, length), d.lastOfMonth());
                    Assert.areEqual(ymd(year, 1, 1), d.firstOfYear());
                    Assert.areEqual(ymd(year, 12, 31), d.lastOfYear());
                    Assert.areEqual(length, d.daysInMonth());
                }
            }
        }
    }

    @IsTest
    static void knowsTheLengthOfItsMonthAndYear() {
        Assert.areEqual(29, ymd(2024, 2, 10).daysInMonth());
        Assert.areEqual(28, ymd(2023, 2, 10).daysInMonth());
        Assert.areEqual(31, ymd(2024, 8, 15).daysInMonth());
        Assert.areEqual(30, ymd(2024, 9, 15).daysInMonth());
        Assert.areEqual(366, ymd(2024, 7, 10).daysInYear());
        Assert.areEqual(365, ymd(2023, 7, 10).daysInYear());
        Assert.isTrue(ymd(2024, 1, 1).inLeapYear());
        Assert.isFalse(ymd(2023, 12, 31).inLeapYear());
        for (Integer year : new List<Integer>{ -400, -104, -4, 0, 1904, 2000, 2004, 2024 }) {
            Assert.isTrue(ymd(year, 6, 1).inLeapYear(), year + ' should be a leap year');
            Assert.areEqual(366, ymd(year, 6, 1).daysInYear());
        }
        for (Integer year : new List<Integer>{ -401, -100, -1, 1900, 1999, 2001, 2002, 2003 }) {
            Assert.isFalse(ymd(year, 6, 1).inLeapYear(), year + ' should not be a leap year');
            Assert.areEqual(365, ymd(year, 6, 1).daysInYear());
        }
    }

    @IsTest
    static void weekdaysOfAKnownWeek() {
        Assert.areEqual(JiffWeekday.SATURDAY, ymd(2026, 2, 14).weekday());
        Assert.areEqual(JiffWeekday.SUNDAY, ymd(2026, 2, 15).weekday());
        Assert.areEqual(JiffWeekday.MONDAY, ymd(2026, 2, 16).weekday());
        Assert.areEqual(JiffWeekday.TUESDAY, ymd(2026, 2, 17).weekday());
        Assert.areEqual(JiffWeekday.WEDNESDAY, ymd(2026, 2, 18).weekday());
        Assert.areEqual(JiffWeekday.THURSDAY, ymd(2026, 2, 19).weekday());
        Assert.areEqual(JiffWeekday.FRIDAY, ymd(2026, 2, 20).weekday());
        Assert.areEqual(JiffWeekday.SATURDAY, ymd(2026, 2, 21).weekday());
        // The Unix epoch was on a Thursday, in every numbering scheme.
        JiffWeekday epoch = ymd(1970, 1, 1).weekday();
        Assert.areEqual(3, JiffWeekdays.toMondayZeroOffset(epoch));
        Assert.areEqual(4, JiffWeekdays.toMondayOneOffset(epoch));
        Assert.areEqual(4, JiffWeekdays.toSundayZeroOffset(epoch));
        Assert.areEqual(5, JiffWeekdays.toSundayOneOffset(epoch));
    }

    // ---- tomorrow and yesterday -----------------------------------------

    @IsTest
    static void tomorrowCrossesMonthAndYearBoundaries() {
        Assert.areEqual(ymd(2024, 7, 4), ymd(2024, 7, 3).tomorrow());
        Assert.areEqual(ymd(2024, 7, 1), ymd(2024, 6, 30).tomorrow());
        Assert.areEqual(ymd(2024, 5, 31), ymd(2024, 5, 30).tomorrow());
        Assert.areEqual(ymd(2024, 6, 1), ymd(2024, 5, 31).tomorrow());
        Assert.areEqual(ymd(2024, 2, 29), ymd(2024, 2, 28).tomorrow());
        Assert.areEqual(ymd(2024, 3, 1), ymd(2024, 2, 29).tomorrow());
        Assert.areEqual(ymd(2023, 3, 1), ymd(2023, 2, 28).tomorrow());
        Assert.areEqual(ymd(2024, 1, 1), ymd(2023, 12, 31).tomorrow());
        Assert.areEqual(ymd(-9999, 1, 2), ymd(-9999, 1, 1).tomorrow());
        Assert.areEqual(ymd(9999, 12, 31), ymd(9999, 12, 30).tomorrow());
    }

    @IsTest
    static void theLastDateHasNoTomorrow() {
        try {
            JiffDate.MAX.tomorrow();
            Assert.fail('expected the maximum date to have no tomorrow');
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'year\' is not in the required range of -9999..=9999',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void yesterdayCrossesMonthAndYearBoundaries() {
        Assert.areEqual(ymd(2024, 7, 2), ymd(2024, 7, 3).yesterday());
        Assert.areEqual(ymd(2024, 6, 30), ymd(2024, 7, 1).yesterday());
        Assert.areEqual(ymd(2024, 5, 31), ymd(2024, 6, 1).yesterday());
        Assert.areEqual(ymd(2024, 2, 29), ymd(2024, 3, 1).yesterday());
        Assert.areEqual(ymd(2023, 2, 28), ymd(2023, 3, 1).yesterday());
        Assert.areEqual(ymd(2022, 12, 31), ymd(2023, 1, 1).yesterday());
        Assert.areEqual(ymd(-9999, 1, 1), ymd(-9999, 1, 2).yesterday());
        Assert.areEqual(ymd(9999, 12, 30), ymd(9999, 12, 31).yesterday());
    }

    @IsTest
    static void theFirstDateHasNoYesterday() {
        try {
            JiffDate.MIN.yesterday();
            Assert.fail('expected the minimum date to have no yesterday');
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'year\' is not in the required range of -9999..=9999',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void tomorrowAndYesterdayUndoEachOtherAndFollowEpochDays() {
        for (Long epochDay = -4371586L; epochDay < 2932896L; epochDay += 1777) {
            JiffDate d = JiffDate.fromEpochDay(epochDay);
            Assert.areEqual(JiffDate.fromEpochDay(epochDay + 1), d.tomorrow());
            Assert.areEqual(JiffDate.fromEpochDay(epochDay - 1), d.yesterday());
            Assert.areEqual(d, d.yesterday().tomorrow());
            Assert.areEqual(d, d.tomorrow().yesterday());
        }
    }

    // ---- nth weekday of the month ---------------------------------------

    @IsTest
    static void findsTheNthWeekdayFromTheStartOfTheMonth() {
        Assert.areEqual(ymd(2017, 3, 10), ymd(2017, 3, 1).nthWeekdayOfMonth(2, JiffWeekday.FRIDAY));
        Assert.areEqual(
            ymd(2024, 3, 25),
            ymd(2024, 3, 25).nthWeekdayOfMonth(4, JiffWeekday.MONDAY)
        );
        // A regression case from Jiff: January 1998 has five Saturdays.
        Assert.areEqual(
            ymd(1998, 1, 31),
            ymd(1998, 1, 1).nthWeekdayOfMonth(5, JiffWeekday.SATURDAY)
        );
        Assert.areEqual(ymd(2017, 3, 31), ymd(2017, 3, 1).nthWeekdayOfMonth(5, JiffWeekday.FRIDAY));
        Assert.areEqual(
            ymd(2024, 2, 29),
            ymd(2024, 2, 1).nthWeekdayOfMonth(5, JiffWeekday.THURSDAY)
        );
    }

    @IsTest
    static void findsTheNthWeekdayFromTheEndOfTheMonth() {
        JiffDate march = ymd(2024, 3, 1);
        Assert.areEqual(ymd(2024, 3, 28), march.nthWeekdayOfMonth(-1, JiffWeekday.THURSDAY));
        Assert.areEqual(ymd(2024, 3, 21), march.nthWeekdayOfMonth(-2, JiffWeekday.THURSDAY));
        Assert.areEqual(ymd(2017, 3, 3), ymd(2017, 3, 1).nthWeekdayOfMonth(-5, JiffWeekday.FRIDAY));
    }

    private static void assertNoNthWeekdayOfMonth(
        JiffDate month,
        Integer nth,
        JiffWeekday weekday,
        String expected
    ) {
        try {
            JiffDate found = month.nthWeekdayOfMonth(nth, weekday);
            Assert.fail('expected no such weekday, but found ' + found);
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    @IsTest
    static void aFifthWeekdayThatDoesNotExistIsRejected() {
        // March 2024 has only four Mondays.
        assertNoNthWeekdayOfMonth(
            ymd(2024, 3, 25),
            5,
            JiffWeekday.MONDAY,
            'parameter \'day\' for `2024-03` is invalid, must be in range `1..=31`'
        );
        assertNoNthWeekdayOfMonth(
            ymd(2024, 3, 25),
            -5,
            JiffWeekday.MONDAY,
            'parameter \'day\' is not in the required range of 1..=31'
        );
        assertNoNthWeekdayOfMonth(
            ymd(2024, 2, 1),
            5,
            JiffWeekday.FRIDAY,
            'parameter \'day\' for `2024-02` is invalid, must be in range `1..=29`'
        );
        assertNoNthWeekdayOfMonth(
            ymd(2023, 2, 1),
            -5,
            JiffWeekday.FRIDAY,
            'parameter \'day\' is not in the required range of 1..=31'
        );
        assertNoNthWeekdayOfMonth(
            ymd(2017, 3, 1),
            5,
            JiffWeekday.TUESDAY,
            'parameter \'day\' for `2017-03` is invalid, must be in range `1..=31`'
        );
    }

    @IsTest
    static void nthWeekdayOfMonthRejectsZeroAndCountsBeyondFive() {
        String expected = 'parameter \'nth weekday of month\' is not in the required range of -5..=5';
        JiffDate d = ymd(2017, 3, 1);
        for (Integer nth : new List<Integer>{ 0, 6, -6, 127, -128, 2147483647, -2147483647 }) {
            assertNoNthWeekdayOfMonth(d, nth, JiffWeekday.TUESDAY, expected);
        }
    }

    @IsTest
    static void nthWeekdayOfMonthWorksInTheFirstAndLastSupportedMonths() {
        JiffDate first = ymd(-9999, 1, 1);
        JiffDate last = ymd(9999, 12, 1);
        for (Integer nth = 1; nth <= 5; nth++) {
            // January -9999 starts on a Monday and December 9999 ends on a Friday.
            Assert.areEqual(
                ymd(-9999, 1, 1 + (nth - 1) * 7),
                first.nthWeekdayOfMonth(nth, JiffWeekday.MONDAY)
            );
            Assert.areEqual(
                ymd(-9999, 1, 1 + (nth - 1) * 7),
                first.nthWeekdayOfMonth(nth - 6, JiffWeekday.MONDAY)
            );
            Assert.areEqual(
                ymd(9999, 12, 3 + (nth - 1) * 7),
                last.nthWeekdayOfMonth(nth, JiffWeekday.FRIDAY)
            );
            Assert.areEqual(
                ymd(9999, 12, 3 + (nth - 1) * 7),
                last.nthWeekdayOfMonth(nth - 6, JiffWeekday.FRIDAY)
            );
        }
    }

    @IsTest
    static void everyMonthHasAtLeastFourOfEachWeekday() {
        for (Integer year : new List<Integer>{ -9999, -1, 0, 1900, 2023, 2024, 9999 }) {
            for (Integer month = 1; month <= 12; month++) {
                JiffDate d = ymd(year, month, 1);
                for (JiffWeekday weekday : JiffWeekdays.cycleForward(JiffWeekday.SUNDAY)) {
                    for (Integer nth : new List<Integer>{ -4, -3, -2, -1, 1, 2, 3, 4 }) {
                        JiffDate found = d.nthWeekdayOfMonth(nth, weekday);
                        Assert.areEqual(weekday, found.weekday());
                        Assert.areEqual(month, found.month());
                        Assert.areEqual(year, found.year());
                    }
                }
            }
        }
    }

    // ---- nth weekday from a date ----------------------------------------

    @IsTest
    static void findsTheNthWeekdayAfterADate() {
        // 2024-03-10 is a Sunday.
        JiffDate d = ymd(2024, 3, 10);
        Assert.areEqual(JiffWeekday.SUNDAY, d.weekday());
        // The next Monday is tomorrow.
        Assert.areEqual(ymd(2024, 3, 11), d.nthWeekday(1, JiffWeekday.MONDAY));
        // The next Sunday is a week away, because the date itself does not count.
        Assert.areEqual(ymd(2024, 3, 17), d.nthWeekday(1, JiffWeekday.SUNDAY));
        // "Not this Thursday, but next Thursday."
        Assert.areEqual(ymd(2024, 3, 21), d.nthWeekday(2, JiffWeekday.THURSDAY));
    }

    @IsTest
    static void findsTheNthWeekdayBeforeADate() {
        JiffDate d = ymd(2024, 3, 10);
        // "Last Saturday" was yesterday.
        Assert.areEqual(ymd(2024, 3, 9), d.nthWeekday(-1, JiffWeekday.SATURDAY));
        // "Last Sunday" was a week ago.
        Assert.areEqual(ymd(2024, 3, 3), d.nthWeekday(-1, JiffWeekday.SUNDAY));
        Assert.areEqual(ymd(2024, 3, 4), d.nthWeekday(-1, JiffWeekday.MONDAY));
        // "Not last Thursday, but the one before."
        Assert.areEqual(ymd(2024, 2, 29), d.nthWeekday(-2, JiffWeekday.THURSDAY));
    }

    @IsTest
    static void nthWeekdayCombinesWithNthWeekdayOfMonth() {
        // Israeli summer time starts on the Friday before the last Sunday in March.
        JiffDate lastSunday = ymd(2024, 3, 1).nthWeekdayOfMonth(-1, JiffWeekday.SUNDAY);
        Assert.areEqual(ymd(2024, 3, 29), lastSunday.nthWeekday(-1, JiffWeekday.FRIDAY));
    }

    @IsTest
    static void nthWeekdayFindsTheStartOfTheWeek() {
        JiffDate d = ymd(2024, 3, 15);
        // For weeks starting with Sunday, and then for weeks starting with Monday.
        Assert.areEqual(ymd(2024, 3, 10), d.tomorrow().nthWeekday(-1, JiffWeekday.SUNDAY));
        Assert.areEqual(ymd(2024, 3, 11), d.tomorrow().nthWeekday(-1, JiffWeekday.MONDAY));
        // It works at both ends of the week too.
        Assert.areEqual(
            ymd(2024, 3, 10),
            ymd(2024, 3, 10).tomorrow().nthWeekday(-1, JiffWeekday.SUNDAY)
        );
        Assert.areEqual(
            ymd(2024, 3, 10),
            ymd(2024, 3, 16).tomorrow().nthWeekday(-1, JiffWeekday.SUNDAY)
        );
    }

    private static void assertNoNthWeekday(
        JiffDate start,
        Integer nth,
        JiffWeekday weekday,
        String expected
    ) {
        try {
            JiffDate found = start.nthWeekday(nth, weekday);
            Assert.fail('expected no such weekday, but found ' + found);
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    @IsTest
    static void nthWeekdayStopsAtTheEndsOfTheSupportedRange() {
        String outOfRange = 'parameter \'Unix epoch days\' is not in the required range of -4371587..=2932896';
        Assert.areEqual(JiffDate.MAX, ymd(9999, 12, 24).nthWeekday(1, JiffWeekday.FRIDAY));
        Assert.areEqual(JiffDate.MAX, ymd(9999, 12, 30).nthWeekday(1, JiffWeekday.FRIDAY));
        Assert.areEqual(ymd(9999, 12, 24), JiffDate.MAX.nthWeekday(-1, JiffWeekday.FRIDAY));
        assertNoNthWeekday(JiffDate.MAX, 1, JiffWeekday.FRIDAY, outOfRange);
        assertNoNthWeekday(JiffDate.MAX, 1, JiffWeekday.SATURDAY, outOfRange);

        Assert.areEqual(JiffDate.MIN, ymd(-9999, 1, 8).nthWeekday(-1, JiffWeekday.MONDAY));
        Assert.areEqual(JiffDate.MIN, ymd(-9999, 1, 2).nthWeekday(-1, JiffWeekday.MONDAY));
        Assert.areEqual(ymd(-9999, 1, 8), JiffDate.MIN.nthWeekday(1, JiffWeekday.MONDAY));
        assertNoNthWeekday(JiffDate.MIN, -1, JiffWeekday.MONDAY, outOfRange);
        assertNoNthWeekday(JiffDate.MIN, -1, JiffWeekday.SUNDAY, outOfRange);
    }

    @IsTest
    static void nthWeekdayHandlesTheLargestCounts() {
        String outOfRange = 'parameter \'Unix epoch days\' is not in the required range of -4371587..=2932896';
        String badCount = 'parameter \'nth weekday\' is not in the required range of -1043497..=1043497';
        Integer weeks = 1043497;

        Assert.areEqual(ymd(9999, 12, 27), JiffDate.MIN.nthWeekday(weeks, JiffWeekday.MONDAY));
        assertNoNthWeekday(JiffDate.MIN, weeks + 1, JiffWeekday.MONDAY, badCount);
        assertNoNthWeekday(JiffDate.MIN, 2147483647, JiffWeekday.MONDAY, badCount);
        assertNoNthWeekday(JiffDate.MIN, -2147483647, JiffWeekday.MONDAY, badCount);

        Assert.areEqual(ymd(-9999, 1, 5), JiffDate.MAX.nthWeekday(-weeks, JiffWeekday.FRIDAY));
        assertNoNthWeekday(JiffDate.MAX, weeks - 1, JiffWeekday.FRIDAY, outOfRange);
        assertNoNthWeekday(JiffDate.MAX, -weeks - 1, JiffWeekday.FRIDAY, badCount);

        assertNoNthWeekday(ymd(2024, 3, 10), 0, JiffWeekday.MONDAY, badCount);
    }

    // ---- ISO week dates -------------------------------------------------

    @IsTest
    static void convertsToAnIsoWeekDate() {
        JiffIsoWeekDate weekDate = ymd(1995, 1, 1).toIsoWeekDate();
        Assert.areEqual(1994, weekDate.year());
        Assert.areEqual(52, weekDate.week());
        Assert.areEqual(JiffWeekday.SUNDAY, weekDate.weekday());

        weekDate = ymd(1996, 12, 31).toIsoWeekDate();
        Assert.areEqual(1997, weekDate.year());
        Assert.areEqual(1, weekDate.week());
        Assert.areEqual(JiffWeekday.TUESDAY, weekDate.weekday());

        weekDate = ymd(2019, 12, 30).toIsoWeekDate();
        Assert.areEqual(2020, weekDate.year());
        Assert.areEqual(1, weekDate.week());
        Assert.areEqual(JiffWeekday.MONDAY, weekDate.weekday());

        weekDate = ymd(2024, 3, 9).toIsoWeekDate();
        Assert.areEqual(2024, weekDate.year());
        Assert.areEqual(10, weekDate.week());
        Assert.areEqual(JiffWeekday.SATURDAY, weekDate.weekday());

        weekDate = JiffDate.MIN.toIsoWeekDate();
        Assert.areEqual(-9999, weekDate.year());
        Assert.areEqual(1, weekDate.week());
        Assert.areEqual(JiffWeekday.MONDAY, weekDate.weekday());

        weekDate = JiffDate.MAX.toIsoWeekDate();
        Assert.areEqual(9999, weekDate.year());
        Assert.areEqual(52, weekDate.week());
        Assert.areEqual(JiffWeekday.FRIDAY, weekDate.weekday());
    }

    @IsTest
    static void convertsFromAnIsoWeekDate() {
        Assert.areEqual(
            ymd(1995, 1, 1),
            JiffDate.fromIsoWeekDate(JiffIsoWeekDate.newInstance(1994, 52, JiffWeekday.SUNDAY))
        );
        Assert.areEqual(
            ymd(1996, 12, 31),
            JiffDate.fromIsoWeekDate(JiffIsoWeekDate.newInstance(1997, 1, JiffWeekday.TUESDAY))
        );
        Assert.areEqual(
            ymd(2019, 12, 30),
            JiffDate.fromIsoWeekDate(JiffIsoWeekDate.newInstance(2020, 1, JiffWeekday.MONDAY))
        );
        Assert.areEqual(
            ymd(2024, 3, 9),
            JiffDate.fromIsoWeekDate(JiffIsoWeekDate.newInstance(2024, 10, JiffWeekday.SATURDAY))
        );
        Assert.areEqual(
            ymd(9999, 12, 31),
            JiffDate.fromIsoWeekDate(JiffIsoWeekDate.newInstance(9999, 52, JiffWeekday.FRIDAY))
        );
        Assert.areEqual(JiffDate.MIN, JiffDate.fromIsoWeekDate(JiffIsoWeekDate.MIN));
    }

    // ---- platform Date --------------------------------------------------

    @IsTest
    static void convertsToAndFromAPlatformDate() {
        Date leapDay = Date.newInstance(2024, 2, 29);
        Assert.areEqual(ymd(2024, 2, 29), JiffDate.fromSystemDate(leapDay));
        Assert.areEqual(leapDay, ymd(2024, 2, 29).toSystemDate());
        Date converted = ymd(1970, 1, 1).toSystemDate();
        Assert.areEqual(1970, converted.year());
        Assert.areEqual(1, converted.month());
        Assert.areEqual(1, converted.day());
        Assert.areEqual(Date.newInstance(9999, 12, 31), JiffDate.MAX.toSystemDate());
        Assert.areEqual(JiffDate.MAX, JiffDate.fromSystemDate(Date.newInstance(9999, 12, 31)));
    }

    @IsTest
    static void platformDatesKeepTheirFieldsAcrossTheWholeRange() {
        List<JiffDate> dates = new List<JiffDate>{
            // The days on either side of the platform's switch from the Julian calendar.
            ymd(1582, 10, 4),
            ymd(1582, 10, 15),
            ymd(0, 2, 29),
            ymd(-4, 2, 29),
            ymd(1500, 2, 28),
            ymd(1500, 3, 1)
        };
        for (Long epochDay = -4371587L; epochDay <= 2932896L; epochDay += 9973) {
            dates.add(JiffDate.fromEpochDay(epochDay));
        }
        for (JiffDate d : dates) {
            if (d.year() == 1582 && d.month() == 10 && d.day() > 4 && d.day() < 15) {
                continue;
            }
            Date converted = d.toSystemDate();
            Assert.areEqual(d.year(), converted.year(), 'year of ' + d);
            Assert.areEqual(d.month(), converted.month(), 'month of ' + d);
            Assert.areEqual(d.day(), converted.day(), 'day of ' + d);
            Assert.areEqual(d, JiffDate.fromSystemDate(converted), 'round trip of ' + d);
        }
    }

    @IsTest
    static void theDaysThePlatformCalendarSkipsCannotBeConverted() {
        for (Integer day = 5; day <= 14; day++) {
            try {
                ymd(1582, 10, day).toSystemDate();
                Assert.fail('expected 1582-10-' + day + ' to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(
                    'cannot convert `1582-10-' +
                        String.valueOf(day).leftPad(2, '0') +
                        '` to a system Date: the platform calendar skips from 1582-10-04 to 1582-10-15',
                    e.getMessage()
                );
            }
        }
    }

    @IsTest
    static void aPlatformDateOutsideTheSupportedRangeIsRejected() {
        try {
            JiffDate.fromSystemDate(Date.newInstance(10000, 1, 1));
            Assert.fail('expected year 10000 to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'year\' is not in the required range of -9999..=9999',
                e.getMessage()
            );
        }
        try {
            JiffDate.fromSystemDate(null);
            Assert.fail('expected a missing date to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('the system Date to convert must not be null', e.getMessage());
        }
    }

    // ---- combining with a time ------------------------------------------

    @IsTest
    static void combinesWithATimeIntoADatetime() {
        JiffDate day = ymd(2010, 3, 14);
        JiffTime halfPastTwo = JiffTime.newInstance(2, 30, 0, 0);
        Assert.areEqual(JiffDateTime.fromParts(day, halfPastTwo), day.toDateTime(halfPastTwo));
        Assert.areEqual('2010-03-14T02:30:00', day.toDateTime(halfPastTwo).toString());
        try {
            JiffDateTime unexpected = day.toDateTime(null);
            Assert.fail('expected a missing time to be rejected but got ' + unexpected);
        } catch (JiffException e) {
            Assert.areEqual('a datetime needs both a date and a time', e.getMessage());
        }
    }

    @IsTest
    static void buildsADatetimeAtTheGivenTimeOfDay() {
        Assert.areEqual('2010-03-14T02:30:00', ymd(2010, 3, 14).at(2, 30, 0, 0).toString());
        Assert.areEqual(
            JiffDateTime.newInstance(2024, 2, 29, 15, 22, 45, 123456789),
            ymd(2024, 2, 29).at(15, 22, 45, 123456789)
        );
        // It is the same datetime that `JiffTime.onDate` builds from the other side.
        Assert.areEqual(
            JiffTime.newInstance(2, 30, 0, 0).onDate(2010, 3, 14),
            ymd(2010, 3, 14).at(2, 30, 0, 0)
        );
        try {
            JiffDateTime unexpected = ymd(2010, 3, 14).at(24, 0, 0, 0);
            Assert.fail('expected an invalid hour to be rejected but got ' + unexpected);
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'hour\' is not in the required range of 0..=23',
                e.getMessage()
            );
        }
    }
}
