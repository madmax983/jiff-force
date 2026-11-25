@IsTest
private class JiffDifferenceRoundingTest {
    private static JiffSpan span(String text) {
        return JiffOracleSupport.toSpan(text);
    }

    private static JiffDifference halfExpand() {
        return new JiffDifference().mode(JiffRoundMode.HALF_EXPAND);
    }

    private static JiffZonedDateTime newYork(String civil) {
        return JiffOracleSupport.toDateTime(civil).inTz('America/New_York');
    }

    private static JiffTimestamp utc(String civil) {
        return JiffOracleSupport.toDateTime(civil).inTz('UTC').toTimestamp();
    }

    // ---- vectors from Jiff -------------------------------------------------

    /** The options of a vector row, from its smallest, largest, mode and increment fields. */
    private static JiffDifference options(List<String> f) {
        JiffDifference options = new JiffDifference()
            .smallest(JiffSpanVectorSupport.optionalUnit(f.get(3)))
            .largest(JiffSpanVectorSupport.optionalUnit(f.get(4)));
        if (!f.get(5).equals('-')) {
            options = options.mode(JiffOracleSupport.mode(f.get(5)));
        }
        if (!f.get(6).equals('-')) {
            options = options.increment(Long.valueOf(f.get(6)));
        }
        return options;
    }

    /** `a.until(b, options)` or `a.since(b, options)` for the values of a row of `kind`. */
    private static String difference(
        String kind,
        String a,
        String b,
        JiffDifference options,
        Boolean since
    ) {
        try {
            JiffSpan result;
            if (kind.equals('DATE')) {
                JiffDate x = JiffOracleSupport.toDate(a);
                JiffDate y = JiffOracleSupport.toDate(b);
                result = since ? x.since(y, options) : x.until(y, options);
            } else if (kind.equals('TIME')) {
                JiffTime x = JiffOracleSupport.toTime(a);
                JiffTime y = JiffOracleSupport.toTime(b);
                result = since ? x.since(y, options) : x.until(y, options);
            } else if (kind.equals('DATETIME')) {
                JiffDateTime x = JiffOracleSupport.toDateTime(a);
                JiffDateTime y = JiffOracleSupport.toDateTime(b);
                result = since ? x.since(y, options) : x.until(y, options);
            } else if (kind.equals('TIMESTAMP')) {
                JiffTimestamp x = JiffOracleSupport.toTimestamp(a);
                JiffTimestamp y = JiffOracleSupport.toTimestamp(b);
                result = since ? x.since(y, options) : x.until(y, options);
            } else {
                JiffZonedDateTime x = JiffSpanVectorSupport.zoned(a);
                JiffZonedDateTime y = JiffSpanVectorSupport.zoned(b);
                result = since ? x.since(y, options) : x.until(y, options);
            }
            return JiffOracleSupport.spanText(result);
        } catch (JiffException e) {
            return JiffSpanVectorSupport.failure(e);
        }
    }

    private static void replay(String kind, Integer expectedChecks) {
        JiffSpanVectorSupport vectors = new JiffSpanVectorSupport();
        for (String row : JiffDifferenceVectors.rows()) {
            List<String> f = JiffOracleSupport.fields(row);
            if (!f.get(0).equals(kind)) {
                continue;
            }
            JiffDifference config = options(f);
            vectors.check(
                f.get(7),
                difference(kind, f.get(1), f.get(2), config, false),
                'until',
                row
            );
            vectors.check(
                f.get(8),
                difference(kind, f.get(1), f.get(2), config, true),
                'since',
                row
            );
        }
        vectors.verify(expectedChecks);
    }

    @IsTest
    static void dateDifferencesAgreeWithJiff() {
        replay('DATE', 400);
    }

    @IsTest
    static void timeDifferencesAgreeWithJiff() {
        replay('TIME', 400);
    }

    @IsTest
    static void dateTimeDifferencesAgreeWithJiff() {
        replay('DATETIME', 400);
    }

    @IsTest
    static void timestampDifferencesAgreeWithJiff() {
        replay('TIMESTAMP', 400);
    }

    @IsTest
    static void zonedDifferencesAgreeWithJiff() {
        replay('ZONED', 400);
    }

    // ---- JiffDate, from Jiff's documentation of `DateDifference` -----------

    @IsTest
    static void dateDifferencesRoundToTheNearestYear() {
        JiffDate d1 = JiffDate.newInstance(2024, 3, 15);
        JiffDifference toYears = halfExpand().smallest(JiffUnit.YEAR);
        Assert.areEqual(span('6y'), d1.until(JiffDate.newInstance(2030, 9, 13), toYears));
        // One day more and it rounds up.
        Assert.areEqual(span('7y'), d1.until(JiffDate.newInstance(2030, 9, 14), toYears));
    }

    @IsTest
    static void dateDifferencesInWeeksAndMonths() {
        JiffDate d1 = JiffDate.newInstance(2024, 3, 15);
        JiffDate d2 = JiffDate.newInstance(2030, 11, 22);
        Assert.areEqual(
            span('349w'),
            d1.until(d2, halfExpand().smallest(JiffUnit.WEEK).largest(JiffUnit.WEEK))
        );
        Assert.areEqual(
            span('80mo 7d'),
            d1.until(d2, new JiffDifference().largest(JiffUnit.MONTH))
        );
    }

    @IsTest
    static void dateDifferencesRoundUpWithCeilAndIncrements() {
        JiffDate d1 = JiffDate.newInstance(2024, 1, 15);
        JiffDifference ceilMonths = new JiffDifference()
            .smallest(JiffUnit.MONTH)
            .mode(JiffRoundMode.CEIL);
        Assert.areEqual(span('8mo'), d1.until(JiffDate.newInstance(2024, 8, 16), ceilMonths));
        // Ceil rounds toward positive infinity, so a negative span rounds toward zero.
        Assert.areEqual(span('-7mo'), d1.since(JiffDate.newInstance(2024, 8, 16), ceilMonths));
        JiffDifference twoMonths = halfExpand().smallest(JiffUnit.MONTH).increment(2L);
        Assert.areEqual(span('8mo'), d1.until(JiffDate.newInstance(2024, 8, 15), twoMonths));
        Assert.areEqual(span('6mo'), d1.until(JiffDate.newInstance(2024, 8, 14), twoMonths));
    }

    @IsTest
    static void dateDifferencesRejectTimeUnits() {
        JiffDate d1 = JiffDate.newInstance(2020, 1, 1);
        JiffDate d2 = JiffDate.newInstance(2021, 1, 1);
        for (
            JiffDifference bad : new List<JiffDifference>{
                new JiffDifference().smallest(JiffUnit.HOUR),
                new JiffDifference().largest(JiffUnit.HOUR)
            }
        ) {
            try {
                d1.until(d2, bad);
                Assert.fail('hours must be rejected for dates');
            } catch (JiffException e) {
                Assert.areEqual(
                    '\'hour\' not allowed as a date unit for rounding span',
                    e.getMessage()
                );
            }
        }
        // Without options the difference is in days.
        Assert.areEqual(span('366d'), d1.until(d2, (JiffDifference) null));
        Assert.areEqual(span('-366d'), d1.since(d2, (JiffDifference) null));
    }

    // ---- JiffTime, from Jiff's documentation of `TimeDifference` -----------

    @IsTest
    static void timeDifferencesRoundToHalfHours() {
        JiffTime t1 = JiffTime.newInstance(8, 14, 0, 123456789);
        JiffDifference halfHours = halfExpand().smallest(JiffUnit.MINUTE).increment(30L);
        Assert.areEqual(span('7h'), t1.until(JiffTime.newInstance(15, 0, 0, 0), halfHours));
        Assert.areEqual(span('6h 30m'), t1.until(JiffTime.newInstance(14, 59, 0, 0), halfHours));
        Assert.areEqual(
            span('16m 1s'),
            JiffTime.newInstance(8, 14, 2, 500100000)
                .until(
                    JiffTime.newInstance(8, 30, 3, 100000),
                    halfExpand().smallest(JiffUnit.SECOND)
                )
        );
        Assert.areEqual(
            span('960s'),
            JiffTime.newInstance(8, 14, 0, 0)
                .until(
                    JiffTime.newInstance(8, 30, 0, 0),
                    new JiffDifference().largest(JiffUnit.SECOND)
                )
        );
        Assert.areEqual(
            span('4h 35m'),
            JiffTime.newInstance(8, 19, 0, 0)
                .until(
                    JiffTime.newInstance(12, 52, 0, 0),
                    halfExpand().smallest(JiffUnit.MINUTE).increment(5L)
                )
        );
    }

    @IsTest
    static void timeDifferencesRoundUpWithCeil() {
        JiffTime t1 = JiffTime.newInstance(8, 10, 0, 0);
        JiffTime t2 = JiffTime.newInstance(8, 11, 0, 0);
        JiffDifference ceilHours = new JiffDifference()
            .smallest(JiffUnit.HOUR)
            .mode(JiffRoundMode.CEIL);
        Assert.areEqual(span('1h'), t1.until(t2, ceilHours));
        Assert.areEqual(span('0'), t1.since(t2, ceilHours));
        // The JiffTime doc comment, checked against Jiff.
        Assert.areEqual(
            span('7h 16m'),
            JiffTime.newInstance(8, 14, 2, 500000000)
                .until(JiffTime.newInstance(15, 30, 0, 0), halfExpand().smallest(JiffUnit.MINUTE))
        );
    }

    @IsTest
    static void timeDifferencesRejectCalendarUnits() {
        JiffTime t1 = JiffTime.newInstance(1, 0, 0, 0);
        JiffTime t2 = JiffTime.newInstance(2, 0, 0, 0);
        for (
            JiffDifference bad : new List<JiffDifference>{
                new JiffDifference().smallest(JiffUnit.DAY),
                new JiffDifference().largest(JiffUnit.DAY)
            }
        ) {
            try {
                t1.until(t2, bad);
                Assert.fail('days must be rejected for times');
            } catch (JiffException e) {
                Assert.areEqual(
                    '\'day\' not allowed as a time unit for rounding span',
                    e.getMessage()
                );
            }
        }
        Assert.areEqual(span('1h'), t1.until(t2, (JiffDifference) null));
    }

    // ---- JiffDateTime, from Jiff's documentation of `DateTimeDifference` ----

    @IsTest
    static void dateTimeDifferencesRoundAcrossTheCalendar() {
        JiffDateTime dt1 = JiffOracleSupport.toDateTime('2024-03-15T08:14:00.123456789');
        JiffDateTime dt2 = JiffOracleSupport.toDateTime('2030-03-22T15:00:00');
        Assert.areEqual(
            span('6y 7d 7h'),
            dt1.until(
                dt2,
                halfExpand().smallest(JiffUnit.MINUTE).largest(JiffUnit.YEAR).increment(30L)
            )
        );
        Assert.areEqual(
            span('349w'),
            JiffOracleSupport.toDateTime('2024-03-15T08:14:00')
                .until(
                    JiffOracleSupport.toDateTime('2030-11-22T08:30:00'),
                    halfExpand().smallest(JiffUnit.WEEK).largest(JiffUnit.WEEK)
                )
        );
        // The JiffDateTime doc comment, checked against Jiff.
        Assert.areEqual(
            span('1mo 17d'),
            JiffOracleSupport.toDateTime('2024-03-15T08:00:00')
                .until(
                    JiffOracleSupport.toDateTime('2024-05-01T20:00:00'),
                    halfExpand().largest(JiffUnit.MONTH).smallest(JiffUnit.DAY)
                )
        );
    }

    // ---- JiffTimestamp, from Jiff's documentation of `TimestampDifference` --

    @IsTest
    static void timestampDifferencesRoundInHoursAndSmaller() {
        JiffTimestamp ts1 = utc('2024-03-15T08:14:00.123456789');
        JiffDifference halfHours = halfExpand()
            .smallest(JiffUnit.MINUTE)
            .largest(JiffUnit.HOUR)
            .increment(30L);
        Assert.areEqual(span('175h'), ts1.until(utc('2024-03-22T15:00:00'), halfHours));
        Assert.areEqual(span('174h 30m'), ts1.until(utc('2024-03-22T14:59:00'), halfHours));
        JiffTimestamp finish = utc('2024-03-15T08:16:03.0001');
        JiffDifference seconds = halfExpand().smallest(JiffUnit.SECOND);
        Assert.areEqual(span('121s'), utc('2024-03-15T08:14:02.5001').until(finish, seconds));
        Assert.areEqual(span('120s'), utc('2024-03-15T08:14:02.5002').until(finish, seconds));
        Assert.areEqual(
            span('211076160s'),
            utc('2024-03-15T08:14:00')
                .until(utc('2030-11-22T08:30:00'), new JiffDifference().largest(JiffUnit.SECOND))
        );
        Assert.areEqual(
            'PT275M',
            utc('2024-03-15T08:19:00')
                .until(
                    utc('2024-03-15T12:52:00'),
                    halfExpand().smallest(JiffUnit.MINUTE).increment(5L)
                )
                .toString()
        );
        // The JiffTimestamp doc comment, checked against Jiff.
        Assert.areEqual(
            span('1h 45m'),
            utc('2024-03-15T08:14:00.5')
                .until(
                    utc('2024-03-15T10:00:00'),
                    new JiffDifference().largest(JiffUnit.HOUR).smallest(JiffUnit.MINUTE)
                )
        );
    }

    @IsTest
    static void timestampDifferencesRoundUpWithCeil() {
        JiffTimestamp ts1 = utc('2024-03-15T08:10:00');
        JiffTimestamp ts2 = utc('2024-03-15T08:11:00');
        JiffDifference ceilHours = new JiffDifference()
            .smallest(JiffUnit.HOUR)
            .mode(JiffRoundMode.CEIL);
        Assert.areEqual(span('1h'), ts1.until(ts2, ceilHours));
        Assert.areEqual(span('0'), ts1.since(ts2, ceilHours));
    }

    @IsTest
    static void timestampDifferencesRejectDaysAndBadIncrements() {
        JiffTimestamp ts1 = JiffTimestamp.UNIX_EPOCH;
        JiffTimestamp ts2 = JiffTimestamp.newInstance(100000L, 0);
        Map<String, JiffDifference> failures = new Map<String, JiffDifference>{
            'rounding to \'days\' is not supported' => new JiffDifference().smallest(JiffUnit.DAY),
            'failed rounding span: increment for rounding to \'hours\' must divide into `24` evenly' => new JiffDifference()
                .smallest(JiffUnit.HOUR)
                .increment(5L),
            'largest unit (\'minute\') cannot be smaller than smallest unit (\'hour\')' => new JiffDifference()
                .smallest(JiffUnit.HOUR)
                .largest(JiffUnit.MINUTE)
        };
        for (String message : failures.keySet()) {
            try {
                ts1.until(ts2, failures.get(message));
                Assert.fail('expected: ' + message);
            } catch (JiffException e) {
                Assert.areEqual(message, e.getMessage());
            }
        }
        Assert.areEqual(span('100000s'), ts1.until(ts2, (JiffDifference) null));
    }

    // ---- JiffZonedDateTime, from Jiff's documentation of `ZonedDateTimeDifference`

    @IsTest
    static void zonedDifferencesRoundAcrossTheCalendar() {
        Assert.areEqual(
            span('6y 7d 7h'),
            newYork('2024-03-15T08:14:00.123456789')
                .until(
                    newYork('2030-03-22T15:00:00'),
                    halfExpand().smallest(JiffUnit.MINUTE).largest(JiffUnit.YEAR).increment(30L)
                )
        );
        JiffZonedDateTime zdt1 = newYork('2024-03-15T08:14:00');
        JiffZonedDateTime zdt2 = newYork('2030-11-22T08:30:00');
        Assert.areEqual(
            span('349w'),
            zdt1.until(zdt2, halfExpand().smallest(JiffUnit.WEEK).largest(JiffUnit.WEEK))
        );
        Assert.areEqual(
            'PT211079760S',
            zdt1.until(zdt2, new JiffDifference().largest(JiffUnit.SECOND)).toString()
        );
        Assert.areEqual(
            span('4h 35m'),
            newYork('2024-03-15T08:19:00')
                .until(
                    newYork('2024-03-15T12:52:00'),
                    halfExpand().smallest(JiffUnit.MINUTE).increment(5L)
                )
        );
    }

    @IsTest
    static void zonedDifferencesRoundUpWithCeil() {
        JiffZonedDateTime zdt1 = newYork('2024-03-15T08:10:00');
        JiffZonedDateTime zdt2 = newYork('2024-03-15T08:11:00');
        JiffDifference ceilHours = new JiffDifference()
            .smallest(JiffUnit.HOUR)
            .mode(JiffRoundMode.CEIL);
        Assert.areEqual(span('1h'), zdt1.until(zdt2, ceilHours));
        Assert.areEqual(span('0'), zdt1.since(zdt2, ceilHours));
    }

    @IsTest
    static void zonedDaysAreAsLongAsTheyReallyAre() {
        // The JiffZonedDateTime doc comment, checked against Jiff: 2024-03-10 is 23 hours long
        // in New York, so 22.5 hours of it rounds to a whole day.
        JiffZonedDateTime zdt1 = newYork('2024-03-10T00:00:00');
        JiffZonedDateTime zdt2 = newYork('2024-03-10T23:30:00');
        Assert.areEqual(span('22h 30m'), zdt1.until(zdt2, (JiffDifference) null));
        Assert.areEqual(span('1d'), zdt1.until(zdt2, halfExpand().smallest(JiffUnit.DAY)));
        Assert.areEqual(
            span('1d'),
            newYork('2024-03-09T12:00:00')
                .until(newYork('2024-03-10T12:00:00'), new JiffDifference().largest(JiffUnit.DAY))
        );
    }

    @IsTest
    static void zonedDifferencesInDaysNeedOneTimeZone() {
        try {
            newYork('2024-03-09T12:00:00')
                .until(
                    JiffOracleSupport.toDateTime('2024-03-11T01:00:00').inTz('Europe/Paris'),
                    new JiffDifference().largest(JiffUnit.DAY)
                );
            Assert.fail('days between two time zones must be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'computing the span between zoned datetimes, with day units, requires that the time zones are equivalent, but the zoned datetimes have distinct time zones',
                e.getMessage()
            );
        }
    }
}
