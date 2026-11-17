@IsTest
private class JiffWeekdaysTest {
    private static final List<JiffWeekday> MONDAY_FIRST = new List<JiffWeekday>{
        JiffWeekday.MONDAY,
        JiffWeekday.TUESDAY,
        JiffWeekday.WEDNESDAY,
        JiffWeekday.THURSDAY,
        JiffWeekday.FRIDAY,
        JiffWeekday.SATURDAY,
        JiffWeekday.SUNDAY
    };

    private static void assertRejected(String scheme, Integer offset, String expected) {
        try {
            if (scheme.equals('m0')) {
                JiffWeekdays.fromMondayZeroOffset(offset);
            } else if (scheme.equals('m1')) {
                JiffWeekdays.fromMondayOneOffset(offset);
            } else if (scheme.equals('s0')) {
                JiffWeekdays.fromSundayZeroOffset(offset);
            } else {
                JiffWeekdays.fromSundayOneOffset(offset);
            }
            Assert.fail('expected offset ' + offset + ' to be rejected for scheme ' + scheme);
        } catch (JiffException e) {
            Assert.areEqual(expected, e.getMessage());
        }
    }

    @IsTest
    static void theEnumListsTheWeekStartingOnMonday() {
        Assert.areEqual(MONDAY_FIRST, JiffWeekday.values());
        Assert.areEqual(0, JiffWeekday.MONDAY.ordinal());
        Assert.areEqual(6, JiffWeekday.SUNDAY.ordinal());
    }

    @IsTest
    static void buildsAWeekdayFromAMondayZeroOffset() {
        for (Integer offset = 0; offset < 7; offset++) {
            Assert.areEqual(MONDAY_FIRST.get(offset), JiffWeekdays.fromMondayZeroOffset(offset));
        }
        Assert.areEqual(JiffWeekday.THURSDAY, JiffWeekdays.fromMondayZeroOffset(3));
        String expected = 'parameter \'weekday (Monday 0-indexed)\' is not in the required range of 0..=6';
        assertRejected('m0', 7, expected);
        assertRejected('m0', -1, expected);
    }

    @IsTest
    static void buildsAWeekdayFromAMondayOneOffset() {
        for (Integer offset = 1; offset <= 7; offset++) {
            Assert.areEqual(MONDAY_FIRST.get(offset - 1), JiffWeekdays.fromMondayOneOffset(offset));
        }
        Assert.areEqual(JiffWeekday.THURSDAY, JiffWeekdays.fromMondayOneOffset(4));
        String expected = 'parameter \'weekday (Monday 1-indexed)\' is not in the required range of 1..=7';
        assertRejected('m1', 8, expected);
        assertRejected('m1', 0, expected);
    }

    @IsTest
    static void buildsAWeekdayFromASundayZeroOffset() {
        Assert.areEqual(JiffWeekday.SUNDAY, JiffWeekdays.fromSundayZeroOffset(0));
        Assert.areEqual(JiffWeekday.MONDAY, JiffWeekdays.fromSundayZeroOffset(1));
        Assert.areEqual(JiffWeekday.TUESDAY, JiffWeekdays.fromSundayZeroOffset(2));
        Assert.areEqual(JiffWeekday.WEDNESDAY, JiffWeekdays.fromSundayZeroOffset(3));
        Assert.areEqual(JiffWeekday.THURSDAY, JiffWeekdays.fromSundayZeroOffset(4));
        Assert.areEqual(JiffWeekday.FRIDAY, JiffWeekdays.fromSundayZeroOffset(5));
        Assert.areEqual(JiffWeekday.SATURDAY, JiffWeekdays.fromSundayZeroOffset(6));
        String expected = 'parameter \'weekday (Sunday 0-indexed)\' is not in the required range of 0..=6';
        assertRejected('s0', 7, expected);
        assertRejected('s0', -1, expected);
    }

    @IsTest
    static void buildsAWeekdayFromASundayOneOffset() {
        Assert.areEqual(JiffWeekday.SUNDAY, JiffWeekdays.fromSundayOneOffset(1));
        Assert.areEqual(JiffWeekday.MONDAY, JiffWeekdays.fromSundayOneOffset(2));
        Assert.areEqual(JiffWeekday.TUESDAY, JiffWeekdays.fromSundayOneOffset(3));
        Assert.areEqual(JiffWeekday.WEDNESDAY, JiffWeekdays.fromSundayOneOffset(4));
        Assert.areEqual(JiffWeekday.THURSDAY, JiffWeekdays.fromSundayOneOffset(5));
        Assert.areEqual(JiffWeekday.FRIDAY, JiffWeekdays.fromSundayOneOffset(6));
        Assert.areEqual(JiffWeekday.SATURDAY, JiffWeekdays.fromSundayOneOffset(7));
        String expected = 'parameter \'weekday (Sunday 1-indexed)\' is not in the required range of 1..=7';
        assertRejected('s1', 8, expected);
        assertRejected('s1', 0, expected);
    }

    @IsTest
    static void reportsAWeekdayInEachNumberingScheme() {
        Assert.areEqual(0, JiffWeekdays.toMondayZeroOffset(JiffWeekday.MONDAY));
        Assert.areEqual(1, JiffWeekdays.toMondayOneOffset(JiffWeekday.MONDAY));
        Assert.areEqual(1, JiffWeekdays.toSundayZeroOffset(JiffWeekday.MONDAY));
        Assert.areEqual(2, JiffWeekdays.toSundayOneOffset(JiffWeekday.MONDAY));

        Assert.areEqual(6, JiffWeekdays.toMondayZeroOffset(JiffWeekday.SUNDAY));
        Assert.areEqual(7, JiffWeekdays.toMondayOneOffset(JiffWeekday.SUNDAY));
        Assert.areEqual(0, JiffWeekdays.toSundayZeroOffset(JiffWeekday.SUNDAY));
        Assert.areEqual(1, JiffWeekdays.toSundayOneOffset(JiffWeekday.SUNDAY));

        Assert.areEqual(3, JiffWeekdays.toMondayZeroOffset(JiffWeekday.THURSDAY));
        Assert.areEqual(4, JiffWeekdays.toMondayOneOffset(JiffWeekday.THURSDAY));
        Assert.areEqual(4, JiffWeekdays.toSundayZeroOffset(JiffWeekday.THURSDAY));
        Assert.areEqual(5, JiffWeekdays.toSundayOneOffset(JiffWeekday.THURSDAY));

        // 1948-12-31 was a Friday.
        Assert.areEqual(4, JiffWeekdays.toMondayZeroOffset(JiffWeekday.FRIDAY));
        Assert.areEqual(5, JiffWeekdays.toMondayOneOffset(JiffWeekday.FRIDAY));
        Assert.areEqual(5, JiffWeekdays.toSundayZeroOffset(JiffWeekday.FRIDAY));
        Assert.areEqual(6, JiffWeekdays.toSundayOneOffset(JiffWeekday.FRIDAY));
    }

    @IsTest
    static void everyOffsetSchemeRoundTrips() {
        for (JiffWeekday weekday : MONDAY_FIRST) {
            Assert.areEqual(
                weekday,
                JiffWeekdays.fromMondayZeroOffset(JiffWeekdays.toMondayZeroOffset(weekday))
            );
            Assert.areEqual(
                weekday,
                JiffWeekdays.fromMondayOneOffset(JiffWeekdays.toMondayOneOffset(weekday))
            );
            Assert.areEqual(
                weekday,
                JiffWeekdays.fromSundayZeroOffset(JiffWeekdays.toSundayZeroOffset(weekday))
            );
            Assert.areEqual(
                weekday,
                JiffWeekdays.fromSundayOneOffset(JiffWeekdays.toSundayOneOffset(weekday))
            );
        }
    }

    @IsTest
    static void sundayComesFirstOrLastDependingOnTheScheme() {
        JiffWeekday sun = JiffWeekday.SUNDAY;
        JiffWeekday mon = JiffWeekday.MONDAY;
        Assert.isTrue(JiffWeekdays.toSundayZeroOffset(sun) < JiffWeekdays.toSundayZeroOffset(mon));
        Assert.isTrue(JiffWeekdays.toMondayZeroOffset(sun) > JiffWeekdays.toMondayZeroOffset(mon));
    }

    @IsTest
    static void wrappingAddMovesForwardAroundTheWeek() {
        List<JiffWeekday> fromSunday = new List<JiffWeekday>{
            JiffWeekday.SUNDAY,
            JiffWeekday.MONDAY,
            JiffWeekday.TUESDAY,
            JiffWeekday.WEDNESDAY,
            JiffWeekday.THURSDAY,
            JiffWeekday.FRIDAY,
            JiffWeekday.SATURDAY,
            JiffWeekday.SUNDAY
        };
        List<JiffWeekday> fromWednesday = new List<JiffWeekday>{
            JiffWeekday.WEDNESDAY,
            JiffWeekday.THURSDAY,
            JiffWeekday.FRIDAY,
            JiffWeekday.SATURDAY,
            JiffWeekday.SUNDAY,
            JiffWeekday.MONDAY,
            JiffWeekday.TUESDAY,
            JiffWeekday.WEDNESDAY
        };
        for (Integer days = 0; days <= 7; days++) {
            Assert.areEqual(
                fromSunday.get(days),
                JiffWeekdays.wrappingAdd(JiffWeekday.SUNDAY, days)
            );
            Assert.areEqual(
                fromWednesday.get(days),
                JiffWeekdays.wrappingAdd(JiffWeekday.WEDNESDAY, days)
            );
        }
        Assert.areEqual(JiffWeekday.SUNDAY, JiffWeekdays.wrappingAdd(JiffWeekday.SATURDAY, 1L));
        Assert.areEqual(JiffWeekday.SATURDAY, JiffWeekdays.wrappingAdd(JiffWeekday.SATURDAY, 7L));
    }

    @IsTest
    static void wrappingAddOfANegativeCountMovesBackward() {
        List<JiffWeekday> backFromSunday = new List<JiffWeekday>{
            JiffWeekday.SUNDAY,
            JiffWeekday.SATURDAY,
            JiffWeekday.FRIDAY,
            JiffWeekday.THURSDAY,
            JiffWeekday.WEDNESDAY,
            JiffWeekday.TUESDAY,
            JiffWeekday.MONDAY,
            JiffWeekday.SUNDAY
        };
        List<JiffWeekday> backFromWednesday = new List<JiffWeekday>{
            JiffWeekday.WEDNESDAY,
            JiffWeekday.TUESDAY,
            JiffWeekday.MONDAY,
            JiffWeekday.SUNDAY,
            JiffWeekday.SATURDAY,
            JiffWeekday.FRIDAY,
            JiffWeekday.THURSDAY,
            JiffWeekday.WEDNESDAY
        };
        for (Integer days = 0; days <= 7; days++) {
            Assert.areEqual(
                backFromSunday.get(days),
                JiffWeekdays.wrappingAdd(JiffWeekday.SUNDAY, -days)
            );
            Assert.areEqual(
                backFromWednesday.get(days),
                JiffWeekdays.wrappingAdd(JiffWeekday.WEDNESDAY, -days)
            );
            // Subtracting is adding the negation.
            Assert.areEqual(
                backFromSunday.get(days),
                JiffWeekdays.wrappingSubtract(JiffWeekday.SUNDAY, days)
            );
            Assert.areEqual(
                backFromWednesday.get(days),
                JiffWeekdays.wrappingSubtract(JiffWeekday.WEDNESDAY, days)
            );
        }
    }

    @IsTest
    static void wrappingSubtractOfANegativeCountMovesForward() {
        Assert.areEqual(JiffWeekday.MONDAY, JiffWeekdays.wrappingSubtract(JiffWeekday.SUNDAY, -1L));
        Assert.areEqual(
            JiffWeekday.TUESDAY,
            JiffWeekdays.wrappingSubtract(JiffWeekday.SUNDAY, -2L)
        );
        Assert.areEqual(
            JiffWeekday.SATURDAY,
            JiffWeekdays.wrappingSubtract(JiffWeekday.SUNDAY, -6L)
        );
        Assert.areEqual(JiffWeekday.SUNDAY, JiffWeekdays.wrappingSubtract(JiffWeekday.SUNDAY, -7L));
        Assert.areEqual(
            JiffWeekday.THURSDAY,
            JiffWeekdays.wrappingSubtract(JiffWeekday.WEDNESDAY, -1L)
        );
        Assert.areEqual(
            JiffWeekday.MONDAY,
            JiffWeekdays.wrappingSubtract(JiffWeekday.WEDNESDAY, -5L)
        );
        Assert.areEqual(
            JiffWeekday.FRIDAY,
            JiffWeekdays.wrappingSubtract(JiffWeekday.SATURDAY, 1L)
        );
        Assert.areEqual(
            JiffWeekday.SATURDAY,
            JiffWeekdays.wrappingSubtract(JiffWeekday.SATURDAY, 7L)
        );
    }

    @IsTest
    static void wrappingArithmeticAcceptsTheLargestAndSmallestLongs() {
        // These are the regression cases from Jiff's own tests, where an earlier version
        // overflowed.
        Assert.areEqual(
            JiffWeekday.TUESDAY,
            JiffWeekdays.wrappingAdd(JiffWeekday.TUESDAY, JiffMath.LONG_MAX)
        );
        Assert.areEqual(
            JiffWeekday.MONDAY,
            JiffWeekdays.wrappingAdd(JiffWeekday.TUESDAY, JiffMath.LONG_MIN)
        );
        Assert.areEqual(
            JiffWeekday.SATURDAY,
            JiffWeekdays.wrappingSubtract(JiffWeekday.MONDAY, -9223372036854775805L)
        );
        Assert.areEqual(
            JiffWeekday.SUNDAY,
            JiffWeekdays.wrappingSubtract(JiffWeekday.MONDAY, -9223372036854775806L)
        );
        Assert.areEqual(
            JiffWeekday.MONDAY,
            JiffWeekdays.wrappingSubtract(JiffWeekday.MONDAY, -9223372036854775807L)
        );
        Assert.areEqual(
            JiffWeekday.TUESDAY,
            JiffWeekdays.wrappingSubtract(JiffWeekday.MONDAY, JiffMath.LONG_MIN)
        );
        Assert.areEqual(
            JiffWeekday.TUESDAY,
            JiffWeekdays.wrappingSubtract(JiffWeekday.TUESDAY, JiffMath.LONG_MAX)
        );
        Assert.areEqual(
            JiffWeekday.WEDNESDAY,
            JiffWeekdays.wrappingSubtract(JiffWeekday.TUESDAY, JiffMath.LONG_MIN)
        );
    }

    @IsTest
    static void addingThenSubtractingTheSameCountIsTheIdentity() {
        List<Long> counts = new List<Long>{
            0L,
            1L,
            -1L,
            6L,
            7L,
            8L,
            -13L,
            1000000007L,
            -86399999999999L,
            JiffMath.LONG_MAX,
            JiffMath.LONG_MIN
        };
        for (JiffWeekday weekday : MONDAY_FIRST) {
            for (Long count : counts) {
                Assert.areEqual(
                    weekday,
                    JiffWeekdays.wrappingSubtract(JiffWeekdays.wrappingAdd(weekday, count), count),
                    weekday.name() + ' + ' + count + ' - ' + count
                );
            }
        }
    }

    @IsTest
    static void nextAndPreviousStepOneDayAndWrap() {
        Assert.areEqual(JiffWeekday.THURSDAY, JiffWeekdays.next(JiffWeekday.WEDNESDAY));
        Assert.areEqual(JiffWeekday.MONDAY, JiffWeekdays.next(JiffWeekday.SUNDAY));
        Assert.areEqual(JiffWeekday.SUNDAY, JiffWeekdays.next(JiffWeekday.SATURDAY));
        Assert.areEqual(JiffWeekday.TUESDAY, JiffWeekdays.previous(JiffWeekday.WEDNESDAY));
        Assert.areEqual(JiffWeekday.SATURDAY, JiffWeekdays.previous(JiffWeekday.SUNDAY));
        Assert.areEqual(JiffWeekday.FRIDAY, JiffWeekdays.previous(JiffWeekday.SATURDAY));
        Assert.areEqual(JiffWeekday.SUNDAY, JiffWeekdays.previous(JiffWeekday.MONDAY));
    }

    @IsTest
    static void sinceCountsDaysForwardFromTheOtherWeekday() {
        Assert.areEqual(3, JiffWeekdays.since(JiffWeekday.FRIDAY, JiffWeekday.TUESDAY));
        Assert.areEqual(0, JiffWeekdays.since(JiffWeekday.TUESDAY, JiffWeekday.TUESDAY));
        Assert.areEqual(1, JiffWeekdays.since(JiffWeekday.MONDAY, JiffWeekday.SUNDAY));
        Assert.areEqual(6, JiffWeekdays.since(JiffWeekday.SUNDAY, JiffWeekday.MONDAY));
    }

    @IsTest
    static void untilCountsDaysForwardToTheOtherWeekday() {
        Assert.areEqual(4, JiffWeekdays.until(JiffWeekday.FRIDAY, JiffWeekday.TUESDAY));
        Assert.areEqual(0, JiffWeekdays.until(JiffWeekday.TUESDAY, JiffWeekday.TUESDAY));
        Assert.areEqual(6, JiffWeekdays.until(JiffWeekday.MONDAY, JiffWeekday.SUNDAY));
        Assert.areEqual(1, JiffWeekdays.until(JiffWeekday.SUNDAY, JiffWeekday.MONDAY));
    }

    @IsTest
    static void sinceAndUntilAgreeWithTheForwardCycle() {
        for (JiffWeekday first : MONDAY_FIRST) {
            List<JiffWeekday> cycle = JiffWeekdays.cycleForward(first);
            for (Integer distance = 0; distance < 7; distance++) {
                JiffWeekday second = cycle.get(distance);
                Assert.areEqual(distance, JiffWeekdays.since(second, first));
                Assert.areEqual(distance, JiffWeekdays.until(first, second));
                Assert.areEqual(second, JiffWeekdays.wrappingAdd(first, distance));
            }
        }
    }

    @IsTest
    static void cycleForwardListsTheWeekFromTheGivenDay() {
        Assert.areEqual(MONDAY_FIRST, JiffWeekdays.cycleForward(JiffWeekday.MONDAY));
        Assert.areEqual(
            new List<JiffWeekday>{
                JiffWeekday.TUESDAY,
                JiffWeekday.WEDNESDAY,
                JiffWeekday.THURSDAY,
                JiffWeekday.FRIDAY,
                JiffWeekday.SATURDAY,
                JiffWeekday.SUNDAY,
                JiffWeekday.MONDAY
            },
            JiffWeekdays.cycleForward(JiffWeekday.TUESDAY)
        );
    }

    @IsTest
    static void cycleReverseListsTheWeekBackwardFromTheGivenDay() {
        Assert.areEqual(
            new List<JiffWeekday>{
                JiffWeekday.TUESDAY,
                JiffWeekday.MONDAY,
                JiffWeekday.SUNDAY,
                JiffWeekday.SATURDAY,
                JiffWeekday.FRIDAY,
                JiffWeekday.THURSDAY,
                JiffWeekday.WEDNESDAY
            },
            JiffWeekdays.cycleReverse(JiffWeekday.TUESDAY)
        );
        List<JiffWeekday> fromSunday = JiffWeekdays.cycleReverse(JiffWeekday.SUNDAY);
        Assert.areEqual(7, fromSunday.size());
        for (Integer i = 0; i < 7; i++) {
            Assert.areEqual(MONDAY_FIRST.get(6 - i), fromSunday.get(i));
        }
    }
}
