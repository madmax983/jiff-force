@IsTest
private class JiffSpanRelativeToTest {
    private static JiffDate leapDay() {
        return JiffDate.newInstance(2024, 2, 29);
    }

    @IsTest
    static void aDateMeansItsMidnight() {
        JiffSpanRelativeTo relative = JiffSpanRelativeTo.fromDate(leapDay());
        Assert.areEqual(leapDay().at(0, 0, 0, 0), relative.getDateTime());
        Assert.isNull(relative.getZonedDateTime());
        Assert.isFalse(relative.isDaysAre24Hours());
        Assert.areEqual(JiffSpanRelativeTo.fromDateTime(leapDay().at(0, 0, 0, 0)), relative);
        Assert.areEqual('2024-02-29T00:00:00', relative.toString());
    }

    @IsTest
    static void aDateTimeIsKeptAsGiven() {
        JiffDateTime dt = leapDay().at(12, 30, 0, 0);
        JiffSpanRelativeTo relative = JiffSpanRelativeTo.fromDateTime(dt);
        Assert.areEqual(dt, relative.getDateTime());
        Assert.isNull(relative.getZonedDateTime());
        Assert.isFalse(relative.isDaysAre24Hours());
    }

    @IsTest
    static void aZonedDateTimeIsKeptAsGiven() {
        JiffZonedDateTime zdt = leapDay().inTz('America/New_York');
        JiffSpanRelativeTo relative = JiffSpanRelativeTo.fromZonedDateTime(zdt);
        Assert.areEqual(zdt, relative.getZonedDateTime());
        Assert.isNull(relative.getDateTime());
        Assert.isFalse(relative.isDaysAre24Hours());
        Assert.areEqual(zdt.toString(), relative.toString());
    }

    @IsTest
    static void twentyFourHourDaysHaveNoStartingPoint() {
        JiffSpanRelativeTo relative = JiffSpanRelativeTo.daysAre24Hours();
        Assert.isTrue(relative.isDaysAre24Hours());
        Assert.isNull(relative.getDateTime());
        Assert.isNull(relative.getZonedDateTime());
        Assert.areEqual('days are 24 hours', relative.toString());
    }

    @IsTest
    static void equalityComparesKindAndDatetime() {
        JiffSpanRelativeTo civil = JiffSpanRelativeTo.fromDate(leapDay());
        JiffSpanRelativeTo zoned = JiffSpanRelativeTo.fromZonedDateTime(leapDay().inTz('UTC'));
        JiffSpanRelativeTo marker = JiffSpanRelativeTo.daysAre24Hours();
        Assert.isTrue(civil.equals(JiffSpanRelativeTo.fromDate(leapDay())));
        Assert.isFalse(civil.equals(JiffSpanRelativeTo.fromDate(leapDay().tomorrow())));
        Assert.isTrue(zoned.equals(JiffSpanRelativeTo.fromZonedDateTime(leapDay().inTz('UTC'))));
        Assert.isTrue(marker.equals(JiffSpanRelativeTo.daysAre24Hours()));
        Assert.isFalse(civil.equals(zoned));
        Assert.isFalse(zoned.equals(civil));
        Assert.isFalse(marker.equals(civil));
        Assert.isFalse(civil.equals(marker));
        Assert.isFalse(civil.equals('2024-02-29'));
        Assert.areEqual(civil.hashCode(), JiffSpanRelativeTo.fromDate(leapDay()).hashCode());
        Assert.areEqual(
            zoned.hashCode(),
            JiffSpanRelativeTo.fromZonedDateTime(leapDay().inTz('UTC')).hashCode()
        );
        Assert.areEqual(marker.hashCode(), JiffSpanRelativeTo.daysAre24Hours().hashCode());
    }

    @IsTest
    static void nullStartingPointsAreRejected() {
        List<String> messages = new List<String>();
        try {
            JiffSpanRelativeTo.fromDate(null);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            JiffSpanRelativeTo.fromDateTime(null);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        try {
            JiffSpanRelativeTo.fromZonedDateTime(null);
        } catch (JiffException e) {
            messages.add(e.getMessage());
        }
        Assert.areEqual(
            new List<String>{
                'the date to measure a span from must not be null',
                'the datetime to measure a span from must not be null',
                'the zoned datetime to measure a span from must not be null'
            },
            messages
        );
    }

    @IsTest
    static void unitsOfAFixedLengthNeedNoStartingPoint() {
        for (JiffUnit unit : JiffUnit.values()) {
            JiffSpanRelative resolved = JiffSpanRelativeTo.fromDate(leapDay()).toRelative(unit);
            Assert.areEqual(JiffMath.isCalendar(unit), resolved != null, String.valueOf(unit));
        }
        JiffSpanRelative zoned = JiffSpanRelativeTo.fromZonedDateTime(leapDay().inTz('UTC'))
            .toRelative(JiffUnit.DAY);
        Assert.isTrue(zoned.isZoned());
        Assert.isFalse(JiffSpanRelativeTo.fromDate(leapDay()).toRelative(JiffUnit.DAY).isZoned());
        Assert.isNull(JiffSpanRelativeTo.daysAre24Hours().toRelative(JiffUnit.WEEK));
        Assert.isNull(JiffSpanRelativeTo.daysAre24Hours().toRelative(JiffUnit.DAY));
    }

    @IsTest
    static void twentyFourHourDaysCannotMeasureMonthsOrYears() {
        for (JiffUnit unit : new List<JiffUnit>{ JiffUnit.MONTH, JiffUnit.YEAR }) {
            try {
                JiffSpanRelativeTo.daysAre24Hours().toRelative(unit);
                Assert.fail(unit + ' must be rejected');
            } catch (JiffException e) {
                Assert.areEqual(
                    'using unit \'' +
                        JiffMath.singular(unit) +
                        '\' in span or configuration requires that a relative reference time be given (`JiffSpanRelativeTo.daysAre24Hours()` was given but this only permits using days and weeks without a relative reference time)',
                    e.getMessage()
                );
            }
        }
    }

    @IsTest
    static void aCivilDatetimeAtTheEdgeOfTimeHasNoInstant() {
        // A civil reference is read as UTC to find its instant, and the last supported
        // datetime is beyond the last supported instant.
        try {
            new JiffSpan()
                .days(1)
                .total(JiffUnit.DAY, JiffSpanRelativeTo.fromDateTime(JiffDateTime.MAX));
            Assert.fail('the maximum datetime has no instant in UTC');
        } catch (JiffException e) {
            Assert.areEqual(
                'failed to interpret datetime in UTC in order to convert it to a timestamp: ' +
                    'converting datetime with time zone offset `+00` to timestamp overflowed: ' +
                    'parameter \'Unix timestamp seconds\' is not in the required range of -377705023201..=253402207200',
                e.getMessage()
            );
        }
    }
}
