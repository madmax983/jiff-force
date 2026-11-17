@IsTest
private class JiffDateTimeWithTest {
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

    /** `time(15, 21, 59, 0).on(2010, 6, 1)`, the datetime most of Jiff's time field examples use. */
    private static JiffDateTime juneFirst(Integer second) {
        return JiffTime.newInstance(15, 21, second, 0).onDate(2010, 6, 1);
    }

    private static void assertBuildFails(JiffDateTimeWith builder, String expected) {
        try {
            JiffDateTime unexpected = builder.build();
            Assert.fail('expected the build to fail with "' + expected + '" but got ' + unexpected);
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    // ---- the builder as a whole ------------------------------------------

    @IsTest
    static void fieldsCanBeSetInAnyOrder() {
        JiffDateTime dt1 = civil(2024, 10, 31, 0, 0, 0, 0);
        Assert.areEqual(civil(2024, 11, 30, 0, 0, 0, 0), dt1.with().month(11).day(30).build());
        dt1 = civil(2024, 4, 30, 0, 0, 0, 0);
        Assert.areEqual(civil(2024, 7, 31, 0, 0, 0, 0), dt1.with().day(31).month(7).build());
    }

    @IsTest
    static void withNothingSetItRebuildsTheOriginal() {
        JiffDateTime dt = civil(2005, 11, 5, 15, 30, 0, 0);
        Assert.areEqual(dt, dt.with().build());
        Assert.areEqual(dt, new JiffDateTimeWith(dt).build());
        Assert.areEqual(JiffDateTime.MAX, JiffDateTime.MAX.with().build());
        Assert.areEqual(JiffDateTime.MIN, JiffDateTime.MIN.with().build());
    }

    @IsTest
    static void everyFieldCanBeReplacedAtOnce() {
        JiffDateTime dt = civil(2005, 11, 5, 15, 30, 0, 0);
        Assert.areEqual(
            civil(1999, 2, 3, 4, 5, 6, 7008009),
            dt.with()
                .year(1999)
                .month(2)
                .day(3)
                .hour(4)
                .minute(5)
                .second(6)
                .millisecond(7)
                .microsecond(8)
                .nanosecond(9)
                .build()
        );
    }

    @IsTest
    static void failsWhenTheFieldsDoNotCombineIntoADate() {
        assertBuildFails(
            civil(2024, 11, 30, 15, 30, 0, 0).with().day(31),
            'parameter \'day\' for `2024-11` is invalid, must be in range `1..=30`'
        );
        assertBuildFails(
            civil(2024, 2, 29, 15, 30, 0, 0).with().year(2023),
            'parameter \'day\' for `2023-02` is invalid, must be in range `1..=28`'
        );
    }

    @IsTest
    static void theDateIsCheckedBeforeTheTime() {
        JiffDateTime dt = civil(2005, 11, 5, 15, 30, 0, 0);
        assertBuildFails(
            dt.with().month(13).hour(24),
            'parameter \'month\' is not in the required range of 1..=12'
        );
        assertBuildFails(
            dt.with().hour(24).month(13),
            'parameter \'month\' is not in the required range of 1..=12'
        );
    }

    @IsTest
    static void eachSetterReturnsANewBuilder() {
        JiffDateTime dt = civil(2005, 11, 5, 15, 30, 0, 0);
        JiffDateTimeWith base = dt.with().year(2000);
        JiffDateTimeWith january = base.month(1);
        JiffDateTimeWith noon = base.hour(12);
        Assert.areEqual(civil(2000, 11, 5, 15, 30, 0, 0), base.build());
        Assert.areEqual(civil(2000, 1, 5, 15, 30, 0, 0), january.build());
        Assert.areEqual(civil(2000, 11, 5, 12, 30, 0, 0), noon.build());
    }

    @IsTest
    static void needsADatetimeToStartFrom() {
        try {
            JiffDateTimeWith unexpected = new JiffDateTimeWith(null);
            Assert.fail('expected a missing datetime to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('the datetime to build from must not be null', e.getMessage());
        }
    }

    // ---- withDate and withTime -------------------------------------------

    @IsTest
    static void withDateChangesTheDateAndKeepsTheTime() {
        JiffDateTime dt1 = civil(2005, 11, 5, 15, 30, 0, 0);
        JiffDateTime dt2 = dt1.with().withDate(JiffDate.newInstance(2017, 10, 31)).build();
        Assert.areEqual(civil(2017, 10, 31, 15, 30, 0, 0), dt2);
    }

    @IsTest
    static void withDateOverridesEarlierDateFieldsAndYieldsToLaterOnes() {
        JiffDateTime dt = civil(2005, 11, 5, 15, 30, 0, 0);
        JiffDate halloween = JiffDate.newInstance(2017, 10, 31);
        Assert.areEqual(
            civil(2017, 10, 31, 15, 30, 0, 0),
            dt.with().year(2000).month(1).day(1).withDate(halloween).build()
        );
        Assert.areEqual(
            civil(2000, 10, 31, 15, 30, 0, 0),
            dt.with().withDate(halloween).year(2000).build()
        );
        Assert.areEqual(
            civil(2017, 3, 1, 15, 30, 0, 0),
            dt.with().withDate(halloween).dayOfYear(60).build()
        );
    }

    @IsTest
    static void withTimeChangesTheTimeAndKeepsTheDate() {
        JiffDateTime dt1 = civil(2005, 11, 5, 15, 30, 0, 0);
        JiffDateTime dt2 = dt1.with().withTime(JiffTime.newInstance(23, 59, 59, 123456789)).build();
        Assert.areEqual(civil(2005, 11, 5, 23, 59, 59, 123456789), dt2);
    }

    @IsTest
    static void withTimeOverridesEarlierTimeFieldsAndYieldsToLaterOnes() {
        JiffDateTime dt = civil(2005, 11, 5, 15, 30, 0, 0);
        JiffTime late = JiffTime.newInstance(23, 59, 59, 123456789);
        Assert.areEqual(
            civil(2005, 11, 5, 23, 59, 59, 123456789),
            dt.with().hour(1).subsecNanosecond(5).withTime(late).build()
        );
        Assert.areEqual(
            civil(2005, 11, 5, 1, 59, 59, 123456789),
            dt.with().withTime(late).hour(1).build()
        );
        Assert.areEqual(
            civil(2005, 11, 5, 23, 59, 59, 1456789),
            dt.with().withTime(late).millisecond(1).build()
        );
        // The millisecond set before `withTime` is forgotten, so it does not clash with the
        // whole fraction set after it.
        Assert.areEqual(
            civil(2005, 11, 5, 23, 59, 59, 7),
            dt.with().millisecond(1).withTime(late).subsecNanosecond(7).build()
        );
    }

    @IsTest
    static void withDateAndWithTimeNeedAValue() {
        JiffDateTime dt = civil(2005, 11, 5, 15, 30, 0, 0);
        try {
            JiffDateTimeWith unexpected = dt.with().withDate(null);
            Assert.fail('expected a missing date to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('the date to build from must not be null', e.getMessage());
        }
        try {
            JiffDateTimeWith unexpected = dt.with().withTime(null);
            Assert.fail('expected a missing time to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('the time to build from must not be null', e.getMessage());
        }
    }

    // ---- date fields -----------------------------------------------------

    @IsTest
    static void setsTheYear() {
        JiffDateTime dt1 = civil(2005, 11, 5, 15, 30, 0, 0);
        Assert.areEqual(2005, dt1.year());
        JiffDateTime dt2 = dt1.with().year(2007).build();
        Assert.areEqual(2007, dt2.year());
        Assert.areEqual(civil(2007, 11, 5, 15, 30, 0, 0), dt2);
        // While 2024-02-29T01:30:00 is valid, 2023-02-29T01:30:00 is not.
        assertBuildFails(
            civil(2024, 2, 29, 1, 30, 0, 0).with().year(2023),
            'parameter \'day\' for `2023-02` is invalid, must be in range `1..=28`'
        );
        assertBuildFails(
            dt1.with().year(10000),
            'parameter \'year\' is not in the required range of -9999..=9999'
        );
    }

    @IsTest
    static void setsTheYearOfTheCommonEra() {
        JiffDateTime dt1 = civil(2005, 11, 5, 8, 0, 0, 0);
        Assert.areEqual(2005, dt1.year());
        JiffDateTime dt2 = dt1.with().eraYear(2007, JiffEra.CE).build();
        Assert.areEqual(2007, dt2.year());
        // CE years are always positive and can be at most 9999.
        String range = 'parameter \'CE year\' is not in the required range of 1..=9999';
        assertBuildFails(dt1.with().eraYear(-5, JiffEra.CE), range);
        assertBuildFails(dt1.with().eraYear(10000, JiffEra.CE), range);
    }

    @IsTest
    static void setsTheYearBeforeTheCommonEra() {
        JiffDateTime dt1 = civil(-27, 7, 1, 8, 22, 30, 0);
        Assert.areEqual(-27, dt1.year());
        Assert.areEqual(28, dt1.eraYear());
        Assert.areEqual(JiffEra.BCE, dt1.era());
        JiffDateTime dt2 = dt1.with().eraYear(509, JiffEra.BCE).build();
        Assert.areEqual(-508, dt2.year());
        Assert.areEqual(509, dt2.eraYear());
        Assert.areEqual(JiffEra.BCE, dt2.era());
        dt2 = dt1.with().eraYear(10000, JiffEra.BCE).build();
        Assert.areEqual(-9999, dt2.year());
        Assert.areEqual(10000, dt2.eraYear());
        Assert.areEqual(JiffEra.BCE, dt2.era());
        // BCE years are always positive and can be at most 10000.
        String range = 'parameter \'BCE year\' is not in the required range of 1..=10000';
        assertBuildFails(dt1.with().eraYear(-5, JiffEra.BCE), range);
        assertBuildFails(dt1.with().eraYear(10001, JiffEra.BCE), range);
    }

    @IsTest
    static void theLastOfYearAndEraYearWins() {
        JiffDateTime dt1 = civil(2024, 7, 2, 10, 27, 10, 123);
        Assert.areEqual(
            civil(1900, 7, 2, 10, 27, 10, 123),
            dt1.with().year(2000).eraYear(1900, JiffEra.CE).build()
        );
        dt1 = civil(2024, 7, 2, 19, 0, 1, 1);
        Assert.areEqual(
            civil(2000, 7, 2, 19, 0, 1, 1),
            dt1.with().eraYear(1900, JiffEra.CE).year(2000).build()
        );
    }

    @IsTest
    static void setsTheMonth() {
        JiffDateTime dt1 = civil(2005, 11, 5, 18, 3, 59, 123456789);
        Assert.areEqual(11, dt1.month());
        JiffDateTime dt2 = dt1.with().month(6).build();
        Assert.areEqual(6, dt2.month());
        Assert.areEqual(civil(2005, 6, 5, 18, 3, 59, 123456789), dt2);
        // While 2024-10-31T00:00:00 is valid, 2024-11-31T00:00:00 is not.
        assertBuildFails(
            civil(2024, 10, 31, 0, 0, 0, 0).with().month(11),
            'parameter \'day\' for `2024-11` is invalid, must be in range `1..=30`'
        );
    }

    @IsTest
    static void setsTheDay() {
        JiffDateTime dt1 = civil(2024, 2, 5, 21, 59, 1, 999);
        Assert.areEqual(5, dt1.day());
        Assert.areEqual(10, dt1.with().day(10).build().day());
        Assert.areEqual(29, dt1.with().day(29).build().day());
        Assert.areEqual(civil(2024, 2, 29, 21, 59, 1, 999), dt1.with().day(29).build());
        // 2023 is not a leap year, and September has 30 days.
        assertBuildFails(
            civil(2023, 2, 5, 22, 58, 58, 9999).with().day(29),
            'parameter \'day\' for `2023-02` is invalid, must be in range `1..=28`'
        );
        assertBuildFails(
            civil(2023, 9, 5, 22, 58, 58, 9999).with().day(31),
            'parameter \'day\' for `2023-09` is invalid, must be in range `1..=30`'
        );
    }

    @IsTest
    static void setsTheDayOfTheYear() {
        // Day 60 is February 29th in a leap year and March 1st otherwise.
        Assert.areEqual(
            civil(2024, 2, 29, 23, 59, 59, 999999999),
            civil(2024, 1, 1, 23, 59, 59, 999999999).with().dayOfYear(60).build()
        );
        Assert.areEqual(
            civil(2023, 3, 1, 23, 59, 59, 999999999),
            civil(2023, 1, 1, 23, 59, 59, 999999999).with().dayOfYear(60).build()
        );
        // Day 366 does not exist outside a leap year.
        assertBuildFails(
            civil(2023, 1, 1, 0, 0, 0, 0).with().dayOfYear(366),
            'number of days for `2023` is invalid, must be in range `1..=365`'
        );
        assertBuildFails(
            civil(9999, 1, 1, 0, 0, 0, 0).with().dayOfYear(366),
            'number of days for `9999` is invalid, must be in range `1..=365`'
        );
    }

    @IsTest
    static void setsTheDayOfTheYearIgnoringLeapDays() {
        // Day 60 is March 1st whether or not the year is a leap year.
        Assert.areEqual(
            civil(2023, 3, 1, 23, 59, 59, 999999999),
            civil(2023, 1, 1, 23, 59, 59, 999999999).with().dayOfYearNoLeap(60).build()
        );
        Assert.areEqual(
            civil(2024, 3, 1, 23, 59, 59, 999999999),
            civil(2024, 1, 1, 23, 59, 59, 999999999).with().dayOfYearNoLeap(60).build()
        );
        // And day 365 is always the last day of the year.
        for (Integer year : new List<Integer>{ 2023, 2024, 9999 }) {
            Assert.areEqual(
                civil(year, 12, 31, 23, 59, 59, 999999999),
                civil(year, 1, 1, 23, 59, 59, 999999999).with().dayOfYearNoLeap(365).build()
            );
        }
        assertBuildFails(
            civil(2024, 1, 1, 5, 30, 0, 0).with().dayOfYearNoLeap(366),
            'parameter \'day-of-year (skipping Feb 29)\' is not in the required range of 1..=365'
        );
    }

    @IsTest
    static void buildsTheLastDayOfTheYearAtNoon() {
        Assert.areEqual(
            civil(2023, 12, 31, 12, 0, 0, 0),
            civil(2023, 1, 1, 12, 0, 0, 0).with().dayOfYearNoLeap(365).build()
        );
        Assert.areEqual(
            civil(2024, 12, 31, 12, 0, 0, 0),
            civil(2024, 1, 1, 12, 0, 0, 0).with().dayOfYearNoLeap(365).build()
        );
    }

    // ---- time fields -----------------------------------------------------

    @IsTest
    static void setsTheHour() {
        JiffDateTime dt1 = juneFirst(59);
        Assert.areEqual(15, dt1.hour());
        JiffDateTime dt2 = dt1.with().hour(3).build();
        Assert.areEqual(3, dt2.hour());
        Assert.areEqual(civil(2010, 6, 1, 3, 21, 59, 0), dt2);
        assertBuildFails(
            dt1.with().hour(24),
            'parameter \'hour\' is not in the required range of 0..=23'
        );
    }

    @IsTest
    static void setsTheMinute() {
        JiffDateTime dt1 = juneFirst(59);
        Assert.areEqual(21, dt1.minute());
        JiffDateTime dt2 = dt1.with().minute(3).build();
        Assert.areEqual(3, dt2.minute());
        Assert.areEqual(civil(2010, 6, 1, 15, 3, 59, 0), dt2);
        assertBuildFails(
            dt1.with().minute(60),
            'parameter \'minute\' is not in the required range of 0..=59'
        );
    }

    @IsTest
    static void setsTheSecond() {
        JiffDateTime dt1 = juneFirst(59);
        Assert.areEqual(59, dt1.second());
        JiffDateTime dt2 = dt1.with().second(3).build();
        Assert.areEqual(3, dt2.second());
        Assert.areEqual(civil(2010, 6, 1, 15, 21, 3, 0), dt2);
        assertBuildFails(
            dt1.with().second(60),
            'parameter \'second\' is not in the required range of 0..=59'
        );
    }

    @IsTest
    static void setsTheMillisecond() {
        JiffDateTime dt2 = juneFirst(35).with().millisecond(123).build();
        Assert.areEqual(123000000, dt2.subsecNanosecond());
        assertBuildFails(
            juneFirst(35).with().millisecond(1000),
            'parameter \'millisecond\' is not in the required range of 0..=999'
        );
    }

    @IsTest
    static void setsTheMicrosecond() {
        JiffDateTime dt2 = juneFirst(35).with().microsecond(123).build();
        Assert.areEqual(123000, dt2.subsecNanosecond());
        assertBuildFails(
            juneFirst(35).with().microsecond(1000),
            'parameter \'microsecond\' is not in the required range of 0..=999'
        );
    }

    @IsTest
    static void setsTheNanosecond() {
        JiffDateTime dt2 = juneFirst(35).with().nanosecond(123).build();
        Assert.areEqual(123, dt2.subsecNanosecond());
        assertBuildFails(
            juneFirst(35).with().nanosecond(1000),
            'parameter \'nanosecond\' is not in the required range of 0..=999'
        );
    }

    @IsTest
    static void setsTheWholeFractionalSecond() {
        JiffDateTime dt2 = juneFirst(35).with().subsecNanosecond(123456789).build();
        Assert.areEqual(123, dt2.millisecond());
        Assert.areEqual(456, dt2.microsecond());
        Assert.areEqual(789, dt2.nanosecond());
        assertBuildFails(
            juneFirst(35).with().subsecNanosecond(1000000000),
            'parameter \'subsecond nanosecond\' is not in the required range of 0..=999999999'
        );
    }

    @IsTest
    static void eachPartOfTheFractionLeavesTheOthersAlone() {
        JiffDateTime dt = civil(2010, 6, 1, 15, 21, 35, 987654321);
        Assert.areEqual(
            civil(2010, 6, 1, 15, 21, 35, 123654321),
            dt.with().millisecond(123).build()
        );
        Assert.areEqual(
            civil(2010, 6, 1, 15, 21, 35, 987123321),
            dt.with().microsecond(123).build()
        );
        Assert.areEqual(
            civil(2010, 6, 1, 15, 21, 35, 987654123),
            dt.with().nanosecond(123).build()
        );
    }

    @IsTest
    static void theWholeFractionCannotBeCombinedWithItsParts() {
        // Jiff rejects these too. Its messages name `TimeWith::millisecond` and so on; the
        // port names its own methods.
        JiffDateTime dt = civil(2005, 11, 5, 15, 30, 0, 0);
        assertBuildFails(
            dt.with().millisecond(1).subsecNanosecond(7),
            'cannot set both `JiffTimeWith.millisecond` and `JiffTimeWith.subsecNanosecond`'
        );
        assertBuildFails(
            dt.with().microsecond(1).subsecNanosecond(7),
            'cannot set both `JiffTimeWith.microsecond` and `JiffTimeWith.subsecNanosecond`'
        );
        assertBuildFails(
            dt.with().nanosecond(1).subsecNanosecond(7),
            'cannot set both `JiffTimeWith.nanosecond` and `JiffTimeWith.subsecNanosecond`'
        );
    }
}
