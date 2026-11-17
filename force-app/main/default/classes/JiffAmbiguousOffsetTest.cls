@IsTest
private class JiffAmbiguousOffsetTest {
    private static final JiffOffset MINUS_FOUR = JiffOffset.fromHours(-4);
    private static final JiffOffset MINUS_FIVE = JiffOffset.fromHours(-5);

    @IsTest
    static void anUnambiguousOffsetHoldsOneOffset() {
        JiffAmbiguousOffset offset = JiffAmbiguousOffset.unambiguous(MINUS_FOUR);
        Assert.isTrue(offset.isUnambiguous());
        Assert.isFalse(offset.isGap());
        Assert.isFalse(offset.isFold());
        Assert.areEqual(MINUS_FOUR, offset.offset());
        Assert.isNull(offset.before());
        Assert.isNull(offset.after());
        Assert.areEqual('Unambiguous(-04)', offset.toString());
    }

    @IsTest
    static void aGapHoldsTheOffsetsEitherSideOfTheTransition() {
        JiffAmbiguousOffset offset = JiffAmbiguousOffset.gap(MINUS_FIVE, MINUS_FOUR);
        Assert.isFalse(offset.isUnambiguous());
        Assert.isTrue(offset.isGap());
        Assert.isFalse(offset.isFold());
        Assert.isNull(offset.offset());
        Assert.areEqual(MINUS_FIVE, offset.before());
        Assert.areEqual(MINUS_FOUR, offset.after());
        Assert.areEqual('Gap(-05, -04)', offset.toString());
    }

    @IsTest
    static void aFoldHoldsTheOffsetsEitherSideOfTheTransition() {
        JiffAmbiguousOffset offset = JiffAmbiguousOffset.fold(MINUS_FOUR, MINUS_FIVE);
        Assert.isFalse(offset.isUnambiguous());
        Assert.isFalse(offset.isGap());
        Assert.isTrue(offset.isFold());
        Assert.isNull(offset.offset());
        Assert.areEqual(MINUS_FOUR, offset.before());
        Assert.areEqual(MINUS_FIVE, offset.after());
        Assert.areEqual('Fold(-04, -05)', offset.toString());
    }

    @IsTest
    static void equalityComparesTheKindAndTheOffsets() {
        Assert.areEqual(
            JiffAmbiguousOffset.unambiguous(MINUS_FOUR),
            JiffAmbiguousOffset.unambiguous(JiffOffset.fromSeconds(-14400))
        );
        Assert.areEqual(
            JiffAmbiguousOffset.gap(MINUS_FIVE, MINUS_FOUR),
            JiffAmbiguousOffset.gap(MINUS_FIVE, MINUS_FOUR)
        );
        Assert.areEqual(
            JiffAmbiguousOffset.fold(MINUS_FOUR, MINUS_FIVE).hashCode(),
            JiffAmbiguousOffset.fold(MINUS_FOUR, MINUS_FIVE).hashCode()
        );
        Assert.areNotEqual(
            JiffAmbiguousOffset.unambiguous(MINUS_FOUR),
            JiffAmbiguousOffset.unambiguous(MINUS_FIVE)
        );
        // The same pair of offsets is a different thing as a gap and as a fold.
        Assert.areNotEqual(
            JiffAmbiguousOffset.gap(MINUS_FIVE, MINUS_FOUR),
            JiffAmbiguousOffset.fold(MINUS_FIVE, MINUS_FOUR)
        );
        Assert.areNotEqual(
            JiffAmbiguousOffset.gap(MINUS_FIVE, MINUS_FOUR),
            JiffAmbiguousOffset.gap(MINUS_FOUR, MINUS_FIVE)
        );
        Assert.areNotEqual(
            JiffAmbiguousOffset.gap(MINUS_FIVE, MINUS_FOUR),
            JiffAmbiguousOffset.gap(MINUS_FIVE, JiffOffset.UTC)
        );
        Assert.areNotEqual(
            JiffAmbiguousOffset.unambiguous(MINUS_FIVE),
            JiffAmbiguousOffset.gap(MINUS_FIVE, MINUS_FOUR)
        );
        Assert.isFalse(JiffAmbiguousOffset.unambiguous(MINUS_FIVE).equals(MINUS_FIVE));
    }

    @IsTest
    static void offsetsAreRequired() {
        JiffOffset missing = null;
        for (Integer attempt = 0; attempt < 5; attempt++) {
            try {
                if (attempt == 0) {
                    JiffAmbiguousOffset.unambiguous(missing);
                } else if (attempt == 1) {
                    JiffAmbiguousOffset.gap(missing, MINUS_FOUR);
                } else if (attempt == 2) {
                    JiffAmbiguousOffset.gap(MINUS_FIVE, missing);
                } else if (attempt == 3) {
                    JiffAmbiguousOffset.fold(missing, MINUS_FIVE);
                } else {
                    JiffAmbiguousOffset.fold(MINUS_FOUR, missing);
                }
                Assert.fail('expected a null offset to be rejected');
            } catch (JiffException e) {
                Assert.areEqual('an ambiguous offset cannot hold a null offset', e.getMessage());
            }
        }
    }
}
