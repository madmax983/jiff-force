@IsTest
private class JiffRoundTest {
    @IsTest
    static void defaultsLeaveAValueUnchanged() {
        JiffRound options = new JiffRound();
        Assert.areEqual(JiffUnit.NANOSECOND, options.getSmallest());
        Assert.areEqual(JiffRoundMode.HALF_EXPAND, options.getMode());
        Assert.areEqual(1L, options.getIncrement());
    }

    @IsTest
    static void settersReturnNewInstances() {
        JiffRound base = JiffRound.to(JiffUnit.MINUTE);
        JiffRound changed = base.increment(15).mode(JiffRoundMode.FLOOR).smallest(JiffUnit.SECOND);
        Assert.areEqual(JiffUnit.MINUTE, base.getSmallest());
        Assert.areEqual(1L, base.getIncrement());
        Assert.areEqual(JiffRoundMode.HALF_EXPAND, base.getMode());
        Assert.areEqual(JiffUnit.SECOND, changed.getSmallest());
        Assert.areEqual(15L, changed.getIncrement());
        Assert.areEqual(JiffRoundMode.FLOOR, changed.getMode());
    }

    @IsTest
    static void rejectsNullSettings() {
        try {
            new JiffRound().smallest(null);
            Assert.fail('expected a failure');
        } catch (JiffException e) {
            Assert.areEqual('smallest unit must not be null', e.getMessage());
        }
        try {
            new JiffRound().mode(null);
            Assert.fail('expected a failure');
        } catch (JiffException e) {
            Assert.areEqual('rounding mode must not be null', e.getMessage());
        }
    }
}
