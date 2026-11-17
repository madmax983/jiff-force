/**
 * `JiffZonedDateTime.with()` and the `JiffZonedDateTimeWith` builder.
 *
 * Expected values are from the examples in Jiff's documentation of `ZonedDateTimeWith`, from
 * the tests in `jiff/src/zoned.rs`, or were printed by Jiff 1.0.0 itself.
 */
@IsTest
private class JiffZonedDateTimeWithTest {
    private static final String NEW_YORK = 'America/New_York';
    private static final String GAP_IN_NEW_YORK =
        'error converting datetime to instant in time zone America/New_York: datetime is ' +
        'ambiguous since it falls into a gap between offsets -05 and -04';
    private static final String FOLD_IN_NEW_YORK =
        'error converting datetime to instant in time zone America/New_York: datetime is ' +
        'ambiguous since it falls into a fold between offsets -04 and -05';

    private static JiffZonedDateTime zoned(String text) {
        return JiffZonedTestSupport.zoned(text);
    }

    private static JiffZonedDateTime newYork(
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        Integer minute,
        Integer second,
        Integer subsecNanosecond
    ) {
        return JiffDate.newInstance(year, month, day)
            .at(hour, minute, second, subsecNanosecond)
            .inTz(NEW_YORK);
    }

    private static void assertBuildFails(JiffZonedDateTimeWith builder, String expected) {
        try {
            JiffZonedDateTime built = builder.build();
            Assert.fail('expected build() to fail, but it gave ' + built);
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    private static void assertBuildFails(JiffZonedDateTimeWith builder) {
        try {
            JiffZonedDateTime built = builder.build();
            Assert.fail('expected build() to fail, but it gave ' + built);
        } catch (JiffException e) {
            Assert.isNotNull(e.getMessage());
        }
    }

    // ---- civil fields ---------------------------------------------------

    @IsTest
    static void fieldsCanBeSetInAnyOrder() {
        JiffZonedDateTime zdt1 = newYork(2024, 10, 31, 0, 0, 0, 0);
        Assert.areEqual(newYork(2024, 11, 30, 0, 0, 0, 0), zdt1.with().month(11).day(30).build());
        zdt1 = newYork(2024, 4, 30, 0, 0, 0, 0);
        Assert.areEqual(newYork(2024, 7, 31, 0, 0, 0, 0), zdt1.with().day(31).month(7).build());
    }

    @IsTest
    static void nothingSetGivesTheOriginalBack() {
        for (
            String text : new List<String>{
                '2024-03-11T02:05:00-04:00[America/New_York]',
                // Both readings of a repeated time survive, because the offset is kept.
                '2024-11-03T01:30:00-04:00[America/New_York]',
                '2024-11-03T01:30:00-05:00[America/New_York]',
                '2024-07-04T12:00:00+00:00[UTC]',
                '2024-07-04T12:00:00-05:30[-05:30]'
            }
        ) {
            Assert.areEqual(text, zoned(text).with().build().toString());
        }
    }

    @IsTest
    static void anInvalidCivilDatetimeFailsAtBuild() {
        assertBuildFails(newYork(2024, 11, 30, 15, 30, 0, 0).with().day(31));
        assertBuildFails(newYork(2024, 2, 29, 15, 30, 0, 0).with().year(2023));
        assertBuildFails(newYork(2024, 10, 31, 0, 0, 0, 0).with().month(11));
        // 2023 is not a leap year, and September has 30 days, not 31.
        assertBuildFails(newYork(2023, 2, 5, 22, 58, 58, 9999).with().day(29));
        assertBuildFails(JiffDate.newInstance(2023, 9, 5).inTz(NEW_YORK).with().day(31));
    }

    @IsTest
    static void replacesTheDateOrTheTime() {
        JiffZonedDateTime zdt1 = newYork(2005, 11, 5, 15, 30, 0, 0);
        // The date changes but the time remains the same.
        Assert.areEqual(
            newYork(2017, 10, 31, 15, 30, 0, 0),
            zdt1.with().withDate(JiffDate.newInstance(2017, 10, 31)).build()
        );
        // The time changes but the date remains the same.
        Assert.areEqual(
            newYork(2005, 11, 5, 23, 59, 59, 123456789),
            zdt1.with().withTime(JiffTime.newInstance(23, 59, 59, 123456789)).build()
        );
        Assert.areEqual(
            '2017-10-31T23:59:59.123456789+05:30[Asia/Kolkata]',
            zoned('2024-07-04T12:00:00+05:30[Asia/Kolkata]')
                .with()
                .withDate(JiffDate.newInstance(2017, 10, 31))
                .withTime(JiffTime.newInstance(23, 59, 59, 123456789))
                .build()
                .toString()
        );
    }

    @IsTest
    static void setsTheYear() {
        JiffZonedDateTime zdt1 = newYork(2005, 11, 5, 15, 30, 0, 0);
        Assert.areEqual(2005, zdt1.year());
        Assert.areEqual(2007, zdt1.with().year(2007).build().year());
    }

    @IsTest
    static void setsTheYearByEra() {
        JiffZonedDateTime zdt1 = newYork(2005, 11, 5, 8, 0, 0, 0);
        Assert.areEqual(2007, zdt1.with().eraYear(2007, JiffEra.CE).build().year());
        // CE years are always positive and can be at most 9999.
        assertBuildFails(zdt1.with().eraYear(-5, JiffEra.CE));
        assertBuildFails(zdt1.with().eraYear(10000, JiffEra.CE));

        // BCE years, in a fixed zone so that ancient time zone data plays no part.
        JiffZonedDateTime ancient = JiffDate.newInstance(-27, 7, 1)
            .at(8, 22, 30, 0)
            .toZonedDateTime(JiffTimeZone.fixed(JiffOffset.fromHours(1)));
        Assert.areEqual(-27, ancient.year());
        Assert.areEqual(28, ancient.eraYear());
        Assert.areEqual(JiffEra.BCE, ancient.era());
        JiffZonedDateTime zdt2 = ancient.with().eraYear(509, JiffEra.BCE).build();
        Assert.areEqual(-508, zdt2.year());
        Assert.areEqual(509, zdt2.eraYear());
        Assert.areEqual(JiffEra.BCE, zdt2.era());
        zdt2 = ancient.with().eraYear(10000, JiffEra.BCE).build();
        Assert.areEqual(-9999, zdt2.year());
        Assert.areEqual(10000, zdt2.eraYear());
        // BCE years are always positive and can be at most 10000.
        assertBuildFails(ancient.with().eraYear(-5, JiffEra.BCE));
        assertBuildFails(ancient.with().eraYear(10001, JiffEra.BCE));
    }

    @IsTest
    static void theLastOfYearAndEraYearWins() {
        JiffZonedDateTime zdt1 = newYork(2024, 7, 2, 10, 27, 10, 123);
        Assert.areEqual(
            newYork(1900, 7, 2, 10, 27, 10, 123),
            zdt1.with().year(2000).eraYear(1900, JiffEra.CE).build()
        );
        zdt1 = newYork(2024, 7, 2, 19, 0, 1, 1);
        Assert.areEqual(
            newYork(2000, 7, 2, 19, 0, 1, 1),
            zdt1.with().eraYear(1900, JiffEra.CE).year(2000).build()
        );
    }

    @IsTest
    static void setsTheMonthAndTheDay() {
        JiffZonedDateTime zdt1 = newYork(2005, 11, 5, 18, 3, 59, 123456789);
        Assert.areEqual(11, zdt1.month());
        Assert.areEqual(6, zdt1.with().month(6).build().month());

        zdt1 = newYork(2024, 2, 5, 21, 59, 1, 999);
        Assert.areEqual(5, zdt1.day());
        Assert.areEqual(10, zdt1.with().day(10).build().day());
        Assert.areEqual(29, zdt1.with().day(29).build().day());
    }

    @IsTest
    static void setsTheDayOfTheYear() {
        // In a leap year, day 60 is February 29.
        Assert.areEqual(
            newYork(2024, 2, 29, 23, 59, 59, 999999999),
            newYork(2024, 1, 1, 23, 59, 59, 999999999).with().dayOfYear(60).build()
        );
        // But for non-leap years, day 60 is March 1.
        Assert.areEqual(
            newYork(2023, 3, 1, 23, 59, 59, 999999999),
            newYork(2023, 1, 1, 23, 59, 59, 999999999).with().dayOfYear(60).build()
        );
        // Day 366 is only valid in a leap year, and the maximal year is not one.
        assertBuildFails(newYork(2023, 1, 1, 0, 0, 0, 0).with().dayOfYear(366));
        assertBuildFails(
            JiffDate.newInstance(9999, 1, 1).toZonedDateTime(JiffTimeZone.UTC).with().dayOfYear(366)
        );
    }

    @IsTest
    static void setsTheDayOfTheYearIgnoringLeapDays() {
        // Day 60 is always March 1.
        Assert.areEqual(
            newYork(2023, 3, 1, 23, 59, 59, 999999999),
            newYork(2023, 1, 1, 23, 59, 59, 999999999).with().dayOfYearNoLeap(60).build()
        );
        Assert.areEqual(
            newYork(2024, 3, 1, 23, 59, 59, 999999999),
            newYork(2024, 1, 1, 23, 59, 59, 999999999).with().dayOfYearNoLeap(60).build()
        );
        // And day 365 is always the last day of the year.
        Assert.areEqual(
            newYork(2023, 12, 31, 12, 0, 0, 0),
            newYork(2023, 1, 1, 12, 0, 0, 0).with().dayOfYearNoLeap(365).build()
        );
        JiffZonedDateTime zdt = newYork(2024, 1, 1, 23, 59, 59, 999999999);
        Assert.areEqual(zdt.lastOfYear(), zdt.with().dayOfYearNoLeap(365).build());
        Assert.areEqual(
            newYork(2024, 12, 31, 12, 0, 0, 0),
            newYork(2024, 1, 1, 12, 0, 0, 0).with().dayOfYearNoLeap(365).build()
        );
        // 366 is never valid.
        assertBuildFails(newYork(2024, 1, 1, 5, 30, 0, 0).with().dayOfYearNoLeap(366));
    }

    @IsTest
    static void theLastDayOfTheLastYearDependsOnTheZone() {
        // Careful at the boundaries. The last day of the year isn't representable in all time
        // zones: 9999-12-31T23:59:59.999999999 is past the last instant unless the zone is far
        // enough ahead of UTC.
        JiffZonedDateTime behind = JiffDate.newInstance(9999, 1, 1)
            .at(23, 59, 59, 999999999)
            .toZonedDateTime(JiffTimeZone.fixed(JiffOffset.fromHours(-5)));
        assertBuildFails(behind.with().dayOfYearNoLeap(365));
        JiffZonedDateTime ahead = JiffDate.newInstance(9999, 1, 1)
            .at(23, 59, 59, 999999999)
            .toZonedDateTime(JiffTimeZone.fixed(JiffOffset.MAX));
        Assert.areEqual(ahead.lastOfYear(), ahead.with().dayOfYearNoLeap(365).build());
    }

    @IsTest
    static void setsTheClockFields() {
        JiffZonedDateTime zdt1 = newYork(2010, 6, 1, 15, 21, 59, 0);
        Assert.areEqual(3, zdt1.with().hour(3).build().hour());
        Assert.areEqual(3, zdt1.with().minute(3).build().minute());
        Assert.areEqual(3, zdt1.with().second(3).build().second());

        zdt1 = newYork(2010, 6, 1, 15, 21, 35, 0);
        Assert.areEqual(123000000, zdt1.with().millisecond(123).build().subsecNanosecond());
        Assert.areEqual(123000, zdt1.with().microsecond(123).build().subsecNanosecond());
        Assert.areEqual(123, zdt1.with().nanosecond(123).build().subsecNanosecond());
        JiffZonedDateTime zdt2 = zdt1.with().subsecNanosecond(123456789).build();
        Assert.areEqual(123, zdt2.millisecond());
        Assert.areEqual(456, zdt2.microsecond());
        Assert.areEqual(789, zdt2.nanosecond());
    }

    @IsTest
    static void setsEveryFieldAtOnce() {
        JiffZonedDateTime zdt = zoned('2024-07-04T12:00:00+05:30[Asia/Kolkata]');
        Assert.areEqual(
            '2000-02-29T23:59:58.000000001+05:30[Asia/Kolkata]',
            zdt.with()
                .year(2000)
                .month(2)
                .day(29)
                .hour(23)
                .minute(59)
                .second(58)
                .subsecNanosecond(1)
                .build()
                .toString()
        );
        assertBuildFails(zdt.with().month(2).day(30));
        assertBuildFails(zdt.with().millisecond(1).subsecNanosecond(1));
    }

    /** Calls the civil field setter number `which` with null and returns the complaint. */
    private static String complaintAboutNull(Integer which) {
        JiffZonedDateTimeWith builder = JiffZonedDateTime.UNIX_EPOCH.with();
        Integer missing = null;
        try {
            switch on which {
                when 0 {
                    builder.year(missing);
                }
                when 1 {
                    builder.eraYear(missing, JiffEra.CE);
                }
                when 2 {
                    builder.month(missing);
                }
                when 3 {
                    builder.day(missing);
                }
                when 4 {
                    builder.dayOfYear(missing);
                }
                when 5 {
                    builder.dayOfYearNoLeap(missing);
                }
                when 6 {
                    builder.hour(missing);
                }
                when 7 {
                    builder.minute(missing);
                }
                when 8 {
                    builder.second(missing);
                }
                when 9 {
                    builder.millisecond(missing);
                }
                when 10 {
                    builder.microsecond(missing);
                }
                when 11 {
                    builder.nanosecond(missing);
                }
                when else {
                    builder.subsecNanosecond(missing);
                }
            }
        } catch (JiffException e) {
            return e.getMessage();
        }
        return 'accepted';
    }

    @IsTest
    static void civilFieldSettersRejectNull() {
        List<String> fields = new List<String>{
            'year',
            'eraYear',
            'month',
            'day',
            'dayOfYear',
            'dayOfYearNoLeap',
            'hour',
            'minute',
            'second',
            'millisecond',
            'microsecond',
            'nanosecond',
            'subsecNanosecond'
        };
        for (Integer i = 0; i < fields.size(); i++) {
            Assert.areEqual(fields.get(i) + ' must not be null', complaintAboutNull(i));
        }
    }

    @IsTest
    static void theOtherSettersRejectNullToo() {
        JiffZonedDateTimeWith builder = JiffZonedDateTime.UNIX_EPOCH.with();
        List<String> rejected = new List<String>();
        try {
            builder.offset(null);
        } catch (JiffException e) {
            rejected.add(e.getMessage());
        }
        try {
            builder.offsetConflict(null);
        } catch (JiffException e) {
            rejected.add(e.getMessage());
        }
        try {
            builder.disambiguation(null);
        } catch (JiffException e) {
            rejected.add(e.getMessage());
        }
        try {
            builder.withTime(null);
        } catch (JiffException e) {
            rejected.add(e.getMessage());
        }
        try {
            new JiffZonedDateTimeWith(null);
        } catch (JiffException e) {
            rejected.add(e.getMessage());
        }
        Assert.areEqual(
            new List<String>{
                'offset must not be null',
                'offset conflict strategy must not be null',
                'disambiguation strategy must not be null',
                'the time to build from must not be null',
                'the zoned datetime to build from must not be null'
            },
            rejected
        );
    }

    // ---- offset, offset conflict and disambiguation -----------------------

    @IsTest
    static void theOffsetCanBeChangedInAFold() {
        JiffZonedDateTime zdt1 = zoned('2024-11-03T01:30:00-04:00[America/New_York]');
        Assert.areEqual(
            // Everything stays the same, except for the offset.
            '2024-11-03T01:30:00-05:00[America/New_York]',
            zdt1.with().offset(JiffOffset.fromHours(-5)).build().toString()
        );
        // If we use an invalid offset for the America/New_York time zone, then it will be
        // ignored and the disambiguation strategy set will be used.
        Assert.areEqual(
            // The default disambiguation is Compatible.
            '2024-11-03T01:30:00-04:00[America/New_York]',
            zdt1.with().offset(JiffOffset.fromHours(-12)).build().toString()
        );
        Assert.areEqual(
            '2024-11-03T01:30:00-05:00[America/New_York]',
            zdt1.with()
                .offset(JiffOffset.fromHours(-12))
                .disambiguation(JiffDisambiguation.LATER)
                .build()
                .toString()
        );
        // But we could change the disambiguation strategy to reject such cases!
        assertBuildFails(
            zdt1.with().offset(JiffOffset.fromHours(-12)).disambiguation(JiffDisambiguation.REJECT),
            FOLD_IN_NEW_YORK
        );
    }

    @IsTest
    static void theOffsetConflictStrategyDecidesWhatAWrongOffsetMeans() {
        JiffZonedDateTime zdt1 = zoned('2024-11-03T01:30:00-04:00[America/New_York]');
        JiffOffset wrong = JiffOffset.fromHours(-12);
        assertBuildFails(
            zdt1.with().offset(wrong).offsetConflict(JiffOffsetConflict.REJECT),
            'datetime could not resolve to timestamp since `reject` conflict resolution was ' +
                'chosen, and because datetime has offset `-12`, but the time zone ' +
                '`America/New_York` for the given datetime falls in a fold between offsets ' +
                '`-04` and `-05`, neither of which match the offset'
        );
        Assert.areEqual(
            // 01:30 at -12 is 13:30 UTC, which is 08:30 in New York.
            '2024-11-03T08:30:00-05:00[America/New_York]',
            zdt1.with()
                .offset(wrong)
                .offsetConflict(JiffOffsetConflict.ALWAYS_OFFSET)
                .build()
                .toString()
        );
        // A valid offset is ignored too when the time zone always wins.
        JiffZonedDateTimeWith ignoring = zdt1.with()
            .offset(JiffOffset.fromHours(-5))
            .offsetConflict(JiffOffsetConflict.ALWAYS_TIME_ZONE);
        Assert.areEqual('2024-11-03T01:30:00-04:00[America/New_York]', ignoring.build().toString());
        Assert.areEqual(
            '2024-11-03T01:30:00-05:00[America/New_York]',
            ignoring.disambiguation(JiffDisambiguation.LATER).build().toString()
        );
    }

    @IsTest
    static void smallChangesInsideAFoldKeepTheOffset() {
        // Set to the "second" time 1:30 is on the clocks in New York on 2024-11-03.
        JiffZonedDateTime zdt1 = zoned('2024-11-03T01:30:00-05:00[America/New_York]');
        // Now we change the minute field:
        Assert.areEqual(
            // Without taking the offset of the zoned datetime into account, this would have
            // defaulted to using the "compatible" disambiguation strategy, which would have
            // selected the earlier offset of -04 instead of sticking with the later offset of
            // -05.
            '2024-11-03T01:34:00-05:00[America/New_York]',
            zdt1.with().minute(34).build().toString()
        );
        Assert.areEqual(
            '2024-11-03T01:34:00-04:00[America/New_York]',
            zdt1.with()
                .minute(34)
                .offsetConflict(JiffOffsetConflict.ALWAYS_TIME_ZONE)
                .build()
                .toString()
        );
        // But note that if we change the clock time such that the previous offset is no longer
        // valid (by moving back before DST ended), then the default strategy will
        // automatically adapt and change the offset.
        Assert.areEqual(
            '2024-11-03T00:30:00-04:00[America/New_York]',
            zdt1.with().hour(0).build().toString()
        );
        Assert.areEqual(
            '2024-11-03T02:30:00-05:00[America/New_York]',
            zdt1.with().hour(2).build().toString()
        );
        Assert.areEqual(
            '2024-11-02T01:30:00-04:00[America/New_York]',
            zdt1.with().day(2).build().toString()
        );

        JiffZonedDateTime london = zoned('2024-10-27T01:30:00+00:00[Europe/London]');
        Assert.areEqual(
            '2024-10-27T01:45:00+00:00[Europe/London]',
            london.with().minute(45).build().toString()
        );
        Assert.areEqual(
            '2024-10-27T01:30:00+01:00[Europe/London]',
            london.with().offset(JiffOffset.fromHours(1)).build().toString()
        );
    }

    @IsTest
    static void aChangeIntoAGapIsDisambiguated() {
        // This datetime is unambiguous. But the same time on March 10 is ambiguous because
        // there is a gap!
        JiffZonedDateTime zdt1 = zoned('2024-03-11T02:05:00-04:00[America/New_York]');
        JiffZonedDateTime zdt2 = zdt1.with()
            .disambiguation(JiffDisambiguation.EARLIER)
            .day(10)
            .build();
        Assert.areEqual(JiffDateTime.newInstance(2024, 3, 10, 1, 5, 0, 0), zdt2.toDateTime());
        Assert.areEqual(JiffOffset.fromHours(-5), zdt2.offset());

        // The default is compatible, which selects the later time in a gap.
        zdt2 = zdt1.with().day(10).build();
        Assert.areEqual(JiffDateTime.newInstance(2024, 3, 10, 3, 5, 0, 0), zdt2.toDateTime());
        Assert.areEqual(JiffOffset.fromHours(-4), zdt2.offset());

        Assert.areEqual(
            '2024-03-10T03:05:00-04:00[America/New_York]',
            zdt1.with().disambiguation(JiffDisambiguation.LATER).day(10).build().toString()
        );
        assertBuildFails(
            zdt1.with().disambiguation(JiffDisambiguation.REJECT).day(10),
            GAP_IN_NEW_YORK
        );
    }

    @IsTest
    static void theOffsetConflictStrategyAppliesInAGapToo() {
        JiffZonedDateTime zdt1 = zoned('2024-03-11T02:05:00-04:00[America/New_York]');
        JiffZonedDateTime zdt2 = zdt1.with()
            .offsetConflict(JiffOffsetConflict.ALWAYS_OFFSET)
            .day(10)
            .build();
        // Why do we get this result? Because `2024-03-10T02:05-04` is `2024-03-10T06:05Z`. And
        // in `America/New_York`, the civil time for that timestamp is `2024-03-10T01:05-05`.
        Assert.areEqual(JiffDateTime.newInstance(2024, 3, 10, 1, 5, 0, 0), zdt2.toDateTime());
        Assert.areEqual(JiffOffset.fromHours(-5), zdt2.offset());

        assertBuildFails(
            zdt1.with().offsetConflict(JiffOffsetConflict.REJECT).day(10),
            'datetime could not resolve to timestamp since `reject` conflict resolution was ' +
                'chosen, and because datetime has offset `-04`, but the time zone ' +
                '`America/New_York` for the given datetime falls in a gap (between offsets ' +
                '`-05` and `-04`), and all offsets for a gap are regarded as invalid'
        );
        Assert.areEqual(
            '2024-03-10T03:05:00-04:00[America/New_York]',
            zdt1.with()
                .offsetConflict(JiffOffsetConflict.ALWAYS_TIME_ZONE)
                .day(10)
                .build()
                .toString()
        );
    }

    @IsTest
    static void theOffsetIsCorrectedWhenTheSeasonChanges() {
        JiffZonedDateTime zdt1 = zoned('2024-03-11T02:05:00-04:00[America/New_York]');
        Assert.areEqual(
            '2024-01-11T02:05:00-05:00[America/New_York]',
            zdt1.with().month(1).build().toString()
        );
        assertBuildFails(
            zdt1.with().month(1).offsetConflict(JiffOffsetConflict.REJECT),
            'datetime could not resolve to a timestamp since `reject` conflict resolution was ' +
                'chosen, and because datetime has offset `-04`, but the time zone ' +
                '`America/New_York` for the given datetime unambiguously has offset `-05`'
        );
        Assert.areEqual(
            '2024-01-11T01:05:00-05:00[America/New_York]',
            zdt1.with().month(1).offsetConflict(JiffOffsetConflict.ALWAYS_OFFSET).build().toString()
        );
    }

    @IsTest
    static void zonedWithTimeDstAmericaNewYork() {
        // From `zoned_with_time_dst_america_new_york` in Jiff's tests.
        JiffZonedDateTime zdt1 = newYork(2024, 3, 10, 1, 30, 0, 0);
        Assert.areEqual('2024-03-10T01:30:00-05:00[America/New_York]', zdt1.toString());
        Assert.areEqual(
            '2024-03-10T03:30:00-04:00[America/New_York]',
            zdt1.with().hour(2).build().toString()
        );

        JiffZonedDateTime zdt3 = newYork(2024, 3, 10, 3, 30, 0, 0);
        Assert.areEqual('2024-03-10T03:30:00-04:00[America/New_York]', zdt3.toString());
        Assert.areEqual(
            '2024-03-10T03:30:00-04:00[America/New_York]',
            zdt3.with().hour(2).build().toString()
        );

        // The disambiguation setting is respected, and the bad offset is ignored.
        Assert.areEqual(
            '2024-03-10T01:30:00-05:00[America/New_York]',
            zdt1.with()
                .offset(JiffOffset.fromHours(10))
                .hour(2)
                .disambiguation(JiffDisambiguation.EARLIER)
                .build()
                .toString()
        );
        // This should also respect the disambiguation setting even without explicitly
        // specifying an invalid offset. This is because `02:30-05` is regarded as invalid
        // since `02:30` isn't a valid civil time on this date in this time zone.
        Assert.areEqual(
            '2024-03-10T01:30:00-05:00[America/New_York]',
            zdt1.with().hour(2).disambiguation(JiffDisambiguation.EARLIER).build().toString()
        );
    }

    @IsTest
    static void zonedWithTimeDstAfterGap() {
        // From `zoned_with_time_dst_after_gap` in Jiff's tests. The Azores skip midnight.
        JiffZonedDateTime zdt1 = JiffDate.newInstance(2024, 3, 31)
            .at(12, 0, 0, 0)
            .inTz('Atlantic/Azores');
        Assert.areEqual('2024-03-31T12:00:00+00:00[Atlantic/Azores]', zdt1.toString());
        JiffZonedDateTime zdt2 = zdt1.with().withTime(JiffTime.midnight()).build();
        Assert.areEqual('2024-03-31T01:00:00+00:00[Atlantic/Azores]', zdt2.toString());
    }

    @IsTest
    static void noRejectInFoldWhenUsingWith() {
        // From `no_reject_in_fold_when_using_with` in Jiff's tests: one doesn't get a rejection
        // during a fold, because the offset of the original settles it.
        JiffZonedDateTime zdt1 = zoned('2016-09-30T02:01:00+02:00[Europe/Amsterdam]');
        JiffZonedDateTime zdt2 = zdt1.with()
            .month(10)
            .disambiguation(JiffDisambiguation.REJECT)
            .offsetConflict(JiffOffsetConflict.REJECT)
            .build();
        Assert.areEqual('2016-10-30T02:01:00+02:00[Europe/Amsterdam]', zdt2.toString());
        // Both readings of that time exist.
        zoned('2016-10-30T02:01:00+02:00[Europe/Amsterdam]');
        zoned('2016-10-30T02:01:00+01:00[Europe/Amsterdam]');
    }

    @IsTest
    static void changesIntoOtherGaps() {
        // Sao Paulo skipped midnight on 2015-10-18.
        JiffZonedDateTime saoPaulo = zoned('2015-10-17T00:30:00-03:00[America/Sao_Paulo]');
        Assert.areEqual(
            '2015-10-18T01:30:00-02:00[America/Sao_Paulo]',
            saoPaulo.with().day(18).build().toString()
        );
        Assert.areEqual(
            '2015-10-17T23:30:00-03:00[America/Sao_Paulo]',
            saoPaulo.with().day(18).disambiguation(JiffDisambiguation.EARLIER).build().toString()
        );
        // Apia skipped the whole of 2011-12-30.
        JiffZonedDateTime apia = zoned('2011-12-29T12:00:00-10:00[Pacific/Apia]');
        Assert.areEqual(
            '2011-12-31T12:00:00+14:00[Pacific/Apia]',
            apia.with().day(30).build().toString()
        );
        Assert.areEqual(
            '2011-12-29T12:00:00-10:00[Pacific/Apia]',
            apia.with().day(30).disambiguation(JiffDisambiguation.EARLIER).build().toString()
        );
        assertBuildFails(
            apia.with().day(30).disambiguation(JiffDisambiguation.REJECT),
            'error converting datetime to instant in time zone Pacific/Apia: datetime is ' +
            'ambiguous since it falls into a gap between offsets -10 and +14'
        );
    }

    @IsTest
    static void theResultMustBeWithinTheSupportedRange() {
        assertBuildFails(
            JiffTimestamp.MAX.inTz('UTC').with().hour(23),
            'error converting datetime to instant in time zone UTC: converting datetime with ' +
                'time zone offset `+00` to timestamp overflowed: parameter \'Unix timestamp ' +
                'seconds\' is not in the required range of -377705023201..=253402207200'
        );
    }
}
