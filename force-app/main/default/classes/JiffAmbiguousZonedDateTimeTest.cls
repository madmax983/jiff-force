/**
 * `JiffAmbiguousZonedDateTime`.
 *
 * Expected values are from the examples in Jiff's documentation of
 * `tz::AmbiguousZonedDateTime`, or were printed by Jiff 1.0.0 itself.
 */
@IsTest
private class JiffAmbiguousZonedDateTimeTest {
    private static final JiffTimeZone NEW_YORK = JiffTimeZone.get('America/New_York');
    private static final JiffDateTime UNAMBIGUOUS = JiffDateTime.newInstance(
        2024,
        7,
        15,
        17,
        30,
        0,
        0
    );
    private static final JiffDateTime IN_A_GAP = JiffDateTime.newInstance(2024, 3, 10, 2, 30, 0, 0);
    private static final JiffDateTime IN_A_FOLD = JiffDateTime.newInstance(
        2024,
        11,
        3,
        1,
        30,
        0,
        0
    );
    private static final String OVERFLOW =
        'to timestamp overflowed: parameter \'Unix timestamp seconds\' is not in the ' +
        'required range of -377705023201..=253402207200';

    private static JiffOffset hours(Integer value) {
        return JiffOffset.fromHours(value);
    }

    private static String outcome(JiffAmbiguousZonedDateTime ambiguous, JiffDisambiguation option) {
        try {
            return ambiguous.disambiguate(option).toString();
        } catch (JiffException e) {
            return 'ERR ' + e.getMessage();
        }
    }

    @IsTest
    static void remembersTheTimeZoneAndTheCivilDatetime() {
        JiffDateTime dt = JiffDateTime.newInstance(2024, 7, 10, 17, 15, 0, 0);
        JiffAmbiguousZonedDateTime zdt = NEW_YORK.toAmbiguousZonedDateTime(dt);
        Assert.areEqual(NEW_YORK, zdt.timeZone());
        Assert.areEqual(dt, zdt.toDateTime());
    }

    @IsTest
    static void reportsTheCandidateOffsets() {
        // Not ambiguous.
        Assert.areEqual(
            JiffAmbiguousOffset.unambiguous(hours(-4)),
            NEW_YORK.toAmbiguousZonedDateTime(UNAMBIGUOUS).offset()
        );
        // Ambiguous because of a gap.
        Assert.areEqual(
            JiffAmbiguousOffset.gap(hours(-5), hours(-4)),
            NEW_YORK.toAmbiguousZonedDateTime(IN_A_GAP).offset()
        );
        // Ambiguous because of a fold.
        Assert.areEqual(
            JiffAmbiguousOffset.fold(hours(-4), hours(-5)),
            NEW_YORK.toAmbiguousZonedDateTime(IN_A_FOLD).offset()
        );
    }

    @IsTest
    static void knowsWhetherItIsAmbiguous() {
        Assert.isFalse(NEW_YORK.toAmbiguousZonedDateTime(UNAMBIGUOUS).isAmbiguous());
        Assert.isTrue(NEW_YORK.toAmbiguousZonedDateTime(IN_A_GAP).isAmbiguous());
        Assert.isTrue(NEW_YORK.toAmbiguousZonedDateTime(IN_A_FOLD).isAmbiguous());
    }

    @IsTest
    static void compatiblePicksLaterInAGapAndEarlierInAFold() {
        Assert.areEqual(
            '2024-07-15T17:30:00-04:00[America/New_York]',
            NEW_YORK.toAmbiguousZonedDateTime(UNAMBIGUOUS).compatible().toString()
        );
        Assert.areEqual(
            '2024-03-10T03:30:00-04:00[America/New_York]',
            NEW_YORK.toAmbiguousZonedDateTime(IN_A_GAP).compatible().toString()
        );
        Assert.areEqual(
            '2024-11-03T01:30:00-04:00[America/New_York]',
            NEW_YORK.toAmbiguousZonedDateTime(IN_A_FOLD).compatible().toString()
        );
    }

    @IsTest
    static void earlierPicksTheEarlierInstant() {
        Assert.areEqual(
            '2024-07-15T17:30:00-04:00[America/New_York]',
            NEW_YORK.toAmbiguousZonedDateTime(UNAMBIGUOUS).earlier().toString()
        );
        Assert.areEqual(
            '2024-03-10T01:30:00-05:00[America/New_York]',
            NEW_YORK.toAmbiguousZonedDateTime(IN_A_GAP).earlier().toString()
        );
        Assert.areEqual(
            '2024-11-03T01:30:00-04:00[America/New_York]',
            NEW_YORK.toAmbiguousZonedDateTime(IN_A_FOLD).earlier().toString()
        );
    }

    @IsTest
    static void laterPicksTheLaterInstant() {
        Assert.areEqual(
            '2024-07-15T17:30:00-04:00[America/New_York]',
            NEW_YORK.toAmbiguousZonedDateTime(UNAMBIGUOUS).later().toString()
        );
        Assert.areEqual(
            '2024-03-10T03:30:00-04:00[America/New_York]',
            NEW_YORK.toAmbiguousZonedDateTime(IN_A_GAP).later().toString()
        );
        Assert.areEqual(
            '2024-11-03T01:30:00-05:00[America/New_York]',
            NEW_YORK.toAmbiguousZonedDateTime(IN_A_FOLD).later().toString()
        );
    }

    @IsTest
    static void unambiguousRefusesToChoose() {
        Assert.areEqual(
            '2024-07-15T17:30:00-04:00[America/New_York]',
            NEW_YORK.toAmbiguousZonedDateTime(UNAMBIGUOUS).unambiguous().toString()
        );
        try {
            NEW_YORK.toAmbiguousZonedDateTime(IN_A_GAP).unambiguous();
            Assert.fail('expected a datetime in a gap to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'error converting datetime to instant in time zone America/New_York: ' +
                'datetime is ambiguous since it falls into a gap between offsets -05 and -04',
                e.getMessage()
            );
        }
        try {
            NEW_YORK.toAmbiguousZonedDateTime(IN_A_FOLD).unambiguous();
            Assert.fail('expected a datetime in a fold to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'error converting datetime to instant in time zone America/New_York: ' +
                'datetime is ambiguous since it falls into a fold between offsets -04 and -05',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void disambiguateAppliesTheGivenStrategy() {
        JiffAmbiguousZonedDateTime ambiguous = NEW_YORK.toAmbiguousZonedDateTime(IN_A_FOLD);
        // In compatible mode, backward transitions select the earlier time. In the EDT->EST
        // transition, that's the -04 (EDT) offset.
        Assert.areEqual(
            '2024-11-03T01:30:00-04:00[America/New_York]',
            ambiguous.disambiguate(JiffDisambiguation.COMPATIBLE).toString()
        );
        // The earlier time in the EDT->EST transition is the -04 (EDT) offset.
        Assert.areEqual(
            '2024-11-03T01:30:00-04:00[America/New_York]',
            ambiguous.disambiguate(JiffDisambiguation.EARLIER).toString()
        );
        // The later time in the EDT->EST transition is the -05 (EST) offset.
        Assert.areEqual(
            '2024-11-03T01:30:00-05:00[America/New_York]',
            ambiguous.disambiguate(JiffDisambiguation.LATER).toString()
        );
        // Since our datetime is ambiguous, the 'reject' strategy errors.
        try {
            ambiguous.disambiguate(JiffDisambiguation.REJECT);
            Assert.fail('expected the reject strategy to refuse a fold');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('fold'), e.getMessage());
        }
        try {
            ambiguous.disambiguate(null);
            Assert.fail('expected a missing strategy to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('disambiguation strategy must not be null', e.getMessage());
        }
    }

    @IsTest
    static void resolvesGapsAndFoldsInManyZones() {
        // Each row is: zone, civil datetime, the offsets as this port prints them, and what
        // Jiff gives for compatible, earlier, later and unambiguous.
        List<List<String>> cases = new List<List<String>>{
            new List<String>{
                'Europe/London',
                '2024-03-31T01:30:00',
                'Gap(+00, +01)',
                '2024-03-31T02:30:00+01:00[Europe/London]',
                '2024-03-31T00:30:00+00:00[Europe/London]',
                '2024-03-31T02:30:00+01:00[Europe/London]',
                'ERR error converting datetime to instant in time zone Europe/London: ' +
                'datetime is ambiguous since it falls into a gap between offsets +00 and +01'
            },
            new List<String>{
                'Europe/London',
                '2024-10-27T01:30:00',
                'Fold(+01, +00)',
                '2024-10-27T01:30:00+01:00[Europe/London]',
                '2024-10-27T01:30:00+01:00[Europe/London]',
                '2024-10-27T01:30:00+00:00[Europe/London]',
                'ERR error converting datetime to instant in time zone Europe/London: ' +
                'datetime is ambiguous since it falls into a fold between offsets +01 and +00'
            },
            new List<String>{
                'Australia/Sydney',
                '2024-10-06T02:30:00',
                'Gap(+10, +11)',
                '2024-10-06T03:30:00+11:00[Australia/Sydney]',
                '2024-10-06T01:30:00+10:00[Australia/Sydney]',
                '2024-10-06T03:30:00+11:00[Australia/Sydney]',
                'ERR error converting datetime to instant in time zone Australia/Sydney: ' +
                'datetime is ambiguous since it falls into a gap between offsets +10 and +11'
            },
            new List<String>{
                'Australia/Sydney',
                '2024-04-07T02:30:00',
                'Fold(+11, +10)',
                '2024-04-07T02:30:00+11:00[Australia/Sydney]',
                '2024-04-07T02:30:00+11:00[Australia/Sydney]',
                '2024-04-07T02:30:00+10:00[Australia/Sydney]',
                'ERR error converting datetime to instant in time zone Australia/Sydney: ' +
                'datetime is ambiguous since it falls into a fold between offsets +11 and +10'
            },
            new List<String>{
                'America/Sao_Paulo',
                '2015-10-18T00:30:00',
                'Gap(-03, -02)',
                '2015-10-18T01:30:00-02:00[America/Sao_Paulo]',
                '2015-10-17T23:30:00-03:00[America/Sao_Paulo]',
                '2015-10-18T01:30:00-02:00[America/Sao_Paulo]',
                'ERR error converting datetime to instant in time zone America/Sao_Paulo: ' +
                'datetime is ambiguous since it falls into a gap between offsets -03 and -02'
            },
            new List<String>{
                'America/Sao_Paulo',
                '2016-02-20T23:30:00',
                'Fold(-02, -03)',
                '2016-02-20T23:30:00-02:00[America/Sao_Paulo]',
                '2016-02-20T23:30:00-02:00[America/Sao_Paulo]',
                '2016-02-20T23:30:00-03:00[America/Sao_Paulo]',
                'ERR error converting datetime to instant in time zone America/Sao_Paulo: ' +
                'datetime is ambiguous since it falls into a fold between offsets -02 and -03'
            },
            // A whole day that never happened.
            new List<String>{
                'Pacific/Apia',
                '2011-12-30T12:00:00',
                'Gap(-10, +14)',
                '2011-12-31T12:00:00+14:00[Pacific/Apia]',
                '2011-12-29T12:00:00-10:00[Pacific/Apia]',
                '2011-12-31T12:00:00+14:00[Pacific/Apia]',
                'ERR error converting datetime to instant in time zone Pacific/Apia: ' +
                'datetime is ambiguous since it falls into a gap between offsets -10 and +14'
            },
            new List<String>{
                'Asia/Kolkata',
                '2024-07-04T12:00:00',
                'Unambiguous(+05:30)',
                '2024-07-04T12:00:00+05:30[Asia/Kolkata]',
                '2024-07-04T12:00:00+05:30[Asia/Kolkata]',
                '2024-07-04T12:00:00+05:30[Asia/Kolkata]',
                '2024-07-04T12:00:00+05:30[Asia/Kolkata]'
            },
            new List<String>{
                'UTC',
                '2024-07-04T12:00:00',
                'Unambiguous(+00)',
                '2024-07-04T12:00:00+00:00[UTC]',
                '2024-07-04T12:00:00+00:00[UTC]',
                '2024-07-04T12:00:00+00:00[UTC]',
                '2024-07-04T12:00:00+00:00[UTC]'
            },
            new List<String>{
                '-05:00',
                '2024-07-04T12:00:00',
                'Unambiguous(-05)',
                '2024-07-04T12:00:00-05:00[-05:00]',
                '2024-07-04T12:00:00-05:00[-05:00]',
                '2024-07-04T12:00:00-05:00[-05:00]',
                '2024-07-04T12:00:00-05:00[-05:00]'
            }
        };
        for (List<String> row : cases) {
            JiffTimeZone tz = JiffZonedTestSupport.zone(row.get(0));
            JiffDateTime dt = JiffZonedTestSupport.civil(row.get(1));
            JiffAmbiguousZonedDateTime ambiguous = tz.toAmbiguousZonedDateTime(dt);
            String label = row.get(1) + ' in ' + row.get(0);
            Assert.areEqual(row.get(2), ambiguous.offset().toString(), label);
            Assert.areEqual(!row.get(2).startsWith('Unambiguous'), ambiguous.isAmbiguous(), label);
            Assert.areEqual(row.get(3), outcome(ambiguous, JiffDisambiguation.COMPATIBLE), label);
            Assert.areEqual(row.get(4), outcome(ambiguous, JiffDisambiguation.EARLIER), label);
            Assert.areEqual(row.get(5), outcome(ambiguous, JiffDisambiguation.LATER), label);
            Assert.areEqual(row.get(6), outcome(ambiguous, JiffDisambiguation.REJECT), label);
        }
    }

    @IsTest
    static void theChosenInstantMustBeInRange() {
        JiffAmbiguousZonedDateTime atMax = JiffTimeZone.UTC.toAmbiguousZonedDateTime(
            JiffDateTime.MAX
        );
        JiffAmbiguousZonedDateTime atMin = JiffTimeZone.UTC.toAmbiguousZonedDateTime(
            JiffDateTime.MIN
        );
        String inUtc =
            'error converting datetime to instant in time zone UTC: converting datetime with ' +
            'time zone offset `+00` ' +
            OVERFLOW;
        for (JiffDisambiguation option : JiffDisambiguation.values()) {
            Assert.areEqual('ERR ' + inUtc, outcome(atMax, option));
            Assert.areEqual('ERR ' + inUtc, outcome(atMin, option));
        }
        // A fixed offset zone is named by its offset.
        JiffTimeZone fixed = JiffTimeZone.fixed(hours(-5));
        Assert.areEqual(
            'ERR error converting datetime to instant in time zone -05: converting datetime ' +
                'with time zone offset `-05` ' +
                OVERFLOW,
            outcome(fixed.toAmbiguousZonedDateTime(JiffDateTime.MAX), JiffDisambiguation.COMPATIBLE)
        );
    }

    @IsTest
    static void needsAnAmbiguousTimestampAndATimeZone() {
        JiffAmbiguousTimestamp ts = NEW_YORK.toAmbiguousTimestamp(IN_A_FOLD);
        Assert.areEqual(
            NEW_YORK.toAmbiguousZonedDateTime(IN_A_FOLD),
            JiffAmbiguousZonedDateTime.newInstance(ts, NEW_YORK)
        );
        String expected = 'an ambiguous zoned datetime needs both an ambiguous timestamp and a time zone';
        try {
            JiffAmbiguousZonedDateTime.newInstance(null, NEW_YORK);
            Assert.fail('expected a missing timestamp to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
        try {
            JiffAmbiguousZonedDateTime.newInstance(ts, null);
            Assert.fail('expected a missing time zone to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    @IsTest
    static void equalityCoversTheDatetimeTheOffsetsAndTheZone() {
        JiffAmbiguousZonedDateTime fold = NEW_YORK.toAmbiguousZonedDateTime(IN_A_FOLD);
        Assert.areEqual(fold, NEW_YORK.toAmbiguousZonedDateTime(IN_A_FOLD));
        Assert.areEqual(fold.hashCode(), NEW_YORK.toAmbiguousZonedDateTime(IN_A_FOLD).hashCode());
        Assert.areNotEqual(fold, NEW_YORK.toAmbiguousZonedDateTime(IN_A_GAP));
        // The same civil datetime and offset in a different zone is a different thing.
        JiffAmbiguousTimestamp pinned = JiffAmbiguousTimestamp.newInstance(
            UNAMBIGUOUS,
            JiffAmbiguousOffset.unambiguous(hours(-4))
        );
        Assert.areEqual(
            NEW_YORK.toAmbiguousZonedDateTime(UNAMBIGUOUS),
            JiffAmbiguousZonedDateTime.newInstance(pinned, NEW_YORK)
        );
        Assert.areNotEqual(
            NEW_YORK.toAmbiguousZonedDateTime(UNAMBIGUOUS),
            JiffAmbiguousZonedDateTime.newInstance(pinned, JiffTimeZone.fixed(hours(-4)))
        );
        Assert.isFalse(fold.equals(fold.compatible()));
        Assert.isFalse(fold.equals(null));
    }

    @IsTest
    static void printsTheDatetimeTheOffsetsAndTheZone() {
        Assert.areEqual(
            '2024-11-03T01:30:00 Fold(-04, -05) [America/New_York]',
            NEW_YORK.toAmbiguousZonedDateTime(IN_A_FOLD).toString()
        );
        Assert.areEqual(
            '2024-03-10T02:30:00 Gap(-05, -04) [America/New_York]',
            NEW_YORK.toAmbiguousZonedDateTime(IN_A_GAP).toString()
        );
        Assert.areEqual(
            '2024-07-15T17:30:00 Unambiguous(+00) [UTC]',
            JiffTimeZone.UTC.toAmbiguousZonedDateTime(UNAMBIGUOUS).toString()
        );
    }
}
