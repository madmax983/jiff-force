@IsTest
private class JiffI128Test {
    // Each row is: seconds|nanos|factor|divisorSeconds|divisorNanos|value|value*factor|quotient|remainder
    // where value = seconds * 10^9 + nanos and the divisor is built the same way. The expected
    // columns were produced with arbitrary precision integers.
    private static final List<String> VECTORS = new List<String>{
        '999999999|-700344587|1|0|1|999999998299655413|999999998299655413|999999998299655413|0',
        '9223372036854775807|1|1000|2808074611646|500000000|9223372036854775807000000001|9223372036854775807000000001000|3284589|1056261410018500000001',
        '999999999999999999|-1|1000|765180|0|999999999999999998999999999|999999999999999998999999999000|1306882040826|761318999999999',
        '211519221736|-999999999|1000000000|1|1|211519221735000000001|211519221735000000001000000000|211519221523|480778478',
        '1000000000|-26308790|1000000000|3600|500000000|999999999973691210|999999999973691210000000000|277739|730473691210',
        '-448|374389013|7|0|1|-447625610987|-3133379276909|-447625610987|0',
        '-568|218009888|7|414851|500000000|-567781990112|-3974473930784|0|-567781990112',
        '-123|999999999|7|1|0|-122000000001|-854000000007|-122|-1',
        '86400000000000|-999999999|-1000000000|86400|0|86399999999999000000001|-86399999999999000000001000000000|999999999|86399000000001',
        '4071599007773167015|-426997275|1|165841|500000000|4071599007773167014573002725|4071599007773167014573002725|24551146774318|108417573002725',
        '-1|-999999999|0|0|500000000|-1999999999|0|-3|-499999999',
        '-9223372036854775808|1|7|604800|470406376|-9223372036854775807999999999|-64563604257983430655999999993|-15250272590987|-375669675066887',
        '-9223372036854775808|1|7|0|1|-9223372036854775807999999999|-64563604257983430655999999993|-9223372036854775807999999999|0',
        '86400000000000|-1|-1000000000|1|65082363|86399999999999999999999|-86399999999999999999999000000000|81120487017209|216615132',
        '-1000000000000000000|999999999|1000|1|0|-999999999999999999000000001|-999999999999999999000000001000|-999999999999999999|-1',
        '-457|999999999|-1000000000|694023|1|-456000000001|456000000001000000000|0|-456000000001',
        '29|-999999999|0|60|0|28000000001|0|0|28000000001',
        '-1|442443775|-355761183|1|1|-557556225|198356862195014175|0|-557556225',
        '9223372036854775807|-1|7|86400|542678844|9223372036854775806999999999|64563604257983430648999999993|106751320661706|85239072852135',
        '1000000000|0|-1|777237|592362342|1000000000000000000|-1000000000000000000|1286|472456222028188',
        '-1|0|1000000000|9722012850385|0|-1000000000|-1000000000000000000|0|-1000000000',
        '631107417600|999999999|0|3600|876803188|631107417600999999999|0|175264929|352508206347',
        '1000000000|0|-1000000000|1|1|1000000000000000000|-1000000000000000000000000000|999999999|1',
        '86400000000000|0|1000|5439606671327|350236225|86400000000000000000000|86400000000000000000000000|15|4805899930089746456625',
        '532|-999999999|1000|0|500000000|531000000001|531000000001000|1062|1',
        '9223372036854775807|16159586|1|604800|1|9223372036854775807016159586|9223372036854775807016159586|15250284452471|299756731707115',
        '0|0|-1000000000|843171|1|0|0|0|0',
        '650380660895|-1|644572360|287937|500000000|650380660894999999999|419217397491449862199355427640|2258756|105144999999999',
        '1000000000000000000|-999999999|0|604800|320632895|999999999999999999000000001|0|1653438276873|508181398462666',
        '0|-819724207|-1|0|279340713|-819724207|819724207|-2|-261042781'
    };

    @IsTest
    static void matchesArbitraryPrecisionArithmetic() {
        for (String row : VECTORS) {
            List<String> f = row.split('\\|');
            JiffI128 value = JiffI128.ofSecondsAndNanos(
                Long.valueOf(f.get(0)),
                Long.valueOf(f.get(1))
            );
            Assert.areEqual(f.get(5), value.toString(), 'value of ' + row);
            Assert.areEqual(
                f.get(6),
                value.multiply(Long.valueOf(f.get(2))).toString(),
                'product of ' + row
            );
            JiffI128 divisor = JiffI128.ofSecondsAndNanos(
                Long.valueOf(f.get(3)),
                Long.valueOf(f.get(4))
            );
            List<JiffI128> parts = value.divRem(divisor);
            Assert.areEqual(f.get(7), parts.get(0).toString(), 'quotient of ' + row);
            Assert.areEqual(f.get(8), parts.get(1).toString(), 'remainder of ' + row);
            // quotient * divisor + remainder == value, whatever the signs.
            JiffI128 rebuilt = multiplyWide(parts.get(0), divisor).add(parts.get(1));
            Assert.areEqual(value, rebuilt, 'reconstruction of ' + row);
            // Negating the dividend negates both quotient and remainder (truncating division).
            List<JiffI128> negated = value.negate().divRem(divisor);
            Assert.areEqual(parts.get(0).negate(), negated.get(0), 'negated quotient of ' + row);
            Assert.areEqual(parts.get(1).negate(), negated.get(1), 'negated remainder of ' + row);
        }
    }

    /** a * b for a `b` that may not fit in a Long, built from Long sized pieces of `b`. */
    private static JiffI128 multiplyWide(JiffI128 a, JiffI128 b) {
        List<JiffI128> split = b.divRem(JiffI128.valueOf(1000000000L));
        if (!a.fitsLong()) {
            // Every vector has at least one operand that fits; multiplication commutes.
            return multiplyWide(b, a);
        }
        Long factor = a.toLong();
        JiffI128 upper = split.get(0).multiply(factor);
        return upper.multiply(1000000000L).add(split.get(1).multiply(factor));
    }

    @IsTest
    static void convertsToAndFromLong() {
        Assert.areEqual(JiffMath.LONG_MAX, JiffI128.valueOf(JiffMath.LONG_MAX).toLong());
        Assert.areEqual(JiffMath.LONG_MIN, JiffI128.valueOf(JiffMath.LONG_MIN).toLong());
        Assert.areEqual('-9223372036854775808', JiffI128.valueOf(JiffMath.LONG_MIN).toString());
        Assert.isTrue(JiffI128.valueOf(JiffMath.LONG_MAX).fitsLong());
        Assert.isFalse(JiffI128.valueOf(JiffMath.LONG_MAX).add(1L).fitsLong());
        Assert.isFalse(JiffI128.valueOf(JiffMath.LONG_MIN).subtract(1L).fitsLong());
        Assert.isTrue(JiffI128.valueOf(JiffMath.LONG_MAX).add(1L).subtract(1L).fitsLong());
        try {
            JiffI128.valueOf(JiffMath.LONG_MAX).add(1L).toLong();
            Assert.fail('expected an overflow');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('overflowed'), e.getMessage());
        }
    }

    @IsTest
    static void addsAndSubtractsAcrossTheHalfBoundary() {
        JiffI128 big = JiffI128.product(999999999999999999L, 1000L);
        Assert.areEqual('999999999999999999000', big.toString());
        Assert.areEqual('1000000000000000000000', big.add(1000L).toString());
        Assert.areEqual('-1', big.subtract(big).subtract(1L).toString());
        Assert.areEqual('-999999999999999999001', big.negate().subtract(1L).toString());
        Assert.areEqual('1', big.negate().add(big).add(1L).toString());
        Double expected = 123456789012L;
        expected = expected * 1000000000;
        Assert.areEqual(expected, JiffI128.product(123456789012L, 1000000000L).toDouble());
    }

    @IsTest
    static void reportsSignAndParity() {
        Assert.areEqual(0, JiffI128.ZERO.signum());
        Assert.areEqual(1, JiffI128.ONE.signum());
        Assert.areEqual(-1, JiffI128.product(-5L, 1000000000000000000L).signum());
        Assert.isTrue(JiffI128.ZERO.isZero());
        Assert.isTrue(JiffI128.valueOf(-7L).isOdd());
        Assert.isFalse(JiffI128.product(3L, 1000000000000000000L).isOdd());
        Assert.isTrue(JiffI128.product(3L, 1000000000000000000L).add(1L).isOdd());
        Assert.areEqual(JiffI128.valueOf(7L), JiffI128.valueOf(-7L).abs());
    }

    @IsTest
    static void comparesAndHashesByValue() {
        JiffI128 small = JiffI128.valueOf(5L);
        JiffI128 large = JiffI128.product(5L, 1000000000000000000L);
        Assert.areEqual(-1, small.compareTo(large));
        Assert.areEqual(1, large.compareTo(small));
        Assert.areEqual(0, large.compareTo(JiffI128.product(1000000000000000000L, 5L)));
        Assert.areEqual(-1, large.negate().compareTo(small.negate()));
        Assert.areEqual(large.hashCode(), JiffI128.product(1000000000000000000L, 5L).hashCode());
        Assert.isFalse(small.equals('5'));
    }

    @IsTest
    static void rejectsDivisionByZeroAndOverflow() {
        try {
            JiffI128.ONE.divRem(JiffI128.ZERO);
            Assert.fail('expected division by zero to fail');
        } catch (JiffException e) {
            Assert.areEqual('division by zero', e.getMessage());
        }
        JiffI128 huge = JiffI128.product(JiffMath.LONG_MAX, 1000000000L);
        try {
            huge.multiply(1000000000L);
            Assert.fail('expected multiplication to overflow');
        } catch (JiffException e) {
            Assert.isTrue(e.getMessage().contains('overflowed'), e.getMessage());
        }
    }
}
