@IsTest
private class JiffDateTimeRoundTest {
    private static final String YEAR_RANGE = 'parameter \'year\' is not in the required range of -9999..=9999';
    private static final String EPOCH_DAY_RANGE = 'parameter \'Unix epoch days\' is not in the required range of -4371587..=2932896';

    // The pieces Jiff's error messages are built from, keyed by the abbreviations the vector
    // table uses: `ERR:R:year` is "failed to add days to date: parameter 'year' ...".
    private static final Map<String, String> ERROR_TEXT = new Map<String, String>{
        'R' => 'failed to add days to date',
        'year' => YEAR_RANGE,
        'epoch' => EPOCH_DAY_RANGE
    };

    private static JiffDateTime civil(
        Integer year,
        Integer month,
        Integer day,
        Integer hour,
        Integer minute,
        Integer second,
        Integer subsecNanosecond
    ) {
        return JiffDateTime.newInstance(year, month, day, hour, minute, second, subsecNanosecond);
    }

    /** A datetime on the given day and hour, with the rest of the time zero. */
    private static JiffDateTime atHour(Integer year, Integer month, Integer day, Integer hour) {
        return JiffDateTime.newInstance(year, month, day, hour, 0, 0, 0);
    }

    /** Parses the `year,month,day,hour,minute,second,nanosecond` form the vector table uses. */
    private static JiffDateTime parseCivil(String text) {
        List<String> parts = text.split(',');
        return civil(
            Integer.valueOf(parts.get(0)),
            Integer.valueOf(parts.get(1)),
            Integer.valueOf(parts.get(2)),
            Integer.valueOf(parts.get(3)),
            Integer.valueOf(parts.get(4)),
            Integer.valueOf(parts.get(5)),
            Integer.valueOf(parts.get(6))
        );
    }

    /** The text of a vector's result, with an abbreviated error written out in full. */
    private static String expand(String expected) {
        if (!expected.startsWith('ERR:')) {
            return expected;
        }
        List<String> codes = expected.split(':');
        List<String> texts = new List<String>();
        for (Integer i = 1; i < codes.size(); i++) {
            Assert.isTrue(ERROR_TEXT.containsKey(codes.get(i)), 'unknown code in ' + expected);
            texts.add(ERROR_TEXT.get(codes.get(i)));
        }
        return 'ERR:' + String.join(texts, ': ');
    }

    private static String tryRound(JiffDateTime dt, JiffRound options) {
        try {
            return dt.round(options).toString();
        } catch (JiffException e) {
            return 'ERR:' + e.getMessage();
        }
    }

    @IsTest
    static void roundsToTheNearestDay() {
        Assert.areEqual(atHour(2024, 6, 20, 0), atHour(2024, 6, 19, 15).round(JiffUnit.DAY));
        Assert.areEqual(atHour(2024, 6, 19, 0), atHour(2024, 6, 19, 10).round(JiffUnit.DAY));
    }

    @IsTest
    static void theRoundingModeCanBeChanged() {
        JiffDateTime dt = atHour(2024, 6, 19, 15);
        Assert.areEqual(atHour(2024, 6, 20, 0), dt.round(JiffUnit.DAY));
        // The default will round up to the next day for any time past noon, but using
        // truncation rounding will always round down.
        Assert.areEqual(
            atHour(2024, 6, 19, 0),
            dt.round(JiffRound.to(JiffUnit.DAY).mode(JiffRoundMode.TRUNC))
        );
    }

    @IsTest
    static void roundsToTheNearestFiveMinutes() {
        JiffRound fiveMinutes = JiffRound.to(JiffUnit.MINUTE).increment(5);
        // Rounds down.
        Assert.areEqual(
            civil(2024, 6, 19, 15, 25, 0, 0),
            civil(2024, 6, 19, 15, 27, 29, 999999999).round(fiveMinutes)
        );
        // Rounds up.
        Assert.areEqual(
            civil(2024, 6, 19, 15, 30, 0, 0),
            civil(2024, 6, 19, 15, 27, 30, 0).round(fiveMinutes)
        );
    }

    @IsTest
    static void matchesTheExamplesFromTheTemporalDocumentation() {
        JiffDateTime dt = civil(1995, 12, 7, 3, 24, 30, 3500);
        Assert.areEqual(atHour(1995, 12, 7, 3), dt.round(JiffUnit.HOUR));
        Assert.areEqual(
            civil(1995, 12, 7, 3, 30, 0, 0),
            dt.round(JiffRound.to(JiffUnit.MINUTE).increment(30))
        );
        Assert.areEqual(
            atHour(1995, 12, 7, 3),
            dt.round(JiffRound.to(JiffUnit.MINUTE).increment(30).mode(JiffRoundMode.FLOOR))
        );
    }

    @IsTest
    static void roundingToASingleNanosecondChangesNothing() {
        Assert.areEqual(JiffDateTime.MAX, JiffDateTime.MAX.round(JiffUnit.NANOSECOND));
        Assert.areEqual(JiffDateTime.MAX, JiffDateTime.MAX.round(new JiffRound()));
        JiffDateTime dt = civil(1995, 12, 7, 3, 24, 30, 3500);
        Assert.areEqual(dt, dt.round(JiffRound.to(JiffUnit.NANOSECOND).mode(JiffRoundMode.CEIL)));
    }

    @IsTest
    static void roundingUpPastTheMaximumFails() {
        Assert.areEqual(
            'ERR:failed to add days to date: ' + EPOCH_DAY_RANGE,
            tryRound(JiffDateTime.MAX, JiffRound.to(JiffUnit.DAY))
        );
        Assert.areEqual(
            'ERR:failed to add days to date: ' + EPOCH_DAY_RANGE,
            tryRound(JiffDateTime.MAX, JiffRound.to(JiffUnit.SECOND))
        );
    }

    @IsTest
    static void truncationNeverFailsAtTheLimits() {
        JiffRound options = JiffRound.to(JiffUnit.DAY).mode(JiffRoundMode.TRUNC);
        Assert.areEqual(atHour(9999, 12, 31, 0), JiffDateTime.MAX.round(options));
        Assert.areEqual(atHour(-9999, 1, 1, 0), JiffDateTime.MIN.round(options));
    }

    @IsTest
    static void rejectsUnitsBiggerThanDays() {
        JiffDateTime dt = civil(2024, 3, 25, 7, 30, 0, 0);
        Assert.areEqual(
            'ERR:failed rounding datetime: rounding to \'weeks\' is not supported',
            tryRound(dt, JiffRound.to(JiffUnit.WEEK))
        );
        Assert.areEqual(
            'ERR:failed rounding datetime: rounding to \'months\' is not supported',
            tryRound(dt, JiffRound.to(JiffUnit.MONTH))
        );
        Assert.areEqual(
            'ERR:failed rounding datetime: rounding to \'years\' is not supported',
            tryRound(dt, JiffRound.to(JiffUnit.YEAR))
        );
    }

    @IsTest
    static void rejectsIncrementsThatDoNotDivideTheNextUnit() {
        JiffDateTime dt = civil(2024, 3, 25, 7, 30, 0, 0);
        Assert.areEqual(
            'ERR:failed rounding datetime: increment for rounding to \'days\' must be equal to `1`',
            tryRound(dt, JiffRound.to(JiffUnit.DAY).increment(2))
        );
        Assert.areEqual(
            'ERR:failed rounding datetime: increment for rounding to \'hours\' must divide ' +
            'into `24` evenly',
            tryRound(dt, JiffRound.to(JiffUnit.HOUR).increment(24))
        );
        Assert.areEqual(
            'ERR:failed rounding datetime: increment for rounding to \'minutes\' must divide ' +
            'into `60` evenly',
            tryRound(dt, JiffRound.to(JiffUnit.MINUTE).increment(7))
        );
        Assert.areEqual(
            'ERR:failed rounding datetime: increment for rounding to \'minutes\' must divide ' +
            'into `60` evenly',
            tryRound(dt, JiffRound.to(JiffUnit.MINUTE).increment(60))
        );
        Assert.areEqual(
            'ERR:failed rounding datetime: increment for rounding to \'microseconds\' must ' +
            'divide into `1000` evenly',
            tryRound(dt, JiffRound.to(JiffUnit.MICROSECOND).increment(3))
        );
        Assert.areEqual(
            'ERR:failed rounding datetime: increment for rounding to \'nanoseconds\' must ' +
            'divide into `1000` evenly',
            tryRound(dt, JiffRound.to(JiffUnit.NANOSECOND).increment(1000))
        );
    }

    @IsTest
    static void rejectsIncrementsOutOfRange() {
        JiffDateTime dt = civil(2024, 3, 25, 7, 30, 0, 0);
        String expected =
            'ERR:failed rounding datetime: parameter \'rounding increment\' is not in the ' +
            'required range of 1..=1000000000';
        Assert.areEqual(expected, tryRound(dt, JiffRound.to(JiffUnit.NANOSECOND).increment(0)));
        Assert.areEqual(expected, tryRound(dt, JiffRound.to(JiffUnit.DAY).increment(0)));
    }

    @IsTest
    static void theCarriedDayTakesTheSignOfTheYearAsInJiff() {
        // Jiff 1.0.0 multiplies the day carried out of the time of day by the sign of the
        // year. From year 1 onward that is the next day, as expected.
        Assert.areEqual(atHour(1, 1, 2, 0), atHour(1, 1, 1, 15).round(JiffUnit.DAY));
        // In year 0 the carry disappears, so the result is midnight of the same day.
        Assert.areEqual(atHour(0, 6, 19, 0), atHour(0, 6, 19, 15).round(JiffUnit.DAY));
        Assert.areEqual(
            atHour(0, 6, 19, 0),
            civil(0, 6, 19, 23, 59, 59, 999999999).round(JiffUnit.SECOND)
        );
        // And before year 0 it goes backwards, to midnight of the previous day.
        Assert.areEqual(atHour(-1, 6, 18, 0), atHour(-1, 6, 19, 15).round(JiffUnit.DAY));
        Assert.areEqual(atHour(-2, 12, 31, 0), atHour(-1, 1, 1, 15).round(JiffUnit.DAY));
        Assert.areEqual(
            atHour(-1, 6, 18, 0),
            atHour(-1, 6, 19, 10).round(JiffRound.to(JiffUnit.DAY).mode(JiffRoundMode.CEIL))
        );
        // Which makes rounding up on the very first day fail.
        Assert.areEqual(
            'ERR:failed to add days to date: ' + YEAR_RANGE,
            tryRound(atHour(-9999, 1, 1, 15), JiffRound.to(JiffUnit.DAY))
        );
        // Rounding down is not affected.
        Assert.areEqual(atHour(-1, 6, 19, 0), atHour(-1, 6, 19, 10).round(JiffUnit.DAY));
        Assert.areEqual(JiffDateTime.MIN, JiffDateTime.MIN.round(JiffUnit.DAY));
    }

    @IsTest
    static void roundMatchesJiff() {
        // Produced by Jiff 1.0.0, and replayed against it by `npm run oracle:check`. Each row is
        //   datetime | smallest unit | increment | mode | datetime.round(...)
        // with the datetime as `year,month,day,hour,minute,second,nanosecond`, the unit as
        // its position from nanoseconds (0) to days (6) and the mode as its position in
        // `JiffRoundMode`. The result is the datetime as Jiff prints it or the abbreviated
        // error.
        List<String> rows = new List<String>{
            '2024,6,30,12,0,0,0|6|1|0|2024-07-01T00:00:00',
            '2024,6,30,11,59,59,999999999|6|1|0|2024-07-01T00:00:00',
            '2024,12,31,23,59,59,500000000|3|1|0|2025-01-01T00:00:00',
            '2024,2,28,23,52,30,0|4|15|0|2024-02-29T00:00:00',
            '2024,6,30,12,0,0,0|6|1|1|2024-06-30T00:00:00',
            '2024,6,30,11,59,59,999999999|6|1|1|2024-06-30T00:00:00',
            '2024,12,31,23,59,59,500000000|3|1|1|2024-12-31T23:59:59',
            '2024,2,28,23,52,30,0|4|15|1|2024-02-28T23:45:00',
            '2024,6,30,12,0,0,0|6|1|2|2024-07-01T00:00:00',
            '2024,6,30,11,59,59,999999999|6|1|2|2024-07-01T00:00:00',
            '2024,12,31,23,59,59,500000000|3|1|2|2025-01-01T00:00:00',
            '2024,2,28,23,52,30,0|4|15|2|2024-02-29T00:00:00',
            '2024,6,30,12,0,0,0|6|1|3|2024-06-30T00:00:00',
            '2024,6,30,11,59,59,999999999|6|1|3|2024-06-30T00:00:00',
            '2024,12,31,23,59,59,500000000|3|1|3|2024-12-31T23:59:59',
            '2024,2,28,23,52,30,0|4|15|3|2024-02-28T23:45:00',
            '2024,6,30,12,0,0,0|6|1|4|2024-07-01T00:00:00',
            '2024,6,30,11,59,59,999999999|6|1|4|2024-06-30T00:00:00',
            '2024,12,31,23,59,59,500000000|3|1|4|2025-01-01T00:00:00',
            '2024,2,28,23,52,30,0|4|15|4|2024-02-29T00:00:00',
            '2024,6,30,12,0,0,0|6|1|5|2024-06-30T00:00:00',
            '2024,6,30,11,59,59,999999999|6|1|5|2024-06-30T00:00:00',
            '2024,12,31,23,59,59,500000000|3|1|5|2024-12-31T23:59:59',
            '2024,2,28,23,52,30,0|4|15|5|2024-02-28T23:45:00',
            '2024,6,30,12,0,0,0|6|1|6|2024-07-01T00:00:00',
            '2024,6,30,11,59,59,999999999|6|1|6|2024-06-30T00:00:00',
            '2024,12,31,23,59,59,500000000|3|1|6|2025-01-01T00:00:00',
            '2024,2,28,23,52,30,0|4|15|6|2024-02-29T00:00:00',
            '2024,6,30,12,0,0,0|6|1|7|2024-06-30T00:00:00',
            '2024,6,30,11,59,59,999999999|6|1|7|2024-06-30T00:00:00',
            '2024,12,31,23,59,59,500000000|3|1|7|2024-12-31T23:59:59',
            '2024,2,28,23,52,30,0|4|15|7|2024-02-28T23:45:00',
            '2024,6,30,12,0,0,0|6|1|8|2024-06-30T00:00:00',
            '2024,6,30,11,59,59,999999999|6|1|8|2024-06-30T00:00:00',
            '2024,12,31,23,59,59,500000000|3|1|8|2025-01-01T00:00:00',
            '2024,2,28,23,52,30,0|4|15|8|2024-02-29T00:00:00',
            '9999,12,31,23,59,59,999999999|6|1|0|ERR:R:epoch',
            '-9999,1,1,0,0,0,0|6|1|0|-009999-01-01T00:00:00',
            '9999,12,31,23,59,59,999999999|6|1|1|9999-12-31T00:00:00',
            '-9999,1,1,0,0,0,0|6|1|1|-009999-01-01T00:00:00',
            '9999,12,31,23,59,59,999999999|6|1|2|ERR:R:epoch',
            '-9999,1,1,0,0,0,0|6|1|2|-009999-01-01T00:00:00',
            '9999,12,31,23,59,59,999999999|6|1|3|9999-12-31T00:00:00',
            '-9999,1,1,0,0,0,0|6|1|3|-009999-01-01T00:00:00',
            '9999,12,31,23,59,59,999999999|6|1|4|ERR:R:epoch',
            '-9999,1,1,0,0,0,0|6|1|4|-009999-01-01T00:00:00',
            '9999,12,31,23,59,59,999999999|6|1|5|ERR:R:epoch',
            '-9999,1,1,0,0,0,0|6|1|5|-009999-01-01T00:00:00',
            '9999,12,31,23,59,59,999999999|6|1|6|ERR:R:epoch',
            '-9999,1,1,0,0,0,0|6|1|6|-009999-01-01T00:00:00',
            '9999,12,31,23,59,59,999999999|6|1|7|ERR:R:epoch',
            '-9999,1,1,0,0,0,0|6|1|7|-009999-01-01T00:00:00',
            '9999,12,31,23,59,59,999999999|6|1|8|ERR:R:epoch',
            '-9999,1,1,0,0,0,0|6|1|8|-009999-01-01T00:00:00',
            '9999,12,31,23,59,59,999999999|0|1|6|9999-12-31T23:59:59.999999999',
            '9999,12,31,23,59,59,999999999|0|2|6|ERR:R:epoch',
            '9999,12,31,23,59,59,999999999|1|1|6|ERR:R:epoch',
            '9999,12,31,23,59,59,999999999|5|12|6|ERR:R:epoch',
            '9999,12,31,11,59,59,999999999|6|1|6|9999-12-31T00:00:00',
            '9999,12,30,23,59,59,999999999|3|1|6|9999-12-31T00:00:00',
            '1,1,1,15,0,0,0|6|1|6|0001-01-02T00:00:00',
            '1,1,1,10,0,0,0|6|1|6|0001-01-01T00:00:00',
            '1,1,1,10,0,0,0|6|1|0|0001-01-02T00:00:00',
            '1,1,1,23,59,59,999999999|3|1|6|0001-01-02T00:00:00',
            '1,1,1,23,59,59,999999999|5|1|3|0001-01-01T23:00:00',
            '0,6,19,15,0,0,0|6|1|6|0000-06-19T00:00:00',
            '0,6,19,10,0,0,0|6|1|6|0000-06-19T00:00:00',
            '0,6,19,10,0,0,0|6|1|0|0000-06-19T00:00:00',
            '0,6,19,23,59,59,999999999|3|1|6|0000-06-19T00:00:00',
            '0,6,19,23,59,59,999999999|5|1|3|0000-06-19T23:00:00',
            '0,1,1,15,0,0,0|6|1|6|0000-01-01T00:00:00',
            '0,1,1,10,0,0,0|6|1|6|0000-01-01T00:00:00',
            '0,1,1,10,0,0,0|6|1|0|0000-01-01T00:00:00',
            '0,1,1,23,59,59,999999999|3|1|6|0000-01-01T00:00:00',
            '0,1,1,23,59,59,999999999|5|1|3|0000-01-01T23:00:00',
            '-1,6,19,15,0,0,0|6|1|6|-000001-06-18T00:00:00',
            '-1,6,19,10,0,0,0|6|1|6|-000001-06-19T00:00:00',
            '-1,6,19,10,0,0,0|6|1|0|-000001-06-18T00:00:00',
            '-1,6,19,23,59,59,999999999|3|1|6|-000001-06-18T00:00:00',
            '-1,6,19,23,59,59,999999999|5|1|3|-000001-06-19T23:00:00',
            '-1,1,1,15,0,0,0|6|1|6|-000002-12-31T00:00:00',
            '-1,1,1,10,0,0,0|6|1|6|-000001-01-01T00:00:00',
            '-1,1,1,10,0,0,0|6|1|0|-000002-12-31T00:00:00',
            '-1,1,1,23,59,59,999999999|3|1|6|-000002-12-31T00:00:00',
            '-1,1,1,23,59,59,999999999|5|1|3|-000001-01-01T23:00:00',
            '-1,12,31,15,0,0,0|6|1|6|-000001-12-30T00:00:00',
            '-1,12,31,10,0,0,0|6|1|6|-000001-12-31T00:00:00',
            '-1,12,31,10,0,0,0|6|1|0|-000001-12-30T00:00:00',
            '-1,12,31,23,59,59,999999999|3|1|6|-000001-12-30T00:00:00',
            '-1,12,31,23,59,59,999999999|5|1|3|-000001-12-31T23:00:00',
            '-9999,1,1,15,0,0,0|6|1|6|ERR:R:year',
            '-9999,1,1,10,0,0,0|6|1|6|-009999-01-01T00:00:00',
            '-9999,1,1,10,0,0,0|6|1|0|ERR:R:year',
            '-9999,1,1,23,59,59,999999999|3|1|6|ERR:R:year',
            '-9999,1,1,23,59,59,999999999|5|1|3|-009999-01-01T23:00:00',
            '-9999,1,2,15,0,0,0|6|1|6|-009999-01-01T00:00:00',
            '-9999,1,2,10,0,0,0|6|1|6|-009999-01-02T00:00:00',
            '-9999,1,2,10,0,0,0|6|1|0|-009999-01-01T00:00:00',
            '-9999,1,2,23,59,59,999999999|3|1|6|-009999-01-01T00:00:00',
            '-9999,1,2,23,59,59,999999999|5|1|3|-009999-01-02T23:00:00',
            '1945,6,1,23,59,59,999999999|2|4|4|1945-06-02T00:00:00',
            '807,2,28,22,30,33,336219314|6|1|7|0807-03-01T00:00:00',
            '2090,12,3,11,6,39,500000|3|4|4|2090-12-03T11:06:40',
            '2083,3,27,12,40,6,59905640|1|5|8|2083-03-27T12:40:06.059905',
            '2,9,23,0,0,0,0|3|6|8|0002-09-23T00:00:00',
            '2034,9,24,17,0,10,511165157|2|20|2|2034-09-24T17:00:10.52',
            '1995,2,12,19,59,19,179762669|0|40|8|1995-02-12T19:59:19.17976268',
            '1982,5,3,13,59,30,395840462|0|500|3|1982-05-03T13:59:30.39584',
            '2078,7,12,5,0,59,182209330|1|5|4|2078-07-12T05:00:59.18221',
            '1904,11,28,11,27,16,855677351|6|1|1|1904-11-28T00:00:00',
            '1976,12,28,11,45,0,130959203|2|200|3|1976-12-28T11:45:00',
            '-3,1,31,8,55,30,371454055|2|1|1|-000003-01-31T08:55:30.371',
            '1925,9,6,21,30,13,633772164|1|125|6|1925-09-06T21:30:13.63375',
            '1927,12,20,9,12,59,532745436|0|1|5|1927-12-20T09:12:59.532745436',
            '2026,11,14,6,13,43,0|4|6|4|2026-11-14T06:12:00',
            '2008,10,23,3,5,59,752423104|1|25|7|2008-10-23T03:05:59.752425',
            '2042,8,21,0,0,0,0|0|100|3|2042-08-21T00:00:00',
            '1908,4,30,23,59,59,999999999|4|1|0|1908-05-01T00:00:00',
            '6422,1,31,14,1,50,0|2|1|8|6422-01-31T14:01:50',
            '1936,11,7,12,30,37,665292061|4|2|7|1936-11-07T12:30:00',
            '5831,12,1,22,36,46,144505611|0|4|8|5831-12-01T22:36:46.144505612',
            '1925,7,31,5,30,35,68622008|0|125|3|1925-07-31T05:30:35.068622',
            '9969,4,30,2,55,0,250284720|3|4|3|9969-04-30T02:55:00',
            '2091,11,30,7,9,5,999999999|1|1|1|2091-11-30T07:09:05.999999',
            '2016,1,21,7,41,11,123456789|2|100|5|2016-01-21T07:41:11.1',
            '1901,12,19,18,2,37,240807175|4|6|2|1901-12-19T18:06:00',
            '1977,12,6,0,0,0,0|5|1|6|1977-12-06T00:00:00',
            '-8133,6,30,4,16,2,500000|3|10|5|-008133-06-30T04:16:00',
            '2032,6,2,0,0,0,0|0|5|8|2032-06-02T00:00:00',
            '-9601,7,3,14,0,15,760844692|1|1|2|-009601-07-03T14:00:15.760845',
            '2086,11,5,23,9,30,595154441|0|40|0|2086-11-05T23:09:30.59515448',
            '1979,12,21,23,59,59,999999999|4|4|8|1979-12-22T00:00:00',
            '2068,2,2,16,59,59,500000|2|8|0|2068-02-02T16:59:59.008',
            '1976,1,23,2,0,24,416875263|3|6|0|1976-01-23T02:00:30',
            '1920,5,7,20,30,9,500000|4|12|0|1920-05-07T20:36:00',
            '2082,11,30,3,44,58,901507841|1|4|5|2082-11-30T03:44:58.901508',
            '1974,8,17,18,59,27,0|4|30|1|1974-08-17T18:30:00',
            '1925,3,31,23,59,35,939214433|2|250|4|1925-03-31T23:59:36',
            '1900,10,21,19,59,59,500|4|1|5|1900-10-21T20:00:00',
            '1976,10,31,13,56,48,500000|3|30|5|1976-10-31T13:57:00',
            '1929,9,27,12,31,33,239014549|0|5|6|1929-09-27T12:31:33.23901455',
            '2038,1,10,3,38,30,485826907|4|6|6|2038-01-10T03:36:00',
            '2070,5,31,18,30,12,894195285|4|10|6|2070-05-31T18:30:00',
            '-2340,11,30,8,55,28,172364626|4|12|2|-002340-11-30T09:00:00',
            '4014,1,19,4,53,21,605822827|5|3|7|4014-01-19T06:00:00',
            '1938,10,31,0,0,0,0|5|8|0|1938-10-31T00:00:00',
            '1964,12,29,16,15,42,0|5|12|7|1964-12-29T12:00:00',
            '1955,7,31,9,36,18,500000|4|3|6|1955-07-31T09:36:00',
            '1905,8,14,3,28,51,500|2|200|4|1905-08-14T03:28:51',
            '2055,4,13,5,30,30,497493223|3|30|8|2055-04-13T05:30:30',
            '2028,5,6,12,1,25,293410975|1|5|8|2028-05-06T12:01:25.29341',
            '8915,2,28,0,0,0,0|6|1|7|8915-02-28T00:00:00',
            '1915,8,31,0,0,0,0|2|200|0|1915-08-31T00:00:00',
            '2029,4,18,3,16,41,500000|6|1|1|2029-04-18T00:00:00',
            '2059,7,21,0,0,0,0|3|12|2|2059-07-21T00:00:00',
            '2085,1,16,0,0,0,0|3|20|3|2085-01-16T00:00:00',
            '-4172,10,6,3,29,59,565796632|4|2|2|-004172-10-06T03:30:00',
            '1956,8,5,10,50,0,372521466|4|6|8|1956-08-05T10:48:00',
            '2013,11,10,23,59,59,999999999|2|25|0|2013-11-11T00:00:00',
            '2016,2,29,0,0,0,0|2|200|6|2016-02-29T00:00:00',
            '2026,12,30,14,0,24,723939477|1|100|4|2026-12-30T14:00:24.7239',
            '-4625,7,31,0,0,0,0|0|250|0|-004625-07-31T00:00:00',
            '1956,12,31,19,33,11,500|3|3|1|1956-12-31T19:33:09',
            '1932,10,24,23,28,0,231441725|1|50|0|1932-10-24T23:28:00.23145',
            '1987,6,9,13,0,30,974539345|6|1|8|1987-06-10T00:00:00',
            '2096,11,30,14,0,20,361805217|1|25|8|2096-11-30T14:00:20.3618',
            '2041,9,3,10,39,2,500000000|6|1|6|2041-09-03T00:00:00',
            '2028,7,30,7,30,24,313558451|5|3|8|2028-07-30T09:00:00',
            '1998,12,18,9,45,49,123456789|6|1|6|1998-12-18T00:00:00',
            '2008,10,3,22,0,34,166851283|4|6|8|2008-10-03T22:00:00'
        };
        Assert.isTrue(rows.size() >= 160, 'expected the full vector set');
        List<JiffUnit> units = JiffUnit.values();
        List<JiffRoundMode> modes = JiffRoundMode.values();
        for (String row : rows) {
            List<String> f = row.split('\\|');
            JiffRound options = JiffRound.to(units.get(Integer.valueOf(f.get(1))))
                .increment(Long.valueOf(f.get(2)))
                .mode(modes.get(Integer.valueOf(f.get(3))));
            Assert.areEqual(
                expand(f.get(4)),
                tryRound(parseCivil(f.get(0)), options),
                'rounding of ' + row
            );
        }
    }
}
