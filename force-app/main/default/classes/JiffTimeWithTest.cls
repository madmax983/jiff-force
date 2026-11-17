/**
 * Expected values are the examples in the doc comments of `jiff::civil::TimeWith` and, for the
 * error cases, the output of Jiff 1.0.0 itself.
 */
@IsTest
private class JiffTimeWithTest {
    private static JiffTime t(Integer h, Integer m, Integer s, Integer ns) {
        return JiffTime.newInstance(h, m, s, ns);
    }

    private static void assertBuildFails(JiffTimeWith builder, String expected) {
        try {
            builder.build();
            Assert.fail('expected the time to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    private static String outOfRange(String field, Integer max) {
        return 'parameter \'' + field + '\' is not in the required range of 0..=' + max;
    }

    private static String conflict(String field) {
        return 'cannot set both `JiffTimeWith.' + field + '` and `JiffTimeWith.subsecNanosecond`';
    }

    @IsTest
    static void setsSeveralFieldsAtOnce() {
        JiffTime t1 = t(0, 0, 24, 0);
        JiffTime t2 = t1.with().hour(15).minute(30).millisecond(10).build();
        Assert.areEqual(t(15, 30, 24, 10000000), t2);
        Assert.areEqual(
            t(1, 2, 3, 4005006),
            t(14, 27, 30, 123456789)
                .with()
                .hour(1)
                .minute(2)
                .second(3)
                .millisecond(4)
                .microsecond(5)
                .nanosecond(6)
                .build()
        );
    }

    @IsTest
    static void buildingWithNothingSetReturnsTheOriginalTime() {
        JiffTime original = t(14, 27, 30, 123456789);
        Assert.areEqual(original, original.with().build());
        Assert.areEqual(original, new JiffTimeWith(original).build());
    }

    @IsTest
    static void setsTheHourMinuteAndSecondIndividually() {
        JiffTime t1 = t(15, 21, 59, 0);
        Assert.areEqual(3, t1.with().hour(3).build().hour());
        Assert.areEqual(t(3, 21, 59, 0), t1.with().hour(3).build());
        Assert.areEqual(3, t1.with().minute(3).build().minute());
        Assert.areEqual(t(15, 3, 59, 0), t1.with().minute(3).build());
        Assert.areEqual(3, t1.with().second(3).build().second());
        Assert.areEqual(t(15, 21, 3, 0), t1.with().second(3).build());
    }

    @IsTest
    static void eachSubsecondSetterReplacesOnlyItsOwnThreeDigits() {
        JiffTime zero = t(15, 21, 35, 0);
        Assert.areEqual(123000000, zero.with().millisecond(123).build().subsecNanosecond());
        Assert.areEqual(987000000, zero.with().millisecond(987).build().subsecNanosecond());
        Assert.areEqual(123000, zero.with().microsecond(123).build().subsecNanosecond());
        Assert.areEqual(123, zero.with().nanosecond(123).build().subsecNanosecond());
        JiffTime full = t(14, 27, 30, 123456789);
        Assert.areEqual(t(14, 27, 30, 1456789), full.with().millisecond(1).build());
        Assert.areEqual(t(14, 27, 30, 123001789), full.with().microsecond(1).build());
        Assert.areEqual(t(14, 27, 30, 123456001), full.with().nanosecond(1).build());
        Assert.areEqual(
            t(23, 59, 59, 999999999),
            t(23, 59, 59, 999999998).with().nanosecond(999).build()
        );
    }

    @IsTest
    static void subsecNanosecondReplacesTheWholeFraction() {
        JiffTime t1 = t(15, 21, 35, 0);
        JiffTime t2 = t1.with().subsecNanosecond(123456789).build();
        Assert.areEqual(123, t2.millisecond());
        Assert.areEqual(456, t2.microsecond());
        Assert.areEqual(789, t2.nanosecond());
        Assert.areEqual(
            t(14, 27, 30, 0),
            t(14, 27, 30, 123456789).with().subsecNanosecond(0).build()
        );
    }

    @IsTest
    static void settingAFieldAgainReplacesTheEarlierValue() {
        Assert.areEqual(
            t(2, 27, 30, 7),
            t(14, 27, 30, 123456789)
                .with()
                .hour(1)
                .hour(2)
                .subsecNanosecond(5)
                .subsecNanosecond(7)
                .build()
        );
    }

    @IsTest
    static void settersLeaveTheBuilderTheyWereCalledOnUnchanged() {
        JiffTime original = t(14, 27, 30, 0);
        JiffTimeWith builder = original.with().minute(1);
        JiffTimeWith other = builder.hour(3).millisecond(5);
        Assert.areEqual(t(14, 1, 30, 0), builder.build());
        Assert.areEqual(t(3, 1, 30, 5000000), other.build());
    }

    @IsTest
    static void rejectsOutOfRangeFieldsWhenBuilding() {
        JiffTime original = t(14, 27, 30, 123456789);
        assertBuildFails(original.with().hour(24), outOfRange('hour', 23));
        assertBuildFails(original.with().hour(-1), outOfRange('hour', 23));
        assertBuildFails(original.with().minute(60), outOfRange('minute', 59));
        assertBuildFails(original.with().second(60), outOfRange('second', 59));
        assertBuildFails(original.with().millisecond(1000), outOfRange('millisecond', 999));
        assertBuildFails(original.with().microsecond(1000), outOfRange('microsecond', 999));
        assertBuildFails(original.with().nanosecond(1000), outOfRange('nanosecond', 999));
        assertBuildFails(original.with().nanosecond(-1), outOfRange('nanosecond', 999));
        assertBuildFails(
            original.with().subsecNanosecond(1000000000),
            outOfRange('subsecond nanosecond', 999999999)
        );
        assertBuildFails(
            original.with().subsecNanosecond(-1),
            outOfRange('subsecond nanosecond', 999999999)
        );
    }

    @IsTest
    static void reportsTheFirstOutOfRangeFieldFromTheHourDown() {
        JiffTime original = t(14, 27, 30, 123456789);
        assertBuildFails(original.with().minute(60).hour(24), outOfRange('hour', 23));
        assertBuildFails(original.with().second(60).minute(60), outOfRange('minute', 59));
        assertBuildFails(
            original.with().second(60).subsecNanosecond(1000000000),
            outOfRange('second', 59)
        );
        assertBuildFails(original.with().minute(60).millisecond(1000), outOfRange('minute', 59));
        assertBuildFails(
            original.with().microsecond(1000).millisecond(1000),
            outOfRange('millisecond', 999)
        );
        assertBuildFails(
            original.with().microsecond(1000).nanosecond(1000),
            outOfRange('microsecond', 999)
        );
    }

    @IsTest
    static void rejectsMixingSubsecNanosecondWithTheIndividualSubsecondFields() {
        JiffTime original = t(14, 27, 30, 123456789);
        assertBuildFails(
            original.with().millisecond(1).subsecNanosecond(0),
            conflict('millisecond')
        );
        assertBuildFails(
            original.with().microsecond(1).subsecNanosecond(0),
            conflict('microsecond')
        );
        assertBuildFails(original.with().nanosecond(1).subsecNanosecond(0), conflict('nanosecond'));
        // The order the setters were called in does not matter.
        assertBuildFails(
            original.with().subsecNanosecond(0).microsecond(1),
            conflict('microsecond')
        );
    }

    @IsTest
    static void reportsAConflictBeforeAnyRangeErrorAndNamesTheLargestField() {
        JiffTime original = t(14, 27, 30, 123456789);
        assertBuildFails(
            original.with().nanosecond(1).microsecond(1).millisecond(1).subsecNanosecond(0),
            conflict('millisecond')
        );
        assertBuildFails(
            original.with().nanosecond(1).microsecond(1).subsecNanosecond(0),
            conflict('microsecond')
        );
        assertBuildFails(
            original.with().hour(24).millisecond(1).subsecNanosecond(0),
            conflict('millisecond')
        );
    }
}
