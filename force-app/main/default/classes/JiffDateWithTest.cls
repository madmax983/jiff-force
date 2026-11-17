@IsTest
private class JiffDateWithTest {
    private static JiffDate ymd(Integer year, Integer month, Integer day) {
        return JiffDate.newInstance(year, month, day);
    }

    private static void assertBuildFails(JiffDateWith builder, String expected) {
        try {
            JiffDate built = builder.build();
            Assert.fail('expected the build to fail, but it produced ' + built);
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    @IsTest
    static void buildingWithNothingSetReturnsTheOriginalDate() {
        JiffDate original = ymd(2024, 2, 29);
        Assert.areEqual(original, original.with().build());
        Assert.areEqual(JiffDate.MIN, JiffDate.MIN.with().build());
        Assert.areEqual(JiffDate.MAX, new JiffDateWith(JiffDate.MAX).build());
    }

    @IsTest
    static void fieldsCanBeSetInAnyOrder() {
        Assert.areEqual(ymd(2024, 11, 30), ymd(2024, 10, 31).with().month(11).day(30).build());
        Assert.areEqual(ymd(2024, 7, 31), ymd(2024, 4, 30).with().day(31).month(7).build());
    }

    @IsTest
    static void buildersAreImmutable() {
        JiffDateWith base = ymd(2024, 4, 30).with();
        JiffDateWith inJuly = base.month(7);
        JiffDateWith onTheFirst = base.day(1);
        Assert.areEqual(ymd(2024, 4, 30), base.build());
        Assert.areEqual(ymd(2024, 7, 30), inJuly.build());
        Assert.areEqual(ymd(2024, 4, 1), onTheFirst.build());
    }

    @IsTest
    static void setsTheYear() {
        JiffDate d = ymd(2005, 11, 5).with().year(2007).build();
        Assert.areEqual(ymd(2007, 11, 5), d);
        Assert.areEqual(ymd(-9999, 11, 5), ymd(2005, 11, 5).with().year(-9999).build());
        Assert.areEqual(ymd(9999, 11, 5), ymd(2005, 11, 5).with().year(9999).build());
        // A later call replaces an earlier one.
        Assert.areEqual(ymd(2010, 11, 5), ymd(2005, 11, 5).with().year(2007).year(2010).build());
    }

    @IsTest
    static void changingOnlyTheYearCanFail() {
        assertBuildFails(
            ymd(2024, 2, 29).with().year(2023),
            'parameter \'day\' for `2023-02` is invalid, must be in range `1..=28`'
        );
        assertBuildFails(
            ymd(2024, 2, 29).with().year(10000),
            'parameter \'year\' is not in the required range of -9999..=9999'
        );
        assertBuildFails(
            ymd(2024, 2, 29).with().year(-10000),
            'parameter \'year\' is not in the required range of -9999..=9999'
        );
    }

    @IsTest
    static void setsTheYearThroughTheCommonEra() {
        Assert.areEqual(
            ymd(2007, 11, 5),
            ymd(2005, 11, 5).with().eraYear(2007, JiffEra.CE).build()
        );
        Assert.areEqual(ymd(1, 11, 5), ymd(2005, 11, 5).with().eraYear(1, JiffEra.CE).build());
        Assert.areEqual(
            ymd(9999, 11, 5),
            ymd(2005, 11, 5).with().eraYear(9999, JiffEra.CE).build()
        );
        String expected = 'parameter \'CE year\' is not in the required range of 1..=9999';
        assertBuildFails(ymd(2005, 11, 5).with().eraYear(-5, JiffEra.CE), expected);
        assertBuildFails(ymd(2005, 11, 5).with().eraYear(0, JiffEra.CE), expected);
        assertBuildFails(ymd(2005, 11, 5).with().eraYear(10000, JiffEra.CE), expected);
    }

    @IsTest
    static void setsTheYearThroughTheEraBeforeTheCommonEra() {
        JiffDate d1 = ymd(-27, 7, 1);
        Assert.areEqual(28, d1.eraYear());
        Assert.areEqual(JiffEra.BCE, d1.era());

        JiffDate d2 = d1.with().eraYear(509, JiffEra.BCE).build();
        Assert.areEqual(-508, d2.year());
        Assert.areEqual(509, d2.eraYear());
        Assert.areEqual(JiffEra.BCE, d2.era());

        JiffDate d3 = d1.with().eraYear(10000, JiffEra.BCE).build();
        Assert.areEqual(-9999, d3.year());
        Assert.areEqual(10000, d3.eraYear());
        Assert.areEqual(JiffEra.BCE, d3.era());

        // 1 BCE is year zero, which is a leap year.
        Assert.areEqual(ymd(0, 2, 29), ymd(2024, 2, 29).with().eraYear(1, JiffEra.BCE).build());

        String expected = 'parameter \'BCE year\' is not in the required range of 1..=10000';
        assertBuildFails(d1.with().eraYear(-5, JiffEra.BCE), expected);
        assertBuildFails(d1.with().eraYear(0, JiffEra.BCE), expected);
        assertBuildFails(d1.with().eraYear(10001, JiffEra.BCE), expected);
    }

    @IsTest
    static void yearAndEraYearOverrideEachOther() {
        JiffDate d1 = ymd(2024, 7, 2);
        Assert.areEqual(ymd(1900, 7, 2), d1.with().year(2000).eraYear(1900, JiffEra.CE).build());
        Assert.areEqual(ymd(2000, 7, 2), d1.with().eraYear(1900, JiffEra.CE).year(2000).build());
        // The overridden value is not validated.
        Assert.areEqual(ymd(2000, 7, 2), d1.with().eraYear(0, JiffEra.BCE).year(2000).build());
    }

    @IsTest
    static void eraYearNeedsAnEra() {
        try {
            ymd(2024, 7, 2).with().eraYear(5, null);
            Assert.fail('expected a missing era to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('era must not be null', e.getMessage());
        }
    }

    @IsTest
    static void setsTheMonth() {
        Assert.areEqual(ymd(2005, 6, 5), ymd(2005, 11, 5).with().month(6).build());
        Assert.areEqual(ymd(2005, 6, 5), ymd(2005, 11, 5).with().month(3).month(6).build());
    }

    @IsTest
    static void changingOnlyTheMonthCanFail() {
        assertBuildFails(
            ymd(2024, 10, 31).with().month(11),
            'parameter \'day\' for `2024-11` is invalid, must be in range `1..=30`'
        );
        assertBuildFails(
            ymd(2024, 2, 29).with().month(13),
            'parameter \'month\' is not in the required range of 1..=12'
        );
        assertBuildFails(
            ymd(2024, 2, 29).with().month(0),
            'parameter \'month\' is not in the required range of 1..=12'
        );
    }

    @IsTest
    static void setsTheDay() {
        JiffDate d1 = ymd(2024, 2, 5);
        Assert.areEqual(ymd(2024, 2, 10), d1.with().day(10).build());
        Assert.areEqual(ymd(2024, 2, 29), d1.with().day(29).build());
    }

    @IsTest
    static void changingOnlyTheDayCanFail() {
        // 2023 is not a leap year.
        assertBuildFails(
            ymd(2023, 2, 5).with().day(29),
            'parameter \'day\' for `2023-02` is invalid, must be in range `1..=28`'
        );
        // September has 30 days, not 31.
        assertBuildFails(
            ymd(2023, 9, 5).with().day(31),
            'parameter \'day\' for `2023-09` is invalid, must be in range `1..=30`'
        );
        assertBuildFails(
            ymd(2024, 11, 30).with().day(31),
            'parameter \'day\' for `2024-11` is invalid, must be in range `1..=30`'
        );
        assertBuildFails(
            ymd(2024, 2, 29).with().day(0),
            'parameter \'day\' is not in the required range of 1..=31'
        );
        assertBuildFails(
            ymd(2024, 2, 29).with().day(32),
            'parameter \'day\' is not in the required range of 1..=31'
        );
    }

    @IsTest
    static void setsTheDayOfTheYear() {
        // Day 60 is February 29th in a leap year and March 1st otherwise.
        Assert.areEqual(ymd(2024, 2, 29), ymd(2024, 1, 1).with().dayOfYear(60).build());
        Assert.areEqual(ymd(2023, 3, 1), ymd(2023, 1, 1).with().dayOfYear(60).build());
        Assert.areEqual(ymd(2024, 1, 1), ymd(2024, 8, 24).with().dayOfYear(1).build());
        Assert.areEqual(ymd(2024, 12, 31), ymd(2024, 8, 24).with().dayOfYear(366).build());
        Assert.areEqual(ymd(2023, 12, 31), ymd(2023, 8, 24).with().dayOfYear(365).build());
        Assert.areEqual(ymd(2006, 8, 24), ymd(2006, 1, 1).with().dayOfYear(236).build());
        Assert.areEqual(ymd(9999, 12, 31), ymd(9999, 1, 1).with().dayOfYear(365).build());
        Assert.areEqual(ymd(-9999, 1, 1), ymd(-9999, 6, 6).with().dayOfYear(1).build());
    }

    @IsTest
    static void aDayOfTheYearBeyondTheYearIsRejected() {
        assertBuildFails(
            ymd(2023, 1, 1).with().dayOfYear(366),
            'number of days for `2023` is invalid, must be in range `1..=365`'
        );
        // The maximal year is not a leap year either.
        assertBuildFails(
            ymd(9999, 1, 1).with().dayOfYear(366),
            'number of days for `9999` is invalid, must be in range `1..=365`'
        );
        assertBuildFails(
            ymd(-5, 1, 1).with().dayOfYear(366),
            'number of days for `-005` is invalid, must be in range `1..=365`'
        );
        assertBuildFails(
            ymd(2023, 1, 1).with().dayOfYear(0),
            'parameter \'day-of-year\' is not in the required range of 1..=366'
        );
        assertBuildFails(
            ymd(2024, 1, 1).with().dayOfYear(367),
            'parameter \'day-of-year\' is not in the required range of 1..=366'
        );
    }

    @IsTest
    static void setsTheDayOfTheYearIgnoringLeapDays() {
        // Day 60 is March 1st whether or not the year is a leap year.
        Assert.areEqual(ymd(2023, 3, 1), ymd(2023, 1, 1).with().dayOfYearNoLeap(60).build());
        Assert.areEqual(ymd(2024, 3, 1), ymd(2024, 1, 1).with().dayOfYearNoLeap(60).build());
        Assert.areEqual(ymd(2024, 2, 28), ymd(2024, 1, 1).with().dayOfYearNoLeap(59).build());
        // Day 365 is always the last day of the year.
        Assert.areEqual(ymd(2023, 12, 31), ymd(2023, 1, 1).with().dayOfYearNoLeap(365).build());
        Assert.areEqual(ymd(2024, 12, 31), ymd(2024, 1, 1).with().dayOfYearNoLeap(365).build());
        Assert.areEqual(ymd(9999, 12, 31), ymd(9999, 1, 1).with().dayOfYearNoLeap(365).build());
        Assert.areEqual(ymd(2024, 1, 1), ymd(2024, 5, 5).with().dayOfYearNoLeap(1).build());
    }

    @IsTest
    static void aLeapFreeDayOfTheYearMustBeAtMost365() {
        String expected = 'parameter \'day-of-year (skipping Feb 29)\' is not in the required range of 1..=365';
        // 366 is out of bounds even in a leap year.
        assertBuildFails(ymd(2024, 1, 1).with().dayOfYearNoLeap(366), expected);
        assertBuildFails(ymd(2024, 1, 1).with().dayOfYearNoLeap(0), expected);
    }

    @IsTest
    static void aDayOfTheYearDecidesTheMonth() {
        // The month setting is ignored, though it is still validated.
        Assert.areEqual(ymd(2024, 2, 29), ymd(2024, 1, 1).with().month(7).dayOfYear(60).build());
        Assert.areEqual(
            ymd(2024, 3, 1),
            ymd(2024, 1, 1).with().dayOfYearNoLeap(60).month(7).build()
        );
        assertBuildFails(
            ymd(2024, 1, 1).with().month(13).dayOfYear(60),
            'parameter \'month\' is not in the required range of 1..=12'
        );
    }

    @IsTest
    static void theLastDaySettingWins() {
        Assert.areEqual(ymd(2024, 1, 5), ymd(2024, 1, 1).with().dayOfYear(60).day(5).build());
        Assert.areEqual(ymd(2024, 2, 29), ymd(2024, 1, 1).with().day(5).dayOfYear(60).build());
        Assert.areEqual(
            ymd(2024, 3, 1),
            ymd(2024, 1, 1).with().dayOfYear(5).dayOfYearNoLeap(60).build()
        );
        Assert.areEqual(
            ymd(2024, 2, 29),
            ymd(2024, 1, 1).with().dayOfYearNoLeap(5).dayOfYear(60).build()
        );
    }

    @IsTest
    static void aDayOfTheYearUsesTheYearBeingBuilt() {
        Assert.areEqual(ymd(2023, 3, 1), ymd(2024, 1, 1).with().year(2023).dayOfYear(60).build());
        assertBuildFails(
            ymd(2024, 1, 1).with().year(2023).dayOfYear(366),
            'number of days for `2023` is invalid, must be in range `1..=365`'
        );
        assertBuildFails(
            ymd(2024, 1, 1).with().year(10000).dayOfYear(1),
            'parameter \'year\' is not in the required range of -9999..=9999'
        );
        assertBuildFails(
            ymd(2024, 1, 1).with().year(-10000).dayOfYearNoLeap(1),
            'parameter \'year\' is not in the required range of -9999..=9999'
        );
    }

    @IsTest
    static void everyDayOfTheYearRoundTrips() {
        // Jiff's `day_of_year_in_leap_year` and `day_of_year_in_non_leap_year` tests.
        for (Integer year : new List<Integer>{ 2024, 2026 }) {
            JiffDate jan1 = ymd(year, 1, 1);
            Integer dayOfYear = 1;
            for (Integer month = 1; month <= 12; month++) {
                for (Integer day = 1; day <= JiffDate.daysInMonth(year, month); day++) {
                    JiffDate built = jan1.with().dayOfYear(dayOfYear).build();
                    Assert.areEqual(ymd(year, month, day), built);
                    Assert.areEqual(dayOfYear, built.dayOfYear());
                    dayOfYear++;
                }
            }
            Assert.areEqual(jan1.daysInYear() + 1, dayOfYear);
        }
    }

    @IsTest
    static void everyLeapFreeDayOfTheYearRoundTrips() {
        // Jiff's `day_of_year_no_leap_in_leap_year` and `..._in_non_leap_year` tests.
        for (Integer year : new List<Integer>{ 2024, 2026 }) {
            JiffDate jan1 = ymd(year, 1, 1);
            Integer dayOfYear = 1;
            for (Integer month = 1; month <= 12; month++) {
                for (Integer day = 1; day <= JiffDate.daysInMonth(year, month); day++) {
                    if (month == 2 && day == 29) {
                        continue;
                    }
                    JiffDate built = jan1.with().dayOfYearNoLeap(dayOfYear).build();
                    Assert.areEqual(ymd(year, month, day), built);
                    Assert.areEqual(dayOfYear, built.dayOfYearNoLeap());
                    dayOfYear++;
                }
            }
            Assert.areEqual(366, dayOfYear);
        }
    }

    @IsTest
    static void dayOfYearRoundTripsAcrossTheWholeRange() {
        for (Long epochDay = -4371587L; epochDay <= 2932896L; epochDay += 4999) {
            JiffDate d = JiffDate.fromEpochDay(epochDay);
            Assert.areEqual(d, d.firstOfYear().with().dayOfYear(d.dayOfYear()).build());
            Assert.areEqual(d, JiffDate.fromDayOfYear(d.year(), d.dayOfYear()));
            if (d.month() != 2 || d.day() != 29) {
                Integer noLeap = d.dayOfYearNoLeap();
                Assert.areEqual(d, d.lastOfYear().with().dayOfYearNoLeap(noLeap).build());
                Assert.areEqual(d, JiffDate.fromDayOfYearNoLeap(d.year(), noLeap));
            }
        }
    }

    @IsTest
    static void theBuilderNeedsADateToStartFrom() {
        try {
            JiffDateWith builder = new JiffDateWith(null);
            Assert.fail('expected a missing date to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('the date to build from must not be null', e.getMessage());
        }
    }
}
