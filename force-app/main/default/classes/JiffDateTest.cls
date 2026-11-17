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
}
