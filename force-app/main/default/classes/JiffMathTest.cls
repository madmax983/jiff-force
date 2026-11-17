@IsTest
private class JiffMathTest {
    private static Boolean overflows(String op, Long a, Long b) {
        try {
            if (op == 'add') {
                JiffMath.checkedAdd(a, b, 'test');
            } else if (op == 'sub') {
                JiffMath.checkedSub(a, b, 'test');
            } else if (op == 'mul') {
                JiffMath.checkedMul(a, b, 'test');
            } else {
                JiffMath.checkedNeg(a, 'test');
            }
            return false;
        } catch (JiffException e) {
            Assert.areEqual('test overflowed', e.getMessage());
            return true;
        }
    }

    @IsTest
    static void floorDivisionRoundsTowardNegativeInfinity() {
        Assert.areEqual(2L, JiffMath.floorDiv(7L, 3L));
        Assert.areEqual(-3L, JiffMath.floorDiv(-7L, 3L));
        Assert.areEqual(-2L, JiffMath.floorDiv(-6L, 3L));
        Assert.areEqual(0L, JiffMath.floorDiv(0L, 3L));
        Assert.areEqual(1L, JiffMath.floorMod(7L, 3L));
        Assert.areEqual(2L, JiffMath.floorMod(-7L, 3L));
        Assert.areEqual(0L, JiffMath.floorMod(-6L, 3L));
        Assert.areEqual(-1L, JiffMath.truncMod(-7L, 3L));
        Assert.areEqual(1L, JiffMath.truncMod(7L, -3L));
        // -1 second before the epoch is the last second of the previous day.
        Assert.areEqual(-1L, JiffMath.floorDiv(-1L, 86400L));
        Assert.areEqual(86399L, JiffMath.floorMod(-1L, 86400L));
    }

    @IsTest
    static void checkedAdditionDetectsOverflowAtBothEnds() {
        Assert.areEqual(JiffMath.LONG_MAX, JiffMath.checkedAdd(JiffMath.LONG_MAX - 1, 1L, 'test'));
        Assert.areEqual(JiffMath.LONG_MIN, JiffMath.checkedAdd(JiffMath.LONG_MIN + 1, -1L, 'test'));
        Assert.areEqual(-1L, JiffMath.checkedAdd(JiffMath.LONG_MAX, JiffMath.LONG_MIN, 'test'));
        Assert.isTrue(overflows('add', JiffMath.LONG_MAX, 1L));
        Assert.isTrue(overflows('add', JiffMath.LONG_MIN, -1L));
        Assert.isTrue(overflows('add', JiffMath.LONG_MIN, JiffMath.LONG_MIN));
    }

    @IsTest
    static void checkedSubtractionDetectsOverflowAtBothEnds() {
        Assert.areEqual(JiffMath.LONG_MIN, JiffMath.checkedSub(JiffMath.LONG_MIN + 1, 1L, 'test'));
        Assert.areEqual(JiffMath.LONG_MAX, JiffMath.checkedSub(JiffMath.LONG_MAX - 1, -1L, 'test'));
        Assert.areEqual(0L, JiffMath.checkedSub(JiffMath.LONG_MIN, JiffMath.LONG_MIN, 'test'));
        Assert.isTrue(overflows('sub', JiffMath.LONG_MIN, 1L));
        Assert.isTrue(overflows('sub', JiffMath.LONG_MAX, -1L));
        Assert.isTrue(overflows('sub', 0L, JiffMath.LONG_MIN));
    }

    @IsTest
    static void checkedMultiplicationDetectsOverflowWithoutWrapping() {
        Assert.areEqual(0L, JiffMath.checkedMul(0L, JiffMath.LONG_MIN, 'test'));
        Assert.areEqual(JiffMath.LONG_MIN, JiffMath.checkedMul(JiffMath.LONG_MIN, 1L, 'test'));
        Assert.areEqual(JiffMath.LONG_MIN, JiffMath.checkedMul(1L, JiffMath.LONG_MIN, 'test'));
        Assert.areEqual(JiffMath.LONG_MIN, JiffMath.checkedMul(-4611686018427387904L, 2L, 'test'));
        Assert.areEqual(JiffMath.LONG_MIN, JiffMath.checkedMul(4611686018427387904L, -2L, 'test'));
        Assert.areEqual(
            9223372036854775806L,
            JiffMath.checkedMul(4611686018427387903L, 2L, 'test')
        );
        Assert.areEqual(
            9223372036854775806L,
            JiffMath.checkedMul(-4611686018427387903L, -2L, 'test')
        );
        Assert.isTrue(overflows('mul', 4611686018427387904L, 2L));
        Assert.isTrue(overflows('mul', -4611686018427387904L, -2L));
        Assert.isTrue(overflows('mul', -4611686018427387905L, 2L));
        Assert.isTrue(overflows('mul', JiffMath.LONG_MIN, -1L));
        Assert.isTrue(overflows('mul', -1L, JiffMath.LONG_MIN));
        Assert.isTrue(overflows('mul', JiffMath.LONG_MAX, JiffMath.LONG_MAX));
        Assert.isTrue(overflows('mul', 3037000500L, 3037000500L));
        Assert.areEqual(
            9223372030926249001L,
            JiffMath.checkedMul(3037000499L, 3037000499L, 'test')
        );
    }

    @IsTest
    static void checkedNegationRejectsTheMinimum() {
        Assert.areEqual(-JiffMath.LONG_MAX, JiffMath.checkedNeg(JiffMath.LONG_MAX, 'test'));
        Assert.isTrue(overflows('neg', JiffMath.LONG_MIN, 0L));
    }

    @IsTest
    static void rangeChecksUseJiffsWording() {
        Assert.areEqual(31L, JiffMath.check(31L, 1L, 31L, 'day'));
        Assert.areEqual(1, JiffMath.checkInt(1L, 1L, 31L, 'day'));
        for (Long bad : new List<Long>{ 0L, 32L }) {
            try {
                JiffMath.check(bad, 1L, 31L, 'day');
                Assert.fail('expected a range error');
            } catch (JiffException e) {
                Assert.areEqual(
                    'parameter \'day\' is not in the required range of 1..=31',
                    e.getMessage()
                );
            }
        }
    }

    @IsTest
    static void knowsTheLengthAndOrderOfUnits() {
        Assert.areEqual(1L, JiffMath.nanosPerUnit(JiffUnit.NANOSECOND));
        Assert.areEqual(1000L, JiffMath.nanosPerUnit(JiffUnit.MICROSECOND));
        Assert.areEqual(1000000L, JiffMath.nanosPerUnit(JiffUnit.MILLISECOND));
        Assert.areEqual(1000000000L, JiffMath.nanosPerUnit(JiffUnit.SECOND));
        Assert.areEqual(60000000000L, JiffMath.nanosPerUnit(JiffUnit.MINUTE));
        Assert.areEqual(3600000000000L, JiffMath.nanosPerUnit(JiffUnit.HOUR));
        Assert.areEqual(86400000000000L, JiffMath.nanosPerUnit(JiffUnit.DAY));
        Assert.areEqual(604800000000000L, JiffMath.nanosPerUnit(JiffUnit.WEEK));
        try {
            JiffMath.nanosPerUnit(JiffUnit.MONTH);
            Assert.fail('expected a failure');
        } catch (JiffException e) {
            Assert.areEqual('unit \'month\' does not have a fixed length', e.getMessage());
        }
        Assert.areEqual('year', JiffMath.singular(JiffUnit.YEAR));
        Assert.areEqual('nanoseconds', JiffMath.plural(JiffUnit.NANOSECOND));
        Assert.isTrue(JiffMath.isLarger(JiffUnit.YEAR, JiffUnit.MONTH));
        Assert.isFalse(JiffMath.isLarger(JiffUnit.DAY, JiffUnit.DAY));
        Assert.isTrue(JiffMath.isCalendar(JiffUnit.DAY));
        Assert.isFalse(JiffMath.isCalendar(JiffUnit.HOUR));
        Assert.areEqual(JiffUnit.WEEK, JiffMath.largerOf(JiffUnit.WEEK, JiffUnit.DAY));
        Assert.areEqual(JiffUnit.DAY, JiffMath.smallerOf(JiffUnit.WEEK, JiffUnit.DAY));
    }

    @IsTest
    static void smallHelpersBehave() {
        Assert.areEqual(5L, JiffMath.abs(-5L));
        Assert.areEqual(-1, JiffMath.signum(-5L));
        Assert.areEqual(0, JiffMath.signum(0L));
        Assert.areEqual(1, JiffMath.signum(5L));
        Assert.areEqual(-1, JiffMath.compare(1L, 2L));
        Assert.areEqual(0, JiffMath.compare(2L, 2L));
        Assert.areEqual(1, JiffMath.compare(3L, 2L));
        Assert.areEqual('0007', JiffMath.pad(7L, 4));
        Assert.areEqual('12345', JiffMath.pad(12345L, 4));
        Assert.areEqual(2147483647, JiffMath.INT_MAX);
        Assert.areEqual(-2147483647 - 1, JiffMath.INT_MIN);
    }
}
