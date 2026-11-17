@IsTest
private class JiffDateTimeTest {
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
}
