/**
 * `JiffPiecesOffset`: the offset of a datetime string, which is `Z` or numeric.
 *
 * The cases are the examples in the doc comments of `jiff::fmt::temporal::PiecesOffset` and
 * `Pieces::offset` (`fmt/temporal/pieces.rs`), and the printed forms are what Jiff 1.0.0
 * prints for the same offset in a `Pieces`.
 */
@IsTest
private class JiffPiecesOffsetTest {
    @IsTest
    static void zuluIsUtcWithNoNumericForm() {
        // The example on `PiecesOffset::to_numeric_offset`.
        JiffPiecesOffset off = JiffPieces.parse('1970-01-01T00:00:00Z').offset();
        Assert.areEqual(JiffPiecesOffset.ZULU, off);
        Assert.isTrue(off.isZulu());
        Assert.isNull(off.asNumeric());
        Assert.areEqual(JiffOffset.UTC, off.toNumericOffset());
        Assert.areEqual('Z', off.toString());
    }

    @IsTest
    static void negativeAndPositiveZeroBothConvertToUtc() {
        // The example on `PiecesOffset::to_numeric_offset`, continued.
        JiffPiecesOffset negative = JiffPieces.parse('1970-01-01T00:00:00-00:00').offset();
        Assert.areEqual(
            JiffPiecesOffset.fromNumeric(
                JiffPiecesNumericOffset.fromOffset(JiffOffset.UTC).withNegativeZero()
            ),
            negative
        );
        Assert.isFalse(negative.isZulu());
        Assert.areEqual(JiffOffset.UTC, negative.toNumericOffset());
        Assert.areEqual('-00:00', negative.toString());

        JiffPiecesOffset positive = JiffPieces.parse('1970-01-01T00:00:00+00:00').offset();
        Assert.areEqual(JiffPiecesOffset.fromOffset(JiffOffset.UTC), positive);
        Assert.areEqual(JiffOffset.UTC, positive.toNumericOffset());
        Assert.areEqual('+00:00', positive.toString());
    }

    @IsTest
    static void aNumericOffsetIsReturnedAsItIs() {
        JiffOffset minusFive = JiffOffset.fromHours(-5);
        JiffPiecesOffset off = JiffPiecesOffset.fromOffset(minusFive);
        Assert.isFalse(off.isZulu());
        Assert.areEqual(minusFive, off.toNumericOffset());
        Assert.areEqual(JiffPiecesNumericOffset.fromOffset(minusFive), off.asNumeric());
        Assert.areEqual('-05:00', off.toString());
        // `From<Offset>` and `From<PiecesNumericOffset>` agree.
        Assert.areEqual(
            JiffPiecesOffset.fromNumeric(JiffPiecesNumericOffset.fromOffset(minusFive)),
            off
        );
    }

    @IsTest
    static void equalityTellsZuluNegativeZeroAndPositiveZeroApart() {
        JiffPiecesOffset positive = JiffPiecesOffset.fromOffset(JiffOffset.UTC);
        JiffPiecesOffset negative = JiffPiecesOffset.fromNumeric(
            JiffPiecesNumericOffset.fromOffset(JiffOffset.UTC).withNegativeZero()
        );
        Assert.areNotEqual(JiffPiecesOffset.ZULU, positive);
        Assert.areNotEqual(positive, JiffPiecesOffset.ZULU);
        Assert.areNotEqual(JiffPiecesOffset.ZULU, negative);
        Assert.areNotEqual(positive, negative);
        Assert.areEqual(positive, JiffPiecesOffset.fromOffset(JiffOffset.ZERO));
        Assert.areEqual(
            positive.hashCode(),
            JiffPiecesOffset.fromOffset(JiffOffset.ZERO).hashCode()
        );
        Assert.areEqual(JiffPiecesOffset.ZULU.hashCode(), JiffPiecesOffset.ZULU.hashCode());
        Assert.isTrue(JiffPiecesOffset.ZULU.equals(JiffPiecesOffset.ZULU));
        Assert.isFalse(JiffPiecesOffset.ZULU.equals(JiffOffset.UTC));
        Assert.isFalse(positive.equals(null));
    }

    @IsTest
    static void aNumericOffsetIsRequired() {
        try {
            JiffPiecesOffset.fromNumeric(null);
            Assert.fail('expected a missing numeric offset to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('a numeric pieces offset needs an offset', e.getMessage());
        }
        try {
            JiffPiecesOffset.fromOffset(null);
            Assert.fail('expected a missing offset to be rejected');
        } catch (JiffException e) {
            Assert.areEqual('a numeric offset needs an offset', e.getMessage());
        }
    }
}
