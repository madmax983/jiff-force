@IsTest
private class JiffTimeTest {
    private static void assertRejected(
        Integer h,
        Integer m,
        Integer s,
        Integer ns,
        String expected
    ) {
        try {
            JiffTime.newInstance(h, m, s, ns);
            Assert.fail('expected the time to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    @IsTest
    static void exposesItsComponents() {
        JiffTime t = JiffTime.newInstance(15, 22, 45, 123456789);
        Assert.areEqual(15, t.hour());
        Assert.areEqual(22, t.minute());
        Assert.areEqual(45, t.second());
        Assert.areEqual(123, t.millisecond());
        Assert.areEqual(456, t.microsecond());
        Assert.areEqual(789, t.nanosecond());
        Assert.areEqual(123456789, t.subsecNanosecond());
        Assert.areEqual(55365, t.toSecondOfDay());
        Assert.areEqual(55365123456789L, t.toNanosecondOfDay());
    }

    @IsTest
    static void rejectsOutOfRangeComponentsWithJiffsWording() {
        assertRejected(24, 0, 0, 0, 'parameter \'hour\' is not in the required range of 0..=23');
        assertRejected(-1, 0, 0, 0, 'parameter \'hour\' is not in the required range of 0..=23');
        assertRejected(0, 60, 0, 0, 'parameter \'minute\' is not in the required range of 0..=59');
        assertRejected(0, -1, 0, 0, 'parameter \'minute\' is not in the required range of 0..=59');
        // There is no leap second: 23:59:60 is not a valid civil time.
        assertRejected(
            23,
            59,
            60,
            0,
            'parameter \'second\' is not in the required range of 0..=59'
        );
        assertRejected(0, 0, -1, 0, 'parameter \'second\' is not in the required range of 0..=59');
        assertRejected(
            0,
            0,
            0,
            1000000000,
            'parameter \'subsecond nanosecond\' is not in the required range of 0..=999999999'
        );
        assertRejected(
            0,
            0,
            0,
            -1,
            'parameter \'subsecond nanosecond\' is not in the required range of 0..=999999999'
        );
    }

    @IsTest
    static void hasNamedBoundaries() {
        Assert.areEqual(JiffTime.newInstance(0, 0, 0, 0), JiffTime.MIN);
        Assert.areEqual(JiffTime.MIN, JiffTime.midnight());
        Assert.areEqual(JiffTime.newInstance(23, 59, 59, 999999999), JiffTime.MAX);
        Assert.areEqual(0L, JiffTime.MIN.toNanosecondOfDay());
        Assert.areEqual(86399999999999L, JiffTime.MAX.toNanosecondOfDay());
    }

    @IsTest
    static void convertsToAndFromNanosecondsSinceMidnight() {
        Assert.areEqual(JiffTime.MIN, JiffTime.fromNanosecondOfDay(0L));
        Assert.areEqual(JiffTime.MAX, JiffTime.fromNanosecondOfDay(86399999999999L));
        Assert.areEqual(JiffTime.newInstance(0, 0, 0, 1), JiffTime.fromNanosecondOfDay(1L));
        Assert.areEqual(
            JiffTime.newInstance(0, 0, 1, 0),
            JiffTime.fromNanosecondOfDay(1000000000L)
        );
        Assert.areEqual(
            JiffTime.newInstance(1, 0, 0, 0),
            JiffTime.fromNanosecondOfDay(3600000000000L)
        );
        Assert.areEqual(
            JiffTime.newInstance(15, 22, 45, 123456789),
            JiffTime.fromNanosecondOfDay(55365123456789L)
        );
        // A prime step visits every hour, minute and second boundary pattern over the day.
        for (Long nanos = 0L; nanos < 86400000000000L; nanos += 86028121000037L / 1000) {
            Assert.areEqual(nanos, JiffTime.fromNanosecondOfDay(nanos).toNanosecondOfDay());
        }
        for (Long bad : new List<Long>{ -1L, 86400000000000L }) {
            try {
                JiffTime.fromNanosecondOfDay(bad);
                Assert.fail('expected an out of range nanosecond to be rejected');
            } catch (JiffException e) {
                Assert.areEqual(
                    'parameter \'nanoseconds (in one civil day)\' is not in the required range of 0..=86399999999999',
                    e.getMessage()
                );
            }
        }
    }

    @IsTest
    static void ordersFromMidnightOnward() {
        JiffTime noon = JiffTime.newInstance(12, 0, 0, 0);
        Assert.areEqual(0, noon.compareTo(JiffTime.newInstance(12, 0, 0, 0)));
        Assert.areEqual(-1, noon.compareTo(JiffTime.newInstance(12, 0, 0, 1)));
        Assert.areEqual(1, noon.compareTo(JiffTime.newInstance(11, 59, 59, 999999999)));
        Assert.isTrue(JiffTime.MIN.isBefore(JiffTime.MAX));
        Assert.isTrue(JiffTime.MAX.isAfter(noon));
        Assert.isFalse(noon.isBefore(noon));
        List<JiffTime> times = new List<JiffTime>{ JiffTime.MAX, noon, JiffTime.MIN };
        times.sort();
        Assert.areEqual(JiffTime.MIN, times.get(0));
        Assert.areEqual(noon, times.get(1));
        Assert.areEqual(JiffTime.MAX, times.get(2));
    }

    @IsTest
    static void equalsAndHashesByValue() {
        JiffTime t = JiffTime.newInstance(15, 22, 45, 5);
        Assert.isTrue(t.equals(JiffTime.newInstance(15, 22, 45, 5)));
        Assert.areEqual(t.hashCode(), JiffTime.newInstance(15, 22, 45, 5).hashCode());
        Assert.isFalse(t.equals(JiffTime.newInstance(15, 22, 45, 6)));
        Assert.isFalse(t.equals('15:22:45.000000005'));
        Map<JiffTime, String> names = new Map<JiffTime, String>{
            JiffTime.midnight() => 'midnight'
        };
        Assert.areEqual('midnight', names.get(JiffTime.newInstance(0, 0, 0, 0)));
    }

    @IsTest
    static void printsIso8601WithOnlyTheFractionItNeeds() {
        Assert.areEqual('00:00:00', JiffTime.MIN.toString());
        Assert.areEqual('15:22:45', JiffTime.newInstance(15, 22, 45, 0).toString());
        Assert.areEqual('15:22:45.5', JiffTime.newInstance(15, 22, 45, 500000000).toString());
        Assert.areEqual('15:22:45.123', JiffTime.newInstance(15, 22, 45, 123000000).toString());
        Assert.areEqual('15:22:45.000001', JiffTime.newInstance(15, 22, 45, 1000).toString());
        Assert.areEqual('05:02:01.000000001', JiffTime.newInstance(5, 2, 1, 1).toString());
        Assert.areEqual('23:59:59.999999999', JiffTime.MAX.toString());
    }
}
