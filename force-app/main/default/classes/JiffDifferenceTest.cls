@IsTest
private class JiffDifferenceTest {
    @IsTest
    static void defaultsToTruncationWithNoUnitsChosen() {
        JiffDifference options = new JiffDifference();
        Assert.isNull(options.getSmallest());
        Assert.isNull(options.getLargest());
        Assert.areEqual(JiffRoundMode.TRUNC, options.getMode());
        Assert.areEqual(1L, options.getIncrement());
    }

    @IsTest
    static void settersReturnNewInstances() {
        JiffDifference base = new JiffDifference();
        JiffDifference changed = base.smallest(JiffUnit.MINUTE)
            .largest(JiffUnit.DAY)
            .mode(JiffRoundMode.HALF_EVEN)
            .increment(30);
        Assert.isNull(base.getSmallest());
        Assert.areEqual(JiffUnit.MINUTE, changed.getSmallest());
        Assert.areEqual(JiffUnit.DAY, changed.getLargest());
        Assert.areEqual(JiffRoundMode.HALF_EVEN, changed.getMode());
        Assert.areEqual(30L, changed.getIncrement());
        Assert.isNull(changed.largest(null).getLargest());
        Assert.isNull(changed.smallest(null).getSmallest());
    }

    @IsTest
    static void rejectsANullMode() {
        try {
            new JiffDifference().mode(null);
            Assert.fail('expected a failure');
        } catch (JiffException e) {
            Assert.areEqual('rounding mode must not be null', e.getMessage());
        }
    }
}
