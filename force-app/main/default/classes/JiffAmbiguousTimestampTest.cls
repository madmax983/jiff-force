/**
 * These tests build the ambiguous offsets by hand, using the offsets Jiff reports for
 * `America/New_York` in 2024, so that they do not depend on the platform's zone data.
 * `JiffTimeZoneTest` covers producing them from a time zone.
 */
@IsTest
private class JiffAmbiguousTimestampTest {
    private static final JiffOffset EDT = JiffOffset.fromHours(-4);
    private static final JiffOffset EST = JiffOffset.fromHours(-5);

    private static JiffDateTime dt(
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        Integer minute
    ) {
        return JiffDateTime.newInstance(year, month, day, hour, minute, 0, 0);
    }

    /** 17:30 on a summer afternoon: happens once. */
    private static JiffAmbiguousTimestamp plain() {
        return JiffAmbiguousTimestamp.newInstance(
            dt(2024, 7, 15, 17, 30),
            JiffAmbiguousOffset.unambiguous(EDT)
        );
    }

    /** 02:30 on the morning clocks spring forward: never happens. */
    private static JiffAmbiguousTimestamp gap() {
        return JiffAmbiguousTimestamp.newInstance(
            dt(2024, 3, 10, 2, 30),
            JiffAmbiguousOffset.gap(EST, EDT)
        );
    }

    /** 01:30 on the morning clocks fall back: happens twice. */
    private static JiffAmbiguousTimestamp fold() {
        return JiffAmbiguousTimestamp.newInstance(
            dt(2024, 11, 3, 1, 30),
            JiffAmbiguousOffset.fold(EDT, EST)
        );
    }

    @IsTest
    static void exposesTheDateTimeAndTheOffsets() {
        Assert.areEqual(dt(2024, 7, 15, 17, 30), plain().toDateTime());
        Assert.areEqual(JiffAmbiguousOffset.unambiguous(EDT), plain().offset());
        Assert.areEqual(JiffAmbiguousOffset.gap(EST, EDT), gap().offset());
        Assert.areEqual(JiffAmbiguousOffset.fold(EDT, EST), fold().offset());
    }

    @IsTest
    static void onlyGapsAndFoldsAreAmbiguous() {
        Assert.isFalse(plain().isAmbiguous());
        Assert.isTrue(gap().isAmbiguous());
        Assert.isTrue(fold().isAmbiguous());
    }

    @IsTest
    static void compatiblePicksLaterInAGapAndEarlierInAFold() {
        Assert.areEqual('2024-07-15T21:30:00Z', plain().compatible().toString());
        Assert.areEqual('2024-03-10T07:30:00Z', gap().compatible().toString());
        Assert.areEqual('2024-11-03T05:30:00Z', fold().compatible().toString());
    }

    @IsTest
    static void earlierPicksTheEarlierInstant() {
        Assert.areEqual('2024-07-15T21:30:00Z', plain().earlier().toString());
        Assert.areEqual('2024-03-10T06:30:00Z', gap().earlier().toString());
        Assert.areEqual('2024-11-03T05:30:00Z', fold().earlier().toString());
    }

    @IsTest
    static void laterPicksTheLaterInstant() {
        Assert.areEqual('2024-07-15T21:30:00Z', plain().later().toString());
        Assert.areEqual('2024-03-10T07:30:00Z', gap().later().toString());
        Assert.areEqual('2024-11-03T06:30:00Z', fold().later().toString());
    }

    @IsTest
    static void unambiguousRefusesToChoose() {
        Assert.areEqual('2024-07-15T21:30:00Z', plain().unambiguous().toString());
        try {
            gap().unambiguous();
            Assert.fail('expected a gap to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'datetime is ambiguous since it falls into a gap between offsets -05 and -04',
                e.getMessage()
            );
        }
        try {
            fold().unambiguous();
            Assert.fail('expected a fold to be rejected');
        } catch (JiffException e) {
            Assert.areEqual(
                'datetime is ambiguous since it falls into a fold between offsets -04 and -05',
                e.getMessage()
            );
        }
    }

    @IsTest
    static void disambiguateAppliesTheNamedStrategy() {
        JiffAmbiguousTimestamp ambiguous = fold();
        Assert.areEqual(
            '2024-11-03T05:30:00Z',
            ambiguous.disambiguate(JiffDisambiguation.COMPATIBLE).toString()
        );
        Assert.areEqual(
            '2024-11-03T05:30:00Z',
            ambiguous.disambiguate(JiffDisambiguation.EARLIER).toString()
        );
        Assert.areEqual(
            '2024-11-03T06:30:00Z',
            ambiguous.disambiguate(JiffDisambiguation.LATER).toString()
        );
        try {
            ambiguous.disambiguate(JiffDisambiguation.REJECT);
            Assert.fail('expected the reject strategy to throw for a fold');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('falls into a fold'), e.getMessage());
        }
        Assert.areEqual(
            '2024-03-10T07:30:00Z',
            gap().disambiguate(JiffDisambiguation.COMPATIBLE).toString()
        );
        Assert.areEqual(
            '2024-03-10T06:30:00Z',
            gap().disambiguate(JiffDisambiguation.EARLIER).toString()
        );
        Assert.areEqual(
            '2024-07-15T21:30:00Z',
            plain().disambiguate(JiffDisambiguation.REJECT).toString()
        );
        Assert.areEqual(
            new List<JiffDisambiguation>{
                JiffDisambiguation.COMPATIBLE,
                JiffDisambiguation.EARLIER,
                JiffDisambiguation.LATER,
                JiffDisambiguation.REJECT
            },
            JiffDisambiguation.values()
        );
        try {
            JiffDisambiguation missing = null;
            ambiguous.disambiguate(missing);
            Assert.fail('expected a null strategy to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('disambiguation strategy must not be null', e.getMessage());
        }
    }

    @IsTest
    static void aChosenInstantCanStillBeOutOfRange() {
        JiffAmbiguousTimestamp atTheEnd = JiffAmbiguousTimestamp.newInstance(
            JiffDateTime.MAX,
            JiffAmbiguousOffset.unambiguous(EST)
        );
        String expected =
            'converting datetime with time zone offset `-05` to timestamp overflowed: ' +
            'parameter \'Unix timestamp seconds\' is not in the required range of ' +
            '-377705023201..=253402207200';
        for (JiffDisambiguation option : JiffDisambiguation.values()) {
            try {
                atTheEnd.disambiguate(option);
                Assert.fail('expected an overflow with ' + option);
            } catch (JiffException e) {
                Assert.areEqual(expected, e.getMessage());
            }
        }
    }

    @IsTest
    static void equalityComparesTheDateTimeAndTheOffsets() {
        Assert.areEqual(fold(), fold());
        Assert.areEqual(fold().hashCode(), fold().hashCode());
        Assert.areNotEqual(fold(), gap());
        Assert.areNotEqual(
            fold(),
            JiffAmbiguousTimestamp.newInstance(
                dt(2024, 11, 3, 1, 31),
                JiffAmbiguousOffset.fold(EDT, EST)
            )
        );
        Assert.areNotEqual(
            fold(),
            JiffAmbiguousTimestamp.newInstance(
                dt(2024, 11, 3, 1, 30),
                JiffAmbiguousOffset.unambiguous(EDT)
            )
        );
        Assert.isFalse(fold().equals(dt(2024, 11, 3, 1, 30)));
        Assert.areEqual('2024-11-03T01:30:00 Fold(-04, -05)', fold().toString());
        Assert.areEqual('2024-07-15T17:30:00 Unambiguous(-04)', plain().toString());
    }

    @IsTest
    static void bothPartsAreRequired() {
        try {
            JiffAmbiguousTimestamp.newInstance(null, JiffAmbiguousOffset.unambiguous(EDT));
            Assert.fail('expected a null datetime to be rejected');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('needs both'), e.getMessage());
        }
        try {
            JiffAmbiguousTimestamp.newInstance(dt(2024, 7, 15, 17, 30), null);
            Assert.fail('expected a null offset to be rejected');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('needs both'), e.getMessage());
        }
    }
}
