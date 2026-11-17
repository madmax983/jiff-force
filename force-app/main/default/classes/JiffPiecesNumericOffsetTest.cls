/**
 * `JiffPiecesNumericOffset`: an offset together with the sign it was written with.
 *
 * The parsing cases are the examples in the doc comments of
 * `jiff::fmt::temporal::PiecesNumericOffset` (`fmt/temporal/pieces.rs`). The printed forms are
 * what Jiff 1.0.0 prints for the same offset in a `Pieces`.
 */
@IsTest
private class JiffPiecesNumericOffsetTest {
    @IsTest
    static void aParsedOffsetExposesItsNumericValue() {
        // The example on `PiecesNumericOffset::offset`.
        JiffPiecesNumericOffset off = JiffPieces.parse('1970-01-01T00:00:00-05:30')
            .offset()
            .asNumeric();
        Assert.areEqual(JiffOffset.fromSeconds(-5 * 60 * 60 - 30 * 60), off.offset());
        Assert.isTrue(off.isNegative());
    }

    @IsTest
    static void negativeZeroKeepsItsSign() {
        // The example on `PiecesNumericOffset::is_negative`.
        JiffPiecesNumericOffset off = JiffPieces.parse('1970-01-01T00:00:00-00:00')
            .offset()
            .asNumeric();
        // The numeric offset is indistinguishable from UTC.
        Assert.areEqual(JiffOffset.UTC, off.offset());
        // This is where `isNegative` comes in handy.
        Assert.isTrue(off.isNegative());
    }

    @IsTest
    static void anOffsetConvertedDirectlyTakesItsOwnSign() {
        // "When using the `From<Offset>` trait implementation for this type, `is_negative` is
        // always set to `false` when the offset is zero."
        Assert.isFalse(JiffPiecesNumericOffset.fromOffset(JiffOffset.UTC).isNegative());
        Assert.isFalse(JiffPiecesNumericOffset.fromOffset(JiffOffset.fromHours(5)).isNegative());
        Assert.isTrue(JiffPiecesNumericOffset.fromOffset(JiffOffset.fromHours(-5)).isNegative());
        Assert.isTrue(JiffPiecesNumericOffset.fromOffset(JiffOffset.fromSeconds(-1)).isNegative());
    }

    @IsTest
    static void withNegativeZeroOnlyChangesHowZeroIsPrinted() {
        JiffPiecesNumericOffset zero = JiffPiecesNumericOffset.fromOffset(JiffOffset.UTC);
        Assert.areEqual('+00:00', zero.toString());
        Assert.areEqual('-00:00', zero.withNegativeZero().toString());
        Assert.areEqual(JiffOffset.UTC, zero.withNegativeZero().offset());
        // For any other offset the sign printed is the offset's own.
        JiffPiecesNumericOffset plus = JiffPiecesNumericOffset.fromOffset(JiffOffset.fromHours(5));
        Assert.areEqual('+05:00', plus.toString());
        Assert.areEqual('+05:00', plus.withNegativeZero().toString());
        Assert.isTrue(plus.withNegativeZero().isNegative());
        Assert.areEqual(
            '-05:30',
            JiffPiecesNumericOffset.fromOffset(JiffOffset.fromSeconds(-19800)).toString()
        );
    }

    @IsTest
    static void equalityCoversTheOffsetAndTheWrittenSign() {
        JiffPiecesNumericOffset zero = JiffPiecesNumericOffset.fromOffset(JiffOffset.UTC);
        Assert.areEqual(zero, JiffPiecesNumericOffset.fromOffset(JiffOffset.ZERO));
        Assert.areEqual(
            zero.hashCode(),
            JiffPiecesNumericOffset.fromOffset(JiffOffset.ZERO).hashCode()
        );
        Assert.areNotEqual(zero, zero.withNegativeZero());
        Assert.areEqual(zero.withNegativeZero(), zero.withNegativeZero());
        Assert.areNotEqual(zero, JiffPiecesNumericOffset.fromOffset(JiffOffset.fromHours(1)));
        Assert.isFalse(zero.equals(JiffOffset.UTC));
        Assert.isFalse(zero.equals(null));
    }

    @IsTest
    static void anOffsetIsRequired() {
        try {
            JiffPiecesNumericOffset.fromOffset(null);
            Assert.fail('expected a missing offset to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('a numeric offset needs an offset', e.getMessage());
        }
    }
}
