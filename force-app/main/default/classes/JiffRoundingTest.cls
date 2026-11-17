@IsTest
private class JiffRoundingTest {
    private static final List<JiffRoundMode> MODES = new List<JiffRoundMode>{
        JiffRoundMode.CEIL,
        JiffRoundMode.FLOOR,
        JiffRoundMode.EXPAND,
        JiffRoundMode.TRUNC,
        JiffRoundMode.HALF_CEIL,
        JiffRoundMode.HALF_FLOOR,
        JiffRoundMode.HALF_EXPAND,
        JiffRoundMode.HALF_TRUNC,
        JiffRoundMode.HALF_EVEN
    };

    // quantity|increment|then the expected result for each mode, in the order of MODES.
    // Expected values come from the mathematical definition of each mode, computed with
    // exact rational arithmetic, rather than from the remainder based algorithm under test.
    private static final List<String> SMALL = new List<String>{
        '-25|10|-20|-30|-30|-20|-20|-30|-30|-20|-20',
        '-18|10|-10|-20|-20|-10|-20|-20|-20|-20|-20',
        '-15|10|-10|-20|-20|-10|-10|-20|-20|-10|-20',
        '-12|10|-10|-20|-20|-10|-10|-10|-10|-10|-10',
        '-10|10|-10|-10|-10|-10|-10|-10|-10|-10|-10',
        '-5|10|0|-10|-10|0|0|-10|-10|0|0',
        '-1|10|0|-10|-10|0|0|0|0|0|0',
        '0|10|0|0|0|0|0|0|0|0|0',
        '1|10|10|0|10|0|0|0|0|0|0',
        '5|10|10|0|10|0|10|0|10|0|0',
        '12|10|20|10|20|10|10|10|10|10|10',
        '15|10|20|10|20|10|20|10|20|10|20',
        '18|10|20|10|20|10|20|20|20|20|20',
        '25|10|30|20|30|20|30|20|30|20|20',
        '35|10|40|30|40|30|40|30|40|30|40',
        '7|2|8|6|8|6|8|6|8|6|8',
        '-7|2|-6|-8|-8|-6|-6|-8|-8|-6|-8',
        '9|2|10|8|10|8|10|8|10|8|8',
        '-9|2|-8|-10|-10|-8|-8|-10|-10|-8|-8'
    };

    private static final List<String> WIDE = new List<String>{
        '-626515525209648038508317640|1|-626515525209648038508317640|-626515525209648038508317640|-626515525209648038508317640|-626515525209648038508317640|-626515525209648038508317640|-626515525209648038508317640|-626515525209648038508317640|-626515525209648038508317640|-626515525209648038508317640',
        '326779592340946171711926067|86400000000000|326779592340960000000000000|326779592340873600000000000|326779592340960000000000000|326779592340873600000000000|326779592340960000000000000|326779592340960000000000000|326779592340960000000000000|326779592340960000000000000|326779592340960000000000000',
        '-907165243855560193777119499|900000000000|-907165243855559700000000000|-907165243855560600000000000|-907165243855560600000000000|-907165243855559700000000000|-907165243855560600000000000|-907165243855560600000000000|-907165243855560600000000000|-907165243855560600000000000|-907165243855560600000000000',
        '399995549775875594076151222|60000000000|399995549775875640000000000|399995549775875580000000000|399995549775875640000000000|399995549775875580000000000|399995549775875580000000000|399995549775875580000000000|399995549775875580000000000|399995549775875580000000000|399995549775875580000000000',
        '-452627900417680999051042148|1000000000|-452627900417680999000000000|-452627900417681000000000000|-452627900417681000000000000|-452627900417680999000000000|-452627900417680999000000000|-452627900417680999000000000|-452627900417680999000000000|-452627900417680999000000000|-452627900417680999000000000',
        '356149599458831263172227587|1000|356149599458831263172228000|356149599458831263172227000|356149599458831263172228000|356149599458831263172227000|356149599458831263172228000|356149599458831263172228000|356149599458831263172228000|356149599458831263172228000|356149599458831263172228000',
        '532593517482772995751178435|133749395942400000000000|532723844038579200000000000|532590094642636800000000000|532723844038579200000000000|532590094642636800000000000|532590094642636800000000000|532590094642636800000000000|532590094642636800000000000|532590094642636800000000000|532590094642636800000000000',
        '500000000000000000000|1000000000000000000000|1000000000000000000000|0|1000000000000000000000|0|1000000000000000000000|0|1000000000000000000000|0|0',
        '1500000000000000000000|1000000000000000000000|2000000000000000000000|1000000000000000000000|2000000000000000000000|1000000000000000000000|2000000000000000000000|1000000000000000000000|2000000000000000000000|1000000000000000000000|2000000000000000000000',
        '-500000000000000000000|1000000000000000000000|0|-1000000000000000000000|-1000000000000000000000|0|0|-1000000000000000000000|-1000000000000000000000|0|0',
        '-1500000000000000000000|1000000000000000000000|-1000000000000000000000|-2000000000000000000000|-2000000000000000000000|-1000000000000000000000|-1000000000000000000000|-2000000000000000000000|-2000000000000000000000|-1000000000000000000000|-2000000000000000000000',
        '2500000000000000000000|1000000000000000000000|3000000000000000000000|2000000000000000000000|3000000000000000000000|2000000000000000000000|3000000000000000000000|2000000000000000000000|3000000000000000000000|2000000000000000000000|2000000000000000000000'
    };

    @IsTest
    static void roundsSmallQuantitiesInEveryMode() {
        for (String row : SMALL) {
            List<String> f = row.split('\\|');
            Long quantity = Long.valueOf(f.get(0));
            Long increment = Long.valueOf(f.get(1));
            for (Integer i = 0; i < MODES.size(); i++) {
                JiffRoundMode mode = MODES.get(i);
                String label = mode.name() + ' of ' + quantity + ' by ' + increment;
                Assert.areEqual(
                    Long.valueOf(f.get(i + 2)),
                    JiffRounding.roundLong(mode, quantity, increment),
                    label
                );
                Assert.areEqual(
                    f.get(i + 2),
                    JiffRounding.round(
                            mode,
                            JiffI128.valueOf(quantity),
                            JiffI128.valueOf(increment)
                        )
                        .toString(),
                    'wide ' + label
                );
            }
        }
    }

    @IsTest
    static void roundsWideQuantitiesInEveryMode() {
        for (String row : WIDE) {
            List<String> f = row.split('\\|');
            JiffI128 quantity = JiffI128.parse(f.get(0));
            JiffI128 increment = JiffI128.parse(f.get(1));
            for (Integer i = 0; i < MODES.size(); i++) {
                Assert.areEqual(
                    f.get(i + 2),
                    JiffRounding.round(MODES.get(i), quantity, increment).toString(),
                    MODES.get(i).name() + ' of ' + f.get(0) + ' by ' + f.get(1)
                );
            }
        }
    }

    private static Boolean accepts(String kind, JiffUnit unit, Long value) {
        try {
            if (kind == 'span') {
                JiffRounding.incrementForSpan(unit, value);
            } else if (kind == 'datetime') {
                JiffRounding.incrementForDateTime(unit, value);
            } else if (kind == 'time') {
                JiffRounding.incrementForTime(unit, value);
            } else if (kind == 'timestamp') {
                JiffRounding.incrementForTimestamp(unit, value);
            } else if (kind == 'duration') {
                JiffRounding.incrementForSignedDuration(unit, value);
            } else {
                JiffRounding.incrementForOffset(unit, value);
            }
            return true;
        } catch (JiffException e) {
            return false;
        }
    }

    private static void assertIncrements(
        String kind,
        JiffUnit unit,
        List<Long> good,
        List<Long> bad
    ) {
        for (Long value : good) {
            Assert.isTrue(
                accepts(kind, unit, value),
                kind + ' should accept ' + value + ' ' + unit
            );
        }
        for (Long value : bad) {
            Assert.isFalse(
                accepts(kind, unit, value),
                kind + ' should reject ' + value + ' ' + unit
            );
        }
    }

    private static final List<Long> ALWAYS_BAD = new List<Long>{
        -1L,
        0L,
        1000000001L,
        JiffMath.LONG_MIN,
        JiffMath.LONG_MAX
    };

    @IsTest
    static void spanIncrementsMustDivideTheNextUnitForTimeUnits() {
        for (
            JiffUnit unit : new List<JiffUnit>{
                JiffUnit.NANOSECOND,
                JiffUnit.MICROSECOND,
                JiffUnit.MILLISECOND
            }
        ) {
            assertIncrements('span', unit, new List<Long>{ 1L, 500L }, new List<Long>{ 7L, 1000L });
            assertIncrements('span', unit, new List<Long>(), ALWAYS_BAD);
        }
        for (JiffUnit unit : new List<JiffUnit>{ JiffUnit.SECOND, JiffUnit.MINUTE }) {
            assertIncrements(
                'span',
                unit,
                new List<Long>{ 1L, 15L },
                new List<Long>{ 7L, 60L, 1000L }
            );
        }
        assertIncrements(
            'span',
            JiffUnit.HOUR,
            new List<Long>{ 1L, 6L, 12L },
            new List<Long>{ 15L, 18L, 23L, 24L }
        );
        for (
            JiffUnit unit : new List<JiffUnit>{
                JiffUnit.DAY,
                JiffUnit.WEEK,
                JiffUnit.MONTH,
                JiffUnit.YEAR
            }
        ) {
            assertIncrements(
                'span',
                unit,
                new List<Long>{ 1L, 7L, 31L, 100L, 1000000000L },
                ALWAYS_BAD
            );
        }
    }

    @IsTest
    static void datetimeIncrementsAllowOnlySingleDays() {
        assertIncrements(
            'datetime',
            JiffUnit.NANOSECOND,
            new List<Long>{ 1L, 500L },
            new List<Long>{ 7L, 1000L }
        );
        assertIncrements(
            'datetime',
            JiffUnit.HOUR,
            new List<Long>{ 1L, 6L, 12L },
            new List<Long>{ 15L, 24L }
        );
        assertIncrements('datetime', JiffUnit.DAY, new List<Long>{ 1L }, new List<Long>{ 2L, 7L });
        assertIncrements('datetime', JiffUnit.DAY, new List<Long>(), ALWAYS_BAD);
        for (JiffUnit unit : new List<JiffUnit>{ JiffUnit.WEEK, JiffUnit.MONTH, JiffUnit.YEAR }) {
            assertIncrements('datetime', unit, new List<Long>(), new List<Long>{ 1L, 2L });
        }
    }

    @IsTest
    static void timeIncrementsStopAtHours() {
        assertIncrements(
            'time',
            JiffUnit.MINUTE,
            new List<Long>{ 1L, 15L, 30L },
            new List<Long>{ 7L, 60L }
        );
        assertIncrements('time', JiffUnit.HOUR, new List<Long>{ 1L, 12L }, new List<Long>{ 24L });
        assertIncrements('time', JiffUnit.DAY, new List<Long>(), new List<Long>{ 1L });
    }

    @IsTest
    static void timestampIncrementsMustDivideACivilDay() {
        assertIncrements(
            'timestamp',
            JiffUnit.NANOSECOND,
            new List<Long>{ 1L, 1000L, 1000000000L },
            new List<Long>{ 7L, 1000000001L }
        );
        assertIncrements(
            'timestamp',
            JiffUnit.SECOND,
            new List<Long>{ 1L, 60L, 86400L },
            new List<Long>{ 7L, 86401L }
        );
        assertIncrements(
            'timestamp',
            JiffUnit.MINUTE,
            new List<Long>{ 1L, 90L, 1440L },
            new List<Long>{ 7L, 1441L }
        );
        assertIncrements(
            'timestamp',
            JiffUnit.HOUR,
            new List<Long>{ 1L, 12L, 24L },
            new List<Long>{ 5L, 48L }
        );
        assertIncrements('timestamp', JiffUnit.DAY, new List<Long>(), new List<Long>{ 1L });
    }

    @IsTest
    static void signedDurationIncrementsRejectCalendarUnits() {
        assertIncrements(
            'duration',
            JiffUnit.HOUR,
            new List<Long>{ 1L, 5L, 1000000000L },
            ALWAYS_BAD
        );
        assertIncrements('duration', JiffUnit.NANOSECOND, new List<Long>{ 7L }, ALWAYS_BAD);
        assertIncrements('duration', JiffUnit.DAY, new List<Long>(), new List<Long>{ 1L });
        try {
            JiffRounding.incrementForSignedDuration(JiffUnit.MONTH, 1L);
            Assert.fail('expected a failure');
        } catch (JiffException e) {
            Assert.isTrue(
                e.getMessage().contains('\'months\', is a calendar unit'),
                e.getMessage()
            );
        }
    }

    @IsTest
    static void offsetIncrementsAllowOnlyHoursMinutesAndSeconds() {
        for (
            JiffUnit unit : new List<JiffUnit>{ JiffUnit.SECOND, JiffUnit.MINUTE, JiffUnit.HOUR }
        ) {
            assertIncrements('offset', unit, new List<Long>{ 1L, 7L, 1000000000L }, ALWAYS_BAD);
        }
        assertIncrements('offset', JiffUnit.MILLISECOND, new List<Long>(), new List<Long>{ 1L });
        assertIncrements('offset', JiffUnit.DAY, new List<Long>(), new List<Long>{ 1L });
    }

    @IsTest
    static void explainsWhyAnIncrementWasRejected() {
        try {
            JiffRounding.incrementForTime(JiffUnit.MINUTE, 7L);
            Assert.fail('expected a failure');
        } catch (JiffException e) {
            Assert.areEqual(
                'increment for rounding to \'minutes\' must divide into `60` evenly',
                e.getMessage()
            );
        }
        try {
            JiffRounding.incrementForDateTime(JiffUnit.DAY, 2L);
            Assert.fail('expected a failure');
        } catch (JiffException e) {
            Assert.areEqual(
                'increment for rounding to \'days\' must be equal to `1`',
                e.getMessage()
            );
        }
        try {
            JiffRounding.incrementForTime(JiffUnit.WEEK, 1L);
            Assert.fail('expected a failure');
        } catch (JiffException e) {
            Assert.areEqual('rounding to \'weeks\' is not supported', e.getMessage());
        }
        try {
            JiffRounding.incrementForSpan(JiffUnit.YEAR, 0L);
            Assert.fail('expected a failure');
        } catch (JiffException e) {
            Assert.areEqual(
                'parameter \'rounding increment\' is not in the required range of 1..=1000000000',
                e.getMessage()
            );
        }
    }
}
