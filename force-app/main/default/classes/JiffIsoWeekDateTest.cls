@IsTest
private class JiffIsoWeekDateTest {
    private static JiffIsoWeekDate weekDate(Integer year, Integer week, JiffWeekday weekday) {
        return JiffIsoWeekDate.newInstance(year, week, weekday);
    }

    private static void assertRejected(
        Integer year,
        Integer week,
        JiffWeekday weekday,
        String expected
    ) {
        try {
            JiffIsoWeekDate.newInstance(year, week, weekday);
            Assert.fail('expected ' + year + ' W' + week + ' ' + weekday + ' to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    @IsTest
    static void exposesItsComponents() {
        JiffIsoWeekDate wd = weekDate(1948, 53, JiffWeekday.FRIDAY);
        Assert.areEqual(1948, wd.year());
        Assert.areEqual(53, wd.week());
        Assert.areEqual(JiffWeekday.FRIDAY, wd.weekday());
    }

    @IsTest
    static void rejectsWeek53InAYearThatHasOnly52Weeks() {
        String expected = 'parameter \'iso-week\' is not in the required range of 1..=53';
        assertRejected(1949, 53, JiffWeekday.MONDAY, expected);
        assertRejected(2024, 53, JiffWeekday.MONDAY, expected);
        assertRejected(9999, 53, JiffWeekday.MONDAY, expected);
        Assert.areEqual(53, weekDate(2020, 53, JiffWeekday.SUNDAY).week());
        Assert.areEqual(53, weekDate(2026, 53, JiffWeekday.SUNDAY).week());
    }

    @IsTest
    static void rejectsOutOfRangeComponentsWithJiffsWording() {
        assertRejected(
            -10000,
            52,
            JiffWeekday.SUNDAY,
            'parameter \'iso-year\' is not in the required range of -9999..=9999'
        );
        assertRejected(
            10000,
            1,
            JiffWeekday.MONDAY,
            'parameter \'iso-year\' is not in the required range of -9999..=9999'
        );
        assertRejected(
            2024,
            0,
            JiffWeekday.MONDAY,
            'parameter \'iso-week\' is not in the required range of 1..=53'
        );
        assertRejected(
            2024,
            54,
            JiffWeekday.MONDAY,
            'parameter \'iso-week\' is not in the required range of 1..=53'
        );
        assertRejected(2024, 1, null, 'weekday must not be null');
    }

    @IsTest
    static void theRangeEndsWhereTheGregorianRangeEnds() {
        JiffIsoWeekDate max = weekDate(9999, 52, JiffWeekday.FRIDAY);
        Assert.areEqual(JiffIsoWeekDate.MAX, max);
        Assert.areEqual(JiffDate.newInstance(9999, 12, 31), max.toDate());
        String expected = 'parameter \'weekday (Monday 1-indexed)\' is not in the required range of 1..=7';
        assertRejected(9999, 52, JiffWeekday.SATURDAY, expected);
        assertRejected(9999, 52, JiffWeekday.SUNDAY, expected);
        // The same weekdays are fine in any earlier week of that year.
        Assert.areEqual(JiffWeekday.SUNDAY, weekDate(9999, 51, JiffWeekday.SUNDAY).weekday());

        JiffIsoWeekDate min = weekDate(-9999, 1, JiffWeekday.MONDAY);
        Assert.areEqual(JiffIsoWeekDate.MIN, min);
        Assert.areEqual(JiffDate.newInstance(-9999, 1, 1), min.toDate());
    }

    @IsTest
    static void zeroIsTheFirstDayOfWeekYearZero() {
        Assert.areEqual(weekDate(0, 1, JiffWeekday.MONDAY), JiffIsoWeekDate.ZERO);
        // The week calendar's year zero starts on the third day of the Gregorian one.
        Assert.areEqual(JiffDate.newInstance(0, 1, 3), JiffIsoWeekDate.ZERO.toDate());
    }

    @IsTest
    static void convertsFromAGregorianDate() {
        Assert.areEqual(
            weekDate(1948, 7, JiffWeekday.TUESDAY),
            JiffIsoWeekDate.fromDate(JiffDate.newInstance(1948, 2, 10))
        );
        Assert.areEqual(
            weekDate(1994, 52, JiffWeekday.SUNDAY),
            JiffIsoWeekDate.fromDate(JiffDate.newInstance(1995, 1, 1))
        );
        Assert.areEqual(
            weekDate(1997, 1, JiffWeekday.TUESDAY),
            JiffIsoWeekDate.fromDate(JiffDate.newInstance(1996, 12, 31))
        );
        Assert.areEqual(
            weekDate(2020, 1, JiffWeekday.MONDAY),
            JiffIsoWeekDate.fromDate(JiffDate.newInstance(2019, 12, 30))
        );
        Assert.areEqual(
            weekDate(2032, 1, JiffWeekday.MONDAY),
            JiffIsoWeekDate.fromDate(JiffDate.newInstance(2031, 12, 29))
        );
        Assert.areEqual(
            weekDate(2024, 10, JiffWeekday.SATURDAY),
            JiffIsoWeekDate.fromDate(JiffDate.newInstance(2024, 3, 9))
        );
        Assert.areEqual(
            weekDate(1948, 53, JiffWeekday.FRIDAY),
            JiffIsoWeekDate.fromDate(JiffDate.newInstance(1948, 12, 31))
        );
        Assert.areEqual(JiffIsoWeekDate.MIN, JiffIsoWeekDate.fromDate(JiffDate.MIN));
        Assert.areEqual(JiffIsoWeekDate.MAX, JiffIsoWeekDate.fromDate(JiffDate.MAX));
    }

    @IsTest
    static void convertsToAGregorianDate() {
        Assert.areEqual(
            JiffDate.newInstance(1948, 2, 10),
            weekDate(1948, 7, JiffWeekday.TUESDAY).toDate()
        );
        Assert.areEqual(
            JiffDate.newInstance(1995, 1, 1),
            weekDate(1994, 52, JiffWeekday.SUNDAY).toDate()
        );
        Assert.areEqual(
            JiffDate.newInstance(1996, 12, 31),
            weekDate(1997, 1, JiffWeekday.TUESDAY).toDate()
        );
        Assert.areEqual(
            JiffDate.newInstance(2019, 12, 30),
            weekDate(2020, 1, JiffWeekday.MONDAY).toDate()
        );
        Assert.areEqual(
            JiffDate.newInstance(2024, 3, 9),
            weekDate(2024, 10, JiffWeekday.SATURDAY).toDate()
        );
        Assert.areEqual(
            JiffDate.newInstance(2025, 1, 29),
            weekDate(2025, 5, JiffWeekday.WEDNESDAY).toDate()
        );
        Assert.areEqual(
            JiffDate.newInstance(2026, 1, 28),
            weekDate(2026, 5, JiffWeekday.WEDNESDAY).toDate()
        );
        Assert.areEqual(
            JiffDate.newInstance(2024, 6, 16),
            weekDate(2024, 24, JiffWeekday.SUNDAY).toDate()
        );
        Assert.areEqual(
            JiffDate.newInstance(2024, 6, 10),
            weekDate(2024, 24, JiffWeekday.MONDAY).toDate()
        );
    }

    @IsTest
    static void weekYearsDifferFromGregorianYearsAroundNewYear() {
        // Values produced by Jiff 1.0.0 (`Date::iso_week_date` printed with `Display`).
        Map<String, String> expected = new Map<String, String>{
            '2020-12-31' => '2020-W53-4',
            '2021-01-03' => '2020-W53-7',
            '2026-12-31' => '2026-W53-4',
            '2027-01-03' => '2026-W53-7',
            '0000-01-01' => '-000001-W52-6',
            '0000-01-02' => '-000001-W52-7',
            '0000-01-03' => '0000-W01-1',
            '-000001-12-31' => '-000001-W52-5',
            '9999-01-01' => '9998-W53-5',
            '-009999-12-31' => '-009998-W01-1',
            '2000-01-01' => '1999-W52-6',
            '2000-01-02' => '1999-W52-7',
            '2000-01-03' => '2000-W01-1',
            '2010-01-03' => '2009-W53-7',
            '2010-01-04' => '2010-W01-1',
            '2008-12-28' => '2008-W52-7',
            '2008-12-29' => '2009-W01-1',
            '2009-12-31' => '2009-W53-4',
            '2010-01-01' => '2009-W53-5'
        };
        List<JiffDate> dates = new List<JiffDate>{
            JiffDate.newInstance(2020, 12, 31),
            JiffDate.newInstance(2021, 1, 3),
            JiffDate.newInstance(2026, 12, 31),
            JiffDate.newInstance(2027, 1, 3),
            JiffDate.newInstance(0, 1, 1),
            JiffDate.newInstance(0, 1, 2),
            JiffDate.newInstance(0, 1, 3),
            JiffDate.newInstance(-1, 12, 31),
            JiffDate.newInstance(9999, 1, 1),
            JiffDate.newInstance(-9999, 12, 31),
            JiffDate.newInstance(2000, 1, 1),
            JiffDate.newInstance(2000, 1, 2),
            JiffDate.newInstance(2000, 1, 3),
            JiffDate.newInstance(2010, 1, 3),
            JiffDate.newInstance(2010, 1, 4),
            JiffDate.newInstance(2008, 12, 28),
            JiffDate.newInstance(2008, 12, 29),
            JiffDate.newInstance(2009, 12, 31),
            JiffDate.newInstance(2010, 1, 1)
        };
        Assert.areEqual(expected.size(), dates.size());
        for (JiffDate d : dates) {
            JiffIsoWeekDate wd = JiffIsoWeekDate.fromDate(d);
            Assert.areEqual(expected.get(d.toString()), wd.toString(), 'week date of ' + d);
            Assert.areEqual(d, wd.toDate(), 'round trip of ' + d);
        }
    }

    @IsTest
    static void everyDateRoundTripsThroughItsWeekDate() {
        // Jiff checks every date in 2000..=2500 and -9999..=-9500 for a few months. Walking
        // the whole range with a stride that is not a multiple of seven covers every weekday
        // and every kind of year boundary.
        JiffIsoWeekDate previous = null;
        for (Long epochDay = -4371587L; epochDay <= 2932896L; epochDay += 1999) {
            JiffDate d = JiffDate.fromEpochDay(epochDay);
            JiffIsoWeekDate wd = JiffIsoWeekDate.fromDate(d);
            Assert.areEqual(d, wd.toDate(), 'round trip of ' + d);
            Assert.areEqual(d.weekday(), wd.weekday());
            // Re-validating through the public constructor proves the fields are a real week.
            Assert.areEqual(wd, weekDate(wd.year(), wd.week(), wd.weekday()));
            Assert.isTrue(Math.abs(wd.year() - d.year()) <= 1, 'week year of ' + d);
            if (previous != null) {
                Assert.isTrue(previous.isBefore(wd), previous + ' should precede ' + wd);
            }
            previous = wd;
        }
    }

    @IsTest
    static void everyDayAroundNewYearRoundTrips() {
        for (Integer year = 1990; year <= 2040; year++) {
            Long start = JiffDate.newInstance(year, 12, 20).toEpochDay();
            for (Integer offset = 0; offset < 25; offset++) {
                JiffDate d = JiffDate.fromEpochDay(start + offset);
                JiffIsoWeekDate wd = d.toIsoWeekDate();
                Assert.areEqual(d, wd.toDate(), 'round trip of ' + d);
                Assert.areEqual(wd, weekDate(wd.year(), wd.week(), wd.weekday()));
            }
        }
    }

    @IsTest
    static void findsTheFirstAndLastDayOfItsWeek() {
        JiffIsoWeekDate wd = weekDate(2025, 5, JiffWeekday.WEDNESDAY);
        Assert.areEqual(weekDate(2025, 5, JiffWeekday.MONDAY), wd.firstOfWeek());
        Assert.areEqual(weekDate(2025, 5, JiffWeekday.SUNDAY), wd.lastOfWeek());
        Assert.areEqual(weekDate(-9999, 1, JiffWeekday.MONDAY), JiffIsoWeekDate.MIN.firstOfWeek());
        Assert.areEqual(weekDate(9999, 52, JiffWeekday.MONDAY), JiffIsoWeekDate.MAX.firstOfWeek());
        try {
            JiffIsoWeekDate.MAX.lastOfWeek();
            Assert.fail('the last supported week has no Sunday');
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'weekday (Monday 1-indexed)\' is not in the required range of 1..=7',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void findsTheFirstAndLastDayOfItsYear() {
        JiffIsoWeekDate wd = weekDate(2025, 5, JiffWeekday.WEDNESDAY);
        Assert.areEqual(weekDate(2025, 1, JiffWeekday.MONDAY), wd.firstOfYear());
        Assert.areEqual(weekDate(2025, 52, JiffWeekday.SUNDAY), wd.lastOfYear());
        // A long year ends with week 53.
        JiffIsoWeekDate inLongYear = weekDate(2026, 5, JiffWeekday.WEDNESDAY);
        Assert.areEqual(weekDate(2026, 53, JiffWeekday.SUNDAY), inLongYear.lastOfYear());
        Assert.areEqual(weekDate(-9999, 1, JiffWeekday.MONDAY), JiffIsoWeekDate.MIN.firstOfYear());
        Assert.areEqual(weekDate(9999, 1, JiffWeekday.MONDAY), JiffIsoWeekDate.MAX.firstOfYear());
        try {
            JiffIsoWeekDate.MAX.lastOfYear();
            Assert.fail('the last supported year has no final Sunday');
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'weekday (Monday 1-indexed)\' is not in the required range of 1..=7',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void knowsTheLengthOfItsYear() {
        JiffIsoWeekDate shortYear = weekDate(2025, 7, JiffWeekday.MONDAY);
        Assert.areEqual(364, shortYear.daysInYear());
        Assert.areEqual(52, shortYear.weeksInYear());
        Assert.isFalse(shortYear.inLongYear());

        JiffIsoWeekDate longYear = weekDate(2026, 7, JiffWeekday.MONDAY);
        Assert.areEqual(371, longYear.daysInYear());
        Assert.areEqual(53, longYear.weeksInYear());
        Assert.isTrue(longYear.inLongYear());

        Assert.isTrue(weekDate(1948, 7, JiffWeekday.MONDAY).inLongYear());
        Assert.isFalse(weekDate(1949, 7, JiffWeekday.MONDAY).inLongYear());
        Assert.isFalse(JiffIsoWeekDate.MIN.inLongYear());
        Assert.isFalse(JiffIsoWeekDate.MAX.inLongYear());
        Assert.isFalse(JiffIsoWeekDate.ZERO.inLongYear());
        Assert.isTrue(weekDate(-2024, 12, JiffWeekday.SUNDAY).inLongYear());
    }

    @IsTest
    static void longYearsOfThisCenturyMatchJiff() {
        // Produced by Jiff 1.0.0: every year in 2000..=2100 whose week date is in a long year.
        List<Integer> expected = new List<Integer>{
            2004,
            2009,
            2015,
            2020,
            2026,
            2032,
            2037,
            2043,
            2048,
            2054,
            2060,
            2065,
            2071,
            2076,
            2082,
            2088,
            2093,
            2099
        };
        List<Integer> actual = new List<Integer>();
        for (Integer year = 2000; year <= 2100; year++) {
            if (JiffDate.newInstance(year, 6, 1).toIsoWeekDate().inLongYear()) {
                actual.add(year);
            }
        }
        Assert.areEqual(expected, actual);
    }

    @IsTest
    static void leapYearsThatAreAlsoLongYearsInThe20thCentury() {
        // The example from Jiff's documentation of `ISOWeekDate`.
        List<Integer> overlapping = new List<Integer>();
        for (Integer year = 1900; year <= 1999; year++) {
            JiffDate d = JiffDate.newInstance(year, 1, 1);
            if (d.inLeapYear() && d.toIsoWeekDate().inLongYear()) {
                overlapping.add(year);
            }
        }
        Assert.areEqual(
            new List<Integer>{ 1904, 1908, 1920, 1932, 1936, 1948, 1960, 1964, 1976, 1988, 1992 },
            overlapping
        );
    }

    @IsTest
    static void everyLongYearAcceptsA53rdWeek() {
        for (Integer year = -9999; year <= 9998; year += 7) {
            JiffIsoWeekDate wd = weekDate(year, 1, JiffWeekday.MONDAY);
            if (wd.inLongYear()) {
                Assert.areEqual(53, weekDate(year, 53, JiffWeekday.SUNDAY).week());
            } else {
                try {
                    weekDate(year, 53, JiffWeekday.MONDAY);
                    Assert.fail('expected week 53 of ' + year + ' to be rejected');
                } catch (JiffException e) {
                    Assert.isTrue(e.getMessage().contains('iso-week'), e.getMessage());
                }
            }
        }
    }

    @IsTest
    static void tomorrowStepsThroughWeeksAndYears() {
        Assert.areEqual(
            weekDate(2025, 5, JiffWeekday.THURSDAY),
            weekDate(2025, 5, JiffWeekday.WEDNESDAY).tomorrow()
        );
        Assert.areEqual(
            weekDate(2024, 27, JiffWeekday.THURSDAY),
            weekDate(2024, 27, JiffWeekday.WEDNESDAY).tomorrow()
        );
        Assert.areEqual(
            weekDate(2024, 28, JiffWeekday.MONDAY),
            weekDate(2024, 27, JiffWeekday.SUNDAY).tomorrow()
        );
        Assert.areEqual(
            weekDate(2025, 1, JiffWeekday.MONDAY),
            weekDate(2024, 52, JiffWeekday.SUNDAY).tomorrow()
        );
        Assert.areEqual(
            weekDate(2025, 1, JiffWeekday.TUESDAY),
            weekDate(2025, 1, JiffWeekday.MONDAY).tomorrow()
        );
        Assert.areEqual(
            weekDate(2025, 1, JiffWeekday.WEDNESDAY),
            weekDate(2025, 1, JiffWeekday.TUESDAY).tomorrow()
        );
        Assert.areEqual(
            weekDate(2026, 53, JiffWeekday.MONDAY),
            weekDate(2026, 52, JiffWeekday.SUNDAY).tomorrow()
        );
        Assert.areEqual(
            weekDate(2027, 1, JiffWeekday.MONDAY),
            weekDate(2026, 53, JiffWeekday.SUNDAY).tomorrow()
        );
        Assert.areEqual(
            weekDate(-9999, 1, JiffWeekday.TUESDAY),
            weekDate(-9999, 1, JiffWeekday.MONDAY).tomorrow()
        );
        Assert.areEqual(
            weekDate(9999, 52, JiffWeekday.FRIDAY),
            weekDate(9999, 52, JiffWeekday.THURSDAY).tomorrow()
        );
    }

    @IsTest
    static void theLastWeekDateHasNoTomorrow() {
        try {
            JiffIsoWeekDate.MAX.tomorrow();
            Assert.fail('expected the maximum week date to have no tomorrow');
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'iso-year\' is not in the required range of -9999..=9999',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void yesterdayStepsThroughWeeksAndYears() {
        Assert.areEqual(
            weekDate(2025, 5, JiffWeekday.TUESDAY),
            weekDate(2025, 5, JiffWeekday.WEDNESDAY).yesterday()
        );
        Assert.areEqual(
            weekDate(2024, 27, JiffWeekday.WEDNESDAY),
            weekDate(2024, 27, JiffWeekday.THURSDAY).yesterday()
        );
        Assert.areEqual(
            weekDate(2024, 27, JiffWeekday.SUNDAY),
            weekDate(2024, 28, JiffWeekday.MONDAY).yesterday()
        );
        Assert.areEqual(
            weekDate(2024, 52, JiffWeekday.SUNDAY),
            weekDate(2025, 1, JiffWeekday.MONDAY).yesterday()
        );
        Assert.areEqual(
            weekDate(2025, 1, JiffWeekday.MONDAY),
            weekDate(2025, 1, JiffWeekday.TUESDAY).yesterday()
        );
        Assert.areEqual(
            weekDate(2025, 1, JiffWeekday.TUESDAY),
            weekDate(2025, 1, JiffWeekday.WEDNESDAY).yesterday()
        );
        Assert.areEqual(
            weekDate(2026, 52, JiffWeekday.SUNDAY),
            weekDate(2026, 53, JiffWeekday.MONDAY).yesterday()
        );
        Assert.areEqual(
            weekDate(2026, 53, JiffWeekday.SUNDAY),
            weekDate(2027, 1, JiffWeekday.MONDAY).yesterday()
        );
        Assert.areEqual(
            weekDate(9999, 12, JiffWeekday.THURSDAY),
            weekDate(9999, 12, JiffWeekday.FRIDAY).yesterday()
        );
        Assert.areEqual(
            weekDate(-9999, 1, JiffWeekday.MONDAY),
            weekDate(-9999, 1, JiffWeekday.TUESDAY).yesterday()
        );
    }

    @IsTest
    static void theFirstWeekDateHasNoYesterday() {
        try {
            JiffIsoWeekDate.MIN.yesterday();
            Assert.fail('expected the minimum week date to have no yesterday');
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'iso-year\' is not in the required range of -9999..=9999',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void tomorrowAndYesterdayAgreeWithTheGregorianCalendar() {
        for (Long epochDay = -4371586L; epochDay < 2932896L; epochDay += 3331) {
            JiffDate d = JiffDate.fromEpochDay(epochDay);
            JiffIsoWeekDate wd = d.toIsoWeekDate();
            Assert.areEqual(d.tomorrow().toIsoWeekDate(), wd.tomorrow(), 'tomorrow of ' + wd);
            Assert.areEqual(d.yesterday().toIsoWeekDate(), wd.yesterday(), 'yesterday of ' + wd);
            Assert.areEqual(wd, wd.yesterday().tomorrow());
            Assert.areEqual(wd, wd.tomorrow().yesterday());
            Assert.isTrue(wd.yesterday().isBefore(wd));
            Assert.isTrue(wd.tomorrow().isAfter(wd));
        }
    }

    @IsTest
    static void aWholeYearOfTomorrowsVisitsEveryDayOnce() {
        // 2026 is a long year: 53 weeks of 7 days.
        JiffIsoWeekDate wd = weekDate(2026, 1, JiffWeekday.MONDAY);
        JiffDate d = wd.toDate();
        Integer count = 0;
        while (wd.year() == 2026) {
            Assert.areEqual(d, wd.toDate());
            wd = wd.tomorrow();
            d = d.tomorrow();
            count++;
        }
        Assert.areEqual(371, count);
        Assert.areEqual(weekDate(2027, 1, JiffWeekday.MONDAY), wd);
    }

    @IsTest
    static void ordersChronologically() {
        JiffIsoWeekDate a = weekDate(2024, 10, JiffWeekday.WEDNESDAY);
        Assert.areEqual(0, a.compareTo(weekDate(2024, 10, JiffWeekday.WEDNESDAY)));
        Assert.areEqual(-1, a.compareTo(weekDate(2024, 10, JiffWeekday.THURSDAY)));
        Assert.areEqual(1, a.compareTo(weekDate(2024, 10, JiffWeekday.TUESDAY)));
        Assert.areEqual(-1, a.compareTo(weekDate(2024, 11, JiffWeekday.MONDAY)));
        Assert.areEqual(1, a.compareTo(weekDate(2024, 9, JiffWeekday.SUNDAY)));
        Assert.areEqual(-1, a.compareTo(weekDate(2025, 1, JiffWeekday.MONDAY)));
        Assert.areEqual(1, a.compareTo(weekDate(2023, 52, JiffWeekday.SUNDAY)));
        // Sunday is the last day of an ISO week, not the first.
        Assert.isTrue(
            weekDate(2024, 10, JiffWeekday.MONDAY).isBefore(weekDate(2024, 10, JiffWeekday.SUNDAY))
        );
        Assert.isTrue(JiffIsoWeekDate.MIN.isBefore(JiffIsoWeekDate.MAX));
        Assert.isTrue(JiffIsoWeekDate.MAX.isAfter(JiffIsoWeekDate.MIN));
        Assert.isFalse(a.isBefore(a));
        Assert.isFalse(a.isAfter(a));
        List<JiffIsoWeekDate> weekDates = new List<JiffIsoWeekDate>{
            JiffIsoWeekDate.MAX,
            a,
            JiffIsoWeekDate.MIN,
            JiffIsoWeekDate.ZERO
        };
        weekDates.sort();
        Assert.areEqual(JiffIsoWeekDate.MIN, weekDates.get(0));
        Assert.areEqual(JiffIsoWeekDate.ZERO, weekDates.get(1));
        Assert.areEqual(a, weekDates.get(2));
        Assert.areEqual(JiffIsoWeekDate.MAX, weekDates.get(3));
    }

    @IsTest
    static void equalsAndHashesByValue() {
        JiffIsoWeekDate a = weekDate(2024, 10, JiffWeekday.SATURDAY);
        Assert.isTrue(a.equals(weekDate(2024, 10, JiffWeekday.SATURDAY)));
        Assert.areEqual(a.hashCode(), weekDate(2024, 10, JiffWeekday.SATURDAY).hashCode());
        Assert.isFalse(a.equals(weekDate(2024, 10, JiffWeekday.SUNDAY)));
        Assert.isFalse(a.equals(weekDate(2024, 11, JiffWeekday.SATURDAY)));
        Assert.isFalse(a.equals(weekDate(2023, 10, JiffWeekday.SATURDAY)));
        Assert.isFalse(a.equals('2024-W10-6'));
        Assert.isFalse(a.equals(JiffDate.newInstance(2024, 3, 9)));
        Map<JiffIsoWeekDate, String> names = new Map<JiffIsoWeekDate, String>{ a => 'a' };
        Assert.areEqual('a', names.get(weekDate(2024, 10, JiffWeekday.SATURDAY)));
    }

    @IsTest
    static void printsIso8601() {
        Assert.areEqual('2024-W52-1', weekDate(2024, 52, JiffWeekday.MONDAY).toString());
        Assert.areEqual('2004-W01-7', weekDate(2004, 1, JiffWeekday.SUNDAY).toString());
        Assert.areEqual('2024-W24-7', weekDate(2024, 24, JiffWeekday.SUNDAY).toString());
        Assert.areEqual('-009999-W01-1', JiffIsoWeekDate.MIN.toString());
        Assert.areEqual('9999-W52-5', JiffIsoWeekDate.MAX.toString());
        Assert.areEqual('0000-W01-1', JiffIsoWeekDate.ZERO.toString());
        Assert.areEqual('-000001-W05-3', weekDate(-1, 5, JiffWeekday.WEDNESDAY).toString());
        Assert.areEqual('-002024-W12-7', weekDate(-2024, 12, JiffWeekday.SUNDAY).toString());
    }
}
