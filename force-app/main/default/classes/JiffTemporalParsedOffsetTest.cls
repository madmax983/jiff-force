/**
 * `JiffTemporalParsedOffset`: an offset as written, and its conversion to a `JiffOffset`.
 *
 * The rounding cases are `err_numeric_too_big_for_offset` and
 * `err_numeric_too_small_for_offset` in the `#[cfg(test)]` module of Jiff's `fmt/offset.rs`.
 * The parsed strings and their offsets in seconds are what Jiff 1.0.0 reports for the same
 * strings through `Pieces::parse` (see `JiffPiecesTest`), and the written forms are what its
 * "unparsed input remains" error echoes.
 */
@IsTest
private class JiffTemporalParsedOffsetTest {
    private static JiffTemporalParsedOffset parse(String text) {
        JiffDurationScanner scanner = new JiffDurationScanner(text);
        JiffTemporalParsedOffset parsed = new JiffTemporalOffsetParser().parse(scanner);
        Assert.isTrue(scanner.isDone(), text);
        return parsed;
    }

    private static JiffTemporalParsedOffset maximal(Boolean negative, Integer nanoseconds) {
        return JiffTemporalParsedOffset.numeric(negative, 25)
            .withMinutes(59)
            .withSeconds(59)
            .withNanoseconds(nanoseconds);
    }

    @IsTest
    static void aFractionJustUnderHalfASecondKeepsTheLargestOffsetInRange() {
        Assert.areEqual(JiffOffset.MAX, maximal(false, 499999999).toOffset());
        Assert.areEqual(JiffOffset.MIN, maximal(true, 499999999).toOffset());
    }

    @IsTest
    static void aFractionOfHalfASecondRoundsTheLargestOffsetOutOfRange() {
        for (Boolean negative : new List<Boolean>{ false, true }) {
            try {
                maximal(negative, 500000000).toOffset();
                Assert.fail('expected the rounded offset to be out of range');
            } catch (JiffException e) {
                Assert.areEqual(
                    'due to precision loss from fractional seconds, ' +
                    'time zone offset is rounded to a value that is out of bounds',
                    e.getMessage()
                );
            }
            try {
                maximal(negative, 500000000).toPiecesOffset();
                Assert.fail('expected the rounded offset to be out of range');
            } catch (JiffException e) {
                Assert.isTrue(e.getMessage().startsWith('due to precision loss'), e.getMessage());
            }
        }
    }

    @IsTest
    static void aParsedOffsetConvertsToSecondsRoundingAFractionHalfAwayFromZero() {
        // `input => seconds`, as Jiff reports them for `2025-01-03T17:28<input>`.
        List<String> rows = new List<String>{
            'Z => 0',
            'z => 0',
            '-05 => -18000',
            '+05 => 18000',
            '-0530 => -19800',
            '+05:30 => 19800',
            '+00:00 => 0',
            '-00:00 => 0',
            '-00:00:00.0 => 0',
            '+00:00:00.499999999 => 0',
            '+00:00:00.5 => 1',
            '-00:00:00.499999999 => 0',
            '-00:00:00.5 => -1',
            '+05:30:15 => 19815',
            '-05:30:15.5 => -19816',
            '-05:30:15,499 => -19815',
            '+25:59:59.4 => 93599',
            '-25:59:59 => -93599'
        };
        for (String row : rows) {
            Integer at = row.indexOf(' => ');
            Assert.areEqual(
                row.substring(at + 4),
                String.valueOf(parse(row.substring(0, at)).toOffset().seconds()),
                row
            );
        }
    }

    @IsTest
    static void theWrittenFormIsEchoedWithTheComponentsThatWerePresent() {
        // `input => echoed`, as in Jiff's "parsed value '2024-06-19T15:22:45<echoed>', but
        // unparsed input remains" error for `2024-06-19T15:22:45<input>junk`.
        List<String> rows = new List<String>{
            'Z => Z',
            'z => Z',
            '-04 => -04',
            '+04:00 => +04:00',
            '-0430 => -04:30',
            '-04:30:15.25 => -04:30:15.25',
            '+255959,999 => +25:59:59.999',
            '-00:00 => -00:00',
            '+00:00:00 => +00:00:00',
            '+01:02:03.000000001 => +01:02:03.000000001',
            '+01:02:03.0 => +01:02:03'
        };
        for (String row : rows) {
            Integer at = row.indexOf(' => ');
            Assert.areEqual(row.substring(at + 4), parse(row.substring(0, at)).toString(), row);
        }
    }

    @IsTest
    static void aComponentSetWithoutTheOnesBeforeItIsEchoedWithZeros() {
        // The parser never produces these, but Jiff's `Display` for a numeric offset allows
        // for them: seconds or a fraction without the components before them are written
        // after `:00` placeholders (`impl Display for Numeric` in `fmt/offset.rs`).
        Assert.areEqual(
            '+05:00:07',
            JiffTemporalParsedOffset.numeric(false, 5).withSeconds(7).toString()
        );
        Assert.areEqual(
            '-05:00:00.5',
            JiffTemporalParsedOffset.numeric(true, 5).withNanoseconds(500000000).toString()
        );
        Assert.areEqual(
            '+05:30:00.25',
            JiffTemporalParsedOffset.numeric(false, 5)
                .withMinutes(30)
                .withNanoseconds(250000000)
                .toString()
        );
        Assert.areEqual(
            18007,
            JiffTemporalParsedOffset.numeric(false, 5).withSeconds(7).toOffset().seconds()
        );
    }

    @IsTest
    static void zuluAndTheWrittenSignAreRemembered() {
        JiffTemporalParsedOffset zulu = JiffTemporalParsedOffset.zulu();
        Assert.isTrue(zulu.isZulu());
        Assert.isFalse(zulu.isNegative());
        Assert.isFalse(zulu.hasSubminute());
        Assert.areEqual(JiffOffset.UTC, zulu.toOffset());
        Assert.areEqual('Z', zulu.toString());

        Assert.isFalse(parse('-00:00').isZulu());
        Assert.isTrue(parse('-00:00').isNegative());
        Assert.isFalse(parse('+00:00').isNegative());
        Assert.isTrue(parse('-05').isNegative());
    }

    @IsTest
    static void hasSubminuteIsTrueOnlyWhenSecondsWereWritten() {
        Assert.isFalse(parse('+05').hasSubminute());
        Assert.isFalse(parse('+05:30').hasSubminute());
        Assert.isFalse(parse('+0530').hasSubminute());
        // Explicit seconds count even when they are zero.
        Assert.isTrue(parse('+05:30:00').hasSubminute());
        Assert.isTrue(parse('+053000').hasSubminute());
        Assert.isTrue(parse('+05:30:15.5').hasSubminute());
        Assert.isFalse(parse('Z').hasSubminute());
    }

    @IsTest
    static void toPiecesOffsetKeepsZuluAndNegativeZeroApartFromPositiveZero() {
        // `Z`, `-00:00` and `+00:00` as `Pieces::parse` reports their offsets in Jiff.
        Assert.areEqual(JiffPiecesOffset.ZULU, parse('Z').toPiecesOffset());
        Assert.areEqual(
            JiffPiecesOffset.fromNumeric(
                JiffPiecesNumericOffset.fromOffset(JiffOffset.UTC).withNegativeZero()
            ),
            parse('-00:00').toPiecesOffset()
        );
        Assert.areEqual(
            JiffPiecesOffset.fromOffset(JiffOffset.UTC),
            parse('+00:00').toPiecesOffset()
        );
        Assert.areEqual(
            JiffPiecesOffset.fromOffset(JiffOffset.fromSeconds(-19800)),
            parse('-05:30').toPiecesOffset()
        );
        // `-00:00:00.5` rounds to one second west and stays negative.
        Assert.areEqual(
            JiffPiecesOffset.fromOffset(JiffOffset.fromSeconds(-1)),
            parse('-00:00:00.5').toPiecesOffset()
        );
    }
}
