/**
 * `JiffOffsetConflicts.resolve` and `resolveWith`.
 *
 * Expected values are from the examples in Jiff's documentation of `tz::OffsetConflict`, or
 * were printed by Jiff 1.0.0 itself.
 */
@IsTest
private class JiffOffsetConflictsTest {
    private static final JiffTimeZone NEW_YORK = JiffTimeZone.get('America/New_York');
    private static final String GAP_IN_NEW_YORK =
        'ERR error converting datetime to instant in time zone America/New_York: datetime is ' +
        'ambiguous since it falls into a gap between offsets -05 and -04';
    private static final String FOLD_IN_NEW_YORK =
        'ERR error converting datetime to instant in time zone America/New_York: datetime is ' +
        'ambiguous since it falls into a fold between offsets -04 and -05';
    // The order in which the tables below list the strategies.
    private static final List<JiffOffsetConflict> STRATEGIES = new List<JiffOffsetConflict>{
        JiffOffsetConflict.ALWAYS_OFFSET,
        JiffOffsetConflict.ALWAYS_TIME_ZONE,
        JiffOffsetConflict.PREFER_OFFSET,
        JiffOffsetConflict.REJECT
    };

    /** Treats two offsets as equal when they agree after rounding the zone's to the minute. */
    private class ToTheMinute implements JiffOffsetConflicts.Equality {
        public Boolean isEqual(JiffOffset given, JiffOffset candidate) {
            return given.equals(candidate) || given.equals(candidate.round(JiffUnit.MINUTE));
        }
    }

    /** Accepts any offset at all. */
    private class Anything implements JiffOffsetConflicts.Equality {
        public Boolean isEqual(JiffOffset given, JiffOffset candidate) {
            return true;
        }
    }

    private static JiffOffset hours(Integer value) {
        return JiffOffset.fromHours(value);
    }

    /**
     * Resolves and then disambiguates, describing the result the way the tables do: the
     * zoned datetime, or `ERR` and the message when either step fails.
     */
    private static String outcome(
        JiffOffsetConflict strategy,
        JiffDateTime dt,
        JiffOffset offset,
        JiffTimeZone tz,
        JiffOffsetConflicts.Equality isEqual,
        JiffDisambiguation option
    ) {
        try {
            return JiffOffsetConflicts.resolveWith(strategy, dt, offset, tz, isEqual)
                .disambiguate(option)
                .toString();
        } catch (JiffException e) {
            return 'ERR ' + e.getMessage();
        }
    }

    private static String rejected(String given, String reason) {
        return 'ERR datetime could not resolve to timestamp since `reject` conflict ' +
            'resolution was chosen, and because datetime has offset `' +
            given +
            '`, but the time zone `America/New_York` for the given datetime ' +
            reason;
    }

    // ---- Jiff's documentation examples ------------------------------------

    @IsTest
    static void aWrongOffsetIsHandledByTheStrategy() {
        JiffDateTime dt = JiffDateTime.newInstance(2024, 6, 14, 17, 30, 0, 0);
        JiffOffset offset = hours(-5); // wrong! should be -4

        // Here, we use the offset and ignore the time zone.
        JiffZonedDateTime zdt = JiffOffsetConflicts.resolve(
                JiffOffsetConflict.ALWAYS_OFFSET,
                dt,
                offset,
                NEW_YORK
            )
            .unambiguous();
        // The datetime (and offset) have been corrected automatically and the resulting
        // instant corresponds precisely to `2024-06-14T17:30-05[UTC]`.
        Assert.areEqual('2024-06-14T18:30:00-04:00[America/New_York]', zdt.toString());

        // Here, we use the time zone and ignore the offset.
        zdt = JiffOffsetConflicts.resolve(JiffOffsetConflict.ALWAYS_TIME_ZONE, dt, offset, NEW_YORK)
            .unambiguous();
        // The offset has been corrected automatically. Notice how the civil time remains the
        // same, but the exact instant has changed!
        Assert.areEqual('2024-06-14T17:30:00-04:00[America/New_York]', zdt.toString());
        Assert.areEqual(dt, zdt.toDateTime());
        Assert.areEqual(hours(-4), zdt.offset());

        // Here, we prefer the offset, but fall back to the time zone. In this example, it has
        // the same behavior as `ALWAYS_TIME_ZONE`.
        zdt = JiffOffsetConflicts.resolve(JiffOffsetConflict.PREFER_OFFSET, dt, offset, NEW_YORK)
            .unambiguous();
        Assert.areEqual('2024-06-14T17:30:00-04:00[America/New_York]', zdt.toString());

        // The 'Reject' strategy, Jiff's default, will error.
        try {
            JiffOffsetConflicts.resolve(JiffOffsetConflict.REJECT, dt, offset, NEW_YORK);
            Assert.fail('expected the wrong offset to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'datetime could not resolve to a timestamp since `reject` conflict ' +
                    'resolution was chosen, and because datetime has offset `-05`, but the ' +
                    'time zone `America/New_York` for the given datetime unambiguously has ' +
                    'offset `-04`',
                e.getMessage()
            );
        }
    }

    // ---- every strategy against every kind of datetime --------------------

    @IsTest
    static void resolvesEveryCombinationAsJiffDoes() {
        // Each row is a civil datetime in New York and the offset given with it, in hours,
        // followed by four results for each strategy in the order of STRATEGIES: what Jiff
        // gives for compatible, earlier, later and unambiguous. `same` repeats the result
        // before it.
        String unambiguousAt4 = 'datetime unambiguously has offset `-04`';
        String gap =
            'falls in a gap (between offsets `-05` and `-04`), and all offsets for a gap are ' +
            'regarded as invalid';
        String fold = 'falls in a fold between offsets `-04` and `-05`, neither of which match the offset';
        String summerAt4 = '2024-06-14T17:30:00-04:00[America/New_York]';
        String afterGap = '2024-03-10T03:30:00-04:00[America/New_York]';
        String beforeGap = '2024-03-10T01:30:00-05:00[America/New_York]';
        String firstFold = '2024-11-03T01:30:00-04:00[America/New_York]';
        String secondFold = '2024-11-03T01:30:00-05:00[America/New_York]';
        List<List<String>> cases = new List<List<String>>{
            // An unambiguous datetime with the wrong offset.
            new List<String>{
                '2024-06-14T17:30:00',
                '-5',
                '2024-06-14T18:30:00-04:00[America/New_York]',
                'same',
                'same',
                'same',
                summerAt4,
                'same',
                'same',
                'same',
                summerAt4,
                'same',
                'same',
                'same',
                'ERR datetime could not resolve to a timestamp since `reject` conflict ' +
                'resolution was chosen, and because datetime has offset `-05`, but the ' +
                'time zone `America/New_York` for the given ' +
                unambiguousAt4,
                'same',
                'same',
                'same'
            },
            // An unambiguous datetime with the right offset.
            new List<String>{
                '2024-06-14T17:30:00',
                '-4',
                summerAt4,
                'same',
                'same',
                'same',
                summerAt4,
                'same',
                'same',
                'same',
                summerAt4,
                'same',
                'same',
                'same',
                summerAt4,
                'same',
                'same',
                'same'
            },
            // A datetime in a gap, with the offset from before it.
            new List<String>{
                '2024-03-10T02:30:00',
                '-5',
                afterGap,
                'same',
                'same',
                'same',
                afterGap,
                beforeGap,
                afterGap,
                GAP_IN_NEW_YORK,
                afterGap,
                beforeGap,
                afterGap,
                GAP_IN_NEW_YORK,
                rejected('-05', gap),
                'same',
                'same',
                'same'
            },
            // A datetime in a gap, with the offset from after it.
            new List<String>{
                '2024-03-10T02:30:00',
                '-4',
                beforeGap,
                'same',
                'same',
                'same',
                afterGap,
                beforeGap,
                afterGap,
                GAP_IN_NEW_YORK,
                afterGap,
                beforeGap,
                afterGap,
                GAP_IN_NEW_YORK,
                rejected('-04', gap),
                'same',
                'same',
                'same'
            },
            // A datetime in a gap, with an unrelated offset.
            new List<String>{
                '2024-03-10T02:30:00',
                '-7',
                '2024-03-10T05:30:00-04:00[America/New_York]',
                'same',
                'same',
                'same',
                afterGap,
                beforeGap,
                afterGap,
                GAP_IN_NEW_YORK,
                afterGap,
                beforeGap,
                afterGap,
                GAP_IN_NEW_YORK,
                rejected('-07', gap),
                'same',
                'same',
                'same'
            },
            // A datetime in a fold, with the first of its offsets.
            new List<String>{
                '2024-11-03T01:30:00',
                '-4',
                firstFold,
                'same',
                'same',
                'same',
                firstFold,
                firstFold,
                secondFold,
                FOLD_IN_NEW_YORK,
                firstFold,
                'same',
                'same',
                'same',
                firstFold,
                'same',
                'same',
                'same'
            },
            // A datetime in a fold, with the second of its offsets.
            new List<String>{
                '2024-11-03T01:30:00',
                '-5',
                secondFold,
                'same',
                'same',
                'same',
                firstFold,
                firstFold,
                secondFold,
                FOLD_IN_NEW_YORK,
                secondFold,
                'same',
                'same',
                'same',
                secondFold,
                'same',
                'same',
                'same'
            },
            // A datetime in a fold, with an unrelated offset.
            new List<String>{
                '2024-11-03T01:30:00',
                '-6',
                '2024-11-03T02:30:00-05:00[America/New_York]',
                'same',
                'same',
                'same',
                firstFold,
                firstFold,
                secondFold,
                FOLD_IN_NEW_YORK,
                firstFold,
                firstFold,
                secondFold,
                FOLD_IN_NEW_YORK,
                rejected('-06', fold),
                'same',
                'same',
                'same'
            }
        };
        List<JiffDisambiguation> options = new List<JiffDisambiguation>{
            JiffDisambiguation.COMPATIBLE,
            JiffDisambiguation.EARLIER,
            JiffDisambiguation.LATER,
            JiffDisambiguation.REJECT
        };
        for (List<String> row : cases) {
            JiffDateTime dt = JiffZonedTestSupport.civil(row.get(0));
            JiffOffset offset = hours(Integer.valueOf(row.get(1)));
            Integer column = 2;
            for (JiffOffsetConflict strategy : STRATEGIES) {
                String expected = null;
                for (JiffDisambiguation option : options) {
                    String cell = row.get(column);
                    column++;
                    expected = cell.equals('same') ? expected : cell;
                    Assert.areEqual(
                        expected,
                        outcome(strategy, dt, offset, NEW_YORK, null, option),
                        row.get(0) + ' at ' + row.get(1) + ' with ' + strategy + ', ' + option
                    );
                }
            }
        }
    }

    @IsTest
    static void reportsTheOffsetsItFound() {
        JiffDateTime inFold = JiffDateTime.newInstance(2024, 11, 3, 1, 30, 0, 0);
        JiffDateTime inGap = JiffDateTime.newInstance(2024, 3, 10, 2, 30, 0, 0);
        // The given offset decides, so nothing is ambiguous any more.
        Assert.areEqual(
            JiffAmbiguousOffset.unambiguous(hours(-6)),
            JiffOffsetConflicts.resolve(
                    JiffOffsetConflict.ALWAYS_OFFSET,
                    inFold,
                    hours(-6),
                    NEW_YORK
                )
                .offset()
        );
        Assert.areEqual(
            JiffAmbiguousOffset.unambiguous(hours(-5)),
            JiffOffsetConflicts.resolve(
                    JiffOffsetConflict.PREFER_OFFSET,
                    inFold,
                    hours(-5),
                    NEW_YORK
                )
                .offset()
        );
        Assert.areEqual(
            JiffAmbiguousOffset.unambiguous(hours(-5)),
            JiffOffsetConflicts.resolve(JiffOffsetConflict.REJECT, inFold, hours(-5), NEW_YORK)
                .offset()
        );
        // The time zone decides, and reports the ambiguity it found.
        Assert.areEqual(
            JiffAmbiguousOffset.fold(hours(-4), hours(-5)),
            JiffOffsetConflicts.resolve(
                    JiffOffsetConflict.ALWAYS_TIME_ZONE,
                    inFold,
                    hours(-5),
                    NEW_YORK
                )
                .offset()
        );
        Assert.areEqual(
            JiffAmbiguousOffset.fold(hours(-4), hours(-5)),
            JiffOffsetConflicts.resolve(
                    JiffOffsetConflict.PREFER_OFFSET,
                    inFold,
                    hours(-6),
                    NEW_YORK
                )
                .offset()
        );
        Assert.areEqual(
            JiffAmbiguousOffset.gap(hours(-5), hours(-4)),
            JiffOffsetConflicts.resolve(
                    JiffOffsetConflict.PREFER_OFFSET,
                    inGap,
                    hours(-5),
                    NEW_YORK
                )
                .offset()
        );
        JiffAmbiguousZonedDateTime resolved = JiffOffsetConflicts.resolve(
            JiffOffsetConflict.PREFER_OFFSET,
            inGap,
            hours(-5),
            NEW_YORK
        );
        Assert.areEqual(NEW_YORK, resolved.timeZone());
        Assert.areEqual(inGap, resolved.toDateTime());
    }

    @IsTest
    static void fixedAndUtcZonesHaveOneOffset() {
        JiffDateTime dt = JiffDateTime.newInstance(1970, 6, 1, 0, 0, 0, 0);
        try {
            JiffOffsetConflicts.resolve(
                JiffOffsetConflict.REJECT,
                dt,
                hours(-5),
                JiffTimeZone.fixed(hours(3))
            );
            Assert.fail('expected an offset other than the fixed one to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'datetime could not resolve to a timestamp since `reject` conflict ' +
                    'resolution was chosen, and because datetime has offset `-05`, but the ' +
                    'time zone `+03` for the given datetime unambiguously has offset `+03`',
                e.getMessage()
            );
        }
        Assert.areEqual(
            '1970-06-01T00:00:00+00:00[UTC]',
            JiffOffsetConflicts.resolve(
                    JiffOffsetConflict.REJECT,
                    dt,
                    JiffOffset.UTC,
                    JiffTimeZone.UTC
                )
                .compatible()
                .toString()
        );
    }

    @IsTest
    static void theInstantMustBeInRange() {
        try {
            JiffOffsetConflicts.resolve(
                    JiffOffsetConflict.ALWAYS_OFFSET,
                    JiffDateTime.MAX,
                    hours(-5),
                    NEW_YORK
                )
                .compatible();
            Assert.fail('expected the maximum datetime at -05 to have no instant');
        } catch (JiffException e) {
            Assert.areEqual(
                'error converting datetime to instant in time zone America/New_York: ' +
                    'converting datetime with time zone offset `-05` to timestamp overflowed: ' +
                    'parameter \'Unix timestamp seconds\' is not in the required range of ' +
                    '-377705023201..=253402207200',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void needsEveryArgument() {
        JiffDateTime dt = JiffDateTime.ZERO;
        JiffOffset offset = JiffOffset.UTC;
        try {
            JiffOffsetConflicts.resolve(null, dt, offset, NEW_YORK);
            Assert.fail('expected a missing strategy to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('offset conflict strategy must not be null', e.getMessage());
        }
        String expected = 'resolving an offset conflict needs a datetime, an offset and a time zone';
        try {
            JiffOffsetConflicts.resolve(JiffOffsetConflict.REJECT, null, offset, NEW_YORK);
            Assert.fail('expected a missing datetime to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
        try {
            JiffOffsetConflicts.resolve(JiffOffsetConflict.REJECT, dt, null, NEW_YORK);
            Assert.fail('expected a missing offset to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
        try {
            JiffOffsetConflicts.resolve(JiffOffsetConflict.REJECT, dt, offset, null);
            Assert.fail('expected a missing time zone to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    // ---- resolveWith ------------------------------------------------------

    @IsTest
    static void exactComparisonRejectsAnOffsetRoundedToTheMinute() {
        // Monrovia was 44 minutes and 30 seconds behind UTC until 1972. A datetime string can
        // only say -00:45.
        JiffDateTime dt = JiffDateTime.newInstance(1970, 6, 1, 0, 0, 0, 0);
        JiffTimeZone tz = JiffTimeZone.get('Africa/Monrovia');
        JiffOffset written = JiffOffset.fromSeconds(-45 * 60);
        try {
            JiffOffsetConflicts.resolve(JiffOffsetConflict.REJECT, dt, written, tz);
            Assert.fail('expected -00:45 not to match -00:44:30 exactly');
        } catch (JiffException e) {
            Assert.areEqual(
                'datetime could not resolve to a timestamp since `reject` conflict ' +
                    'resolution was chosen, and because datetime has offset `-00:45`, but the ' +
                    'time zone `Africa/Monrovia` for the given datetime unambiguously has ' +
                    'offset `-00:44:30`',
                e.getMessage()
            );
        }
        // The other strategies never reject. Only ALWAYS_OFFSET believes the written offset.
        Assert.areEqual(
            '1970-06-01T00:00:30-00:45[Africa/Monrovia]',
            outcome(
                JiffOffsetConflict.ALWAYS_OFFSET,
                dt,
                written,
                tz,
                null,
                JiffDisambiguation.COMPATIBLE
            )
        );
        Assert.areEqual(
            '1970-06-01T00:00:00-00:45[Africa/Monrovia]',
            outcome(
                JiffOffsetConflict.ALWAYS_TIME_ZONE,
                dt,
                written,
                tz,
                null,
                JiffDisambiguation.COMPATIBLE
            )
        );
        Assert.areEqual(
            '1970-06-01T00:00:00-00:45[Africa/Monrovia]',
            outcome(
                JiffOffsetConflict.PREFER_OFFSET,
                dt,
                written,
                tz,
                null,
                JiffDisambiguation.COMPATIBLE
            )
        );
    }

    @IsTest
    static void aCustomComparisonCanAcceptARoundedOffset() {
        JiffDateTime dt = JiffDateTime.newInstance(1970, 6, 1, 0, 0, 0, 0);
        JiffTimeZone tz = JiffTimeZone.get('Africa/Monrovia');
        JiffOffset written = JiffOffset.fromSeconds(-45 * 60);
        JiffZonedDateTime zdt = JiffOffsetConflicts.resolveWith(
                JiffOffsetConflict.REJECT,
                dt,
                written,
                tz,
                new ToTheMinute()
            )
            .unambiguous();
        // Notice that the offset is the actual offset from the time zone:
        Assert.areEqual(JiffOffset.fromSeconds(-(44 * 60 + 30)), zdt.offset());
        Assert.areEqual(JiffTimestamp.fromSecond(13049070L), zdt.toTimestamp());
        // But when we print it, the offset gets rounded.
        Assert.areEqual('1970-06-01T00:00:00-00:45[Africa/Monrovia]', zdt.toString());

        // ALWAYS_OFFSET still takes the written offset at its word.
        Assert.areEqual(
            JiffTimestamp.fromSecond(13049100L),
            JiffOffsetConflicts.resolveWith(
                    JiffOffsetConflict.ALWAYS_OFFSET,
                    dt,
                    written,
                    tz,
                    new ToTheMinute()
                )
                .compatible()
                .toTimestamp()
        );
        for (
            JiffOffsetConflict strategy : new List<JiffOffsetConflict>{
                JiffOffsetConflict.ALWAYS_TIME_ZONE,
                JiffOffsetConflict.PREFER_OFFSET
            }
        ) {
            Assert.areEqual(
                JiffTimestamp.fromSecond(13049070L),
                JiffOffsetConflicts.resolveWith(strategy, dt, written, tz, new ToTheMinute())
                    .compatible()
                    .toTimestamp()
            );
        }
    }

    @IsTest
    static void aMatchInAFoldUsesTheGivenOffset() {
        // With a comparison that accepts anything, the given offset "matches" the fold and is
        // used as it stands.
        JiffDateTime inFold = JiffDateTime.newInstance(2024, 11, 3, 1, 30, 0, 0);
        Map<JiffOffsetConflict, String> expected = new Map<JiffOffsetConflict, String>{
            JiffOffsetConflict.ALWAYS_OFFSET => '2024-11-03T02:30:00-05:00[America/New_York]',
            JiffOffsetConflict.ALWAYS_TIME_ZONE => '2024-11-03T01:30:00-04:00[America/New_York]',
            JiffOffsetConflict.PREFER_OFFSET => '2024-11-03T02:30:00-05:00[America/New_York]',
            JiffOffsetConflict.REJECT => '2024-11-03T02:30:00-05:00[America/New_York]'
        };
        for (JiffOffsetConflict strategy : STRATEGIES) {
            Assert.areEqual(
                expected.get(strategy),
                outcome(
                    strategy,
                    inFold,
                    hours(-6),
                    NEW_YORK,
                    new Anything(),
                    JiffDisambiguation.COMPATIBLE
                ),
                strategy.name()
            );
        }
    }

    @IsTest
    static void noOffsetMatchesInAGap() {
        JiffDateTime inGap = JiffDateTime.newInstance(2024, 3, 10, 2, 30, 0, 0);
        Map<JiffOffsetConflict, String> expected = new Map<JiffOffsetConflict, String>{
            JiffOffsetConflict.ALWAYS_OFFSET => '2024-03-10T04:30:00-04:00[America/New_York]',
            JiffOffsetConflict.ALWAYS_TIME_ZONE => '2024-03-10T03:30:00-04:00[America/New_York]',
            JiffOffsetConflict.PREFER_OFFSET => '2024-03-10T03:30:00-04:00[America/New_York]',
            JiffOffsetConflict.REJECT => rejected(
                '-06',
                'falls in a gap (between offsets `-05` and `-04`), and all offsets for a gap ' +
                'are regarded as invalid'
            )
        };
        for (JiffOffsetConflict strategy : STRATEGIES) {
            Assert.areEqual(
                expected.get(strategy),
                outcome(
                    strategy,
                    inGap,
                    hours(-6),
                    NEW_YORK,
                    new Anything(),
                    JiffDisambiguation.COMPATIBLE
                ),
                strategy.name()
            );
        }
    }

    @IsTest
    static void anApproximateMatchKeepsTheZonesOffset() {
        // For an unambiguous datetime a match never replaces the time zone's own offset.
        JiffDateTime dt = JiffDateTime.newInstance(2024, 6, 14, 17, 30, 0, 0);
        Map<JiffOffsetConflict, String> expected = new Map<JiffOffsetConflict, String>{
            JiffOffsetConflict.ALWAYS_OFFSET => '2024-06-14T19:30:00-04:00[America/New_York]',
            JiffOffsetConflict.ALWAYS_TIME_ZONE => '2024-06-14T17:30:00-04:00[America/New_York]',
            JiffOffsetConflict.PREFER_OFFSET => '2024-06-14T17:30:00-04:00[America/New_York]',
            JiffOffsetConflict.REJECT => '2024-06-14T17:30:00-04:00[America/New_York]'
        };
        for (JiffOffsetConflict strategy : STRATEGIES) {
            Assert.areEqual(
                expected.get(strategy),
                outcome(
                    strategy,
                    dt,
                    hours(-6),
                    NEW_YORK,
                    new Anything(),
                    JiffDisambiguation.COMPATIBLE
                ),
                strategy.name()
            );
        }
    }
}
