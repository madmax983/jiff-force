@IsTest
private class JiffDateTimeArithmeticTest {
    private static final String YEAR_RANGE = 'parameter \'year\' is not in the required range of -9999..=9999';
    private static final String EPOCH_DAY_RANGE = 'parameter \'Unix epoch days\' is not in the required range of -4371587..=2932896';
    private static final String DAYS_RANGE = 'parameter \'days\' is not in the required range of -7304484..=7304484';

    // The pieces Jiff's error messages are built from, keyed by the abbreviations the vector
    // tables use: `ERR:O:year` is "failed to add overflowing span: parameter 'year' ...".
    private static final Map<String, String> ERROR_TEXT = new Map<String, String>{
        'D' => 'failed to add span to date',
        'T' => 'failed to add span to time',
        'O' => 'failed to add overflowing span',
        'OD' => 'failed to add overflowing duration',
        'DD' => 'number of days derived from duration exceed\'s Jiff\'s datetime limits',
        'U' => 'unsigned duration exceeds Jiff\'s limits',
        'year' => YEAR_RANGE,
        'epoch' => EPOCH_DAY_RANGE,
        'days' => DAYS_RANGE,
        'months' => 'parameter \'months\' is not in the required range of -239976..=239976',
        'nanos' => 'parameter \'nanoseconds\' is not in the required range of ' +
        '-9223372036854775807..=9223372036854775807',
        'secs' => 'parameter \'signed duration seconds\' is not in the required range of ' +
        '-9223372036854775808..=9223372036854775807'
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

    /** Parses the `year,month,day,hour,minute,second,nanosecond` form the vector tables use. */
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

    /** Parses a span given as its ten units from years down to nanoseconds. */
    private static JiffSpan parseSpan(String text) {
        List<String> parts = text.split(',');
        return new JiffSpan()
            .years(Long.valueOf(parts.get(0)))
            .months(Long.valueOf(parts.get(1)))
            .weeks(Long.valueOf(parts.get(2)))
            .days(Long.valueOf(parts.get(3)))
            .hours(Long.valueOf(parts.get(4)))
            .minutes(Long.valueOf(parts.get(5)))
            .seconds(Long.valueOf(parts.get(6)))
            .milliseconds(Long.valueOf(parts.get(7)))
            .microseconds(Long.valueOf(parts.get(8)))
            .nanoseconds(Long.valueOf(parts.get(9)));
    }

    /** Formats a span the way `parseSpan` reads it, so that every unit is compared. */
    private static String fields(JiffSpan span) {
        return String.join(
            new List<Long>{
                span.getYears(),
                span.getMonths(),
                span.getWeeks(),
                span.getDays(),
                span.getHours(),
                span.getMinutes(),
                span.getSeconds(),
                span.getMilliseconds(),
                span.getMicroseconds(),
                span.getNanoseconds()
            },
            ','
        );
    }

    private static JiffSignedDuration parseDuration(String text) {
        List<String> parts = text.split(',');
        return JiffSignedDuration.newInstance(
            Long.valueOf(parts.get(0)),
            Integer.valueOf(parts.get(1))
        );
    }

    /**
     * What a vector says Jiff produced: the text of a value, or `ERR:` followed by the whole
     * error message that the vector abbreviates.
     */
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

    /** What a saturating column says: `=` for the checked result, or one of the limits. */
    private static String saturated(String column, String checked) {
        if (column.equals('=')) {
            return checked;
        }
        return (column.equals('MIN') ? JiffDateTime.MIN : JiffDateTime.MAX).toString();
    }

    private static String tryAdd(JiffDateTime start, JiffSpan span) {
        try {
            return start.add(span).toString();
        } catch (JiffException e) {
            return 'ERR:' + e.getMessage();
        }
    }

    private static String trySubtract(JiffDateTime start, JiffSpan span) {
        try {
            return start.subtract(span).toString();
        } catch (JiffException e) {
            return 'ERR:' + e.getMessage();
        }
    }

    private static String tryAdd(JiffDateTime start, JiffSignedDuration duration) {
        try {
            return start.add(duration).toString();
        } catch (JiffException e) {
            return 'ERR:' + e.getMessage();
        }
    }

    private static String trySubtract(JiffDateTime start, JiffSignedDuration duration) {
        try {
            return start.subtract(duration).toString();
        } catch (JiffException e) {
            return 'ERR:' + e.getMessage();
        }
    }

    private static String tryUntil(JiffDateTime start, JiffDateTime other, JiffUnit largest) {
        try {
            return fields(start.until(other, largest));
        } catch (JiffException e) {
            return 'ERR:' + e.getMessage();
        }
    }

    // ---- add(JiffSpan) ---------------------------------------------------

    @IsTest
    static void addsCalendarAndClockUnitsTogether() {
        JiffDateTime dt = civil(1995, 12, 7, 3, 24, 30, 3500);
        Assert.areEqual(
            civil(2016, 4, 7, 3, 24, 30, 4000),
            dt.add(new JiffSpan().years(20).months(4).nanoseconds(500))
        );
    }

    @IsTest
    static void addingAMonthClampsToTheLastDayAndKeepsTheTime() {
        Assert.areEqual(
            civil(2019, 2, 28, 15, 30, 0, 0),
            civil(2019, 1, 31, 15, 30, 0, 0).add(new JiffSpan().months(1))
        );
        Assert.areEqual(
            atHour(2025, 2, 28, 0),
            atHour(2024, 2, 29, 0).add(new JiffSpan().years(1))
        );
    }

    @IsTest
    static void addingANegativeSpanMovesBackward() {
        Assert.areEqual(
            civil(2024, 2, 29, 19, 5, 59, 999999999),
            civil(2024, 3, 31, 19, 5, 59, 999999999).add(new JiffSpan().months(-1))
        );
    }

    @IsTest
    static void timeUnitsCarryIntoTheDate() {
        Assert.areEqual(
            atHour(2024, 2, 29, 0),
            atHour(2024, 2, 28, 23).add(new JiffSpan().hours(1))
        );
        Assert.areEqual(
            atHour(2024, 3, 1, 0),
            atHour(2024, 2, 28, 23).add(new JiffSpan().hours(25))
        );
        Assert.areEqual(
            civil(2024, 2, 29, 23, 30, 0, 0),
            civil(2024, 3, 1, 0, 30, 0, 0).add(new JiffSpan().hours(-1))
        );
        Assert.areEqual(
            atHour(2024, 1, 1, 0),
            civil(2023, 12, 31, 23, 59, 59, 999999999).add(new JiffSpan().nanoseconds(1))
        );
        Assert.areEqual(
            civil(2023, 12, 31, 23, 59, 59, 999999999),
            atHour(2024, 1, 1, 0).add(new JiffSpan().nanoseconds(-1))
        );
    }

    @IsTest
    static void theCarriedDaysAreAddedAfterTheCalendarUnits() {
        // January 31st plus a month is clamped to February 29th, and only then does the hour
        // that ran past midnight move the date on to March 1st.
        Assert.areEqual(
            civil(2024, 3, 1, 0, 30, 0, 0),
            civil(2024, 1, 31, 23, 30, 0, 0).add(new JiffSpan().months(1).hours(1))
        );
        Assert.areEqual(
            civil(2024, 2, 28, 23, 30, 0, 0),
            civil(2024, 3, 31, 0, 30, 0, 0).add(new JiffSpan().months(-1).hours(-1))
        );
    }

    @IsTest
    static void addingAZeroSpanReturnsTheSameDatetime() {
        Assert.areEqual(JiffDateTime.MAX, JiffDateTime.MAX.add(new JiffSpan()));
        Assert.areEqual(JiffDateTime.MIN, JiffDateTime.MIN.subtract(new JiffSpan()));
        JiffDateTime dt = civil(2024, 3, 31, 13, 13, 13, 13);
        Assert.areEqual(dt, dt.add(new JiffSpan().days(0).hours(0)));
    }

    @IsTest
    static void addingBeyondTheSupportedRangeFails() {
        JiffDateTime dt = civil(2024, 3, 31, 13, 13, 13, 13);
        Assert.areEqual(
            'ERR:failed to add span to date: ' + YEAR_RANGE,
            tryAdd(dt, new JiffSpan().years(9000))
        );
        Assert.areEqual(
            'ERR:failed to add span to date: ' + YEAR_RANGE,
            tryAdd(dt, new JiffSpan().years(-19000))
        );
    }

    @IsTest
    static void aFailureNamesTheStepThatFailed() {
        // Calendar units that take the date out of range.
        Assert.areEqual(
            'ERR:failed to add span to date: ' + YEAR_RANGE,
            tryAdd(JiffDateTime.MAX, new JiffSpan().days(1))
        );
        Assert.areEqual(
            'ERR:failed to add span to date: ' + EPOCH_DAY_RANGE,
            tryAdd(JiffDateTime.MAX, new JiffSpan().days(2))
        );
        // Time units whose carry takes the date out of range.
        Assert.areEqual(
            'ERR:failed to add overflowing span: ' + YEAR_RANGE,
            tryAdd(JiffDateTime.MAX, new JiffSpan().nanoseconds(1))
        );
        Assert.areEqual(
            'ERR:failed to add overflowing span: ' + YEAR_RANGE,
            tryAdd(JiffDateTime.MIN, new JiffSpan().nanoseconds(-1))
        );
        Assert.areEqual(
            'ERR:failed to add overflowing span: ' + EPOCH_DAY_RANGE,
            tryAdd(JiffDateTime.MAX, new JiffSpan().hours(48))
        );
        // Time units that add up to more days than a span can hold.
        JiffSpan tooLong = new JiffSpan().hours(175307616L).minutes(10518456960L);
        JiffDateTime dt = atHour(2024, 6, 19, 12);
        Assert.areEqual('ERR:failed to add span to time: ' + DAYS_RANGE, tryAdd(dt, tooLong));
        // The time of day is added first, so its failure is the one reported.
        Assert.areEqual(
            'ERR:failed to add span to time: ' + DAYS_RANGE,
            tryAdd(dt, tooLong.years(9000))
        );
        // And the calendar units fail before the carried days do.
        Assert.areEqual(
            'ERR:failed to add span to date: ' + YEAR_RANGE,
            tryAdd(JiffDateTime.MAX, new JiffSpan().days(1).nanoseconds(1))
        );
    }

    @IsTest
    static void reachesEitherLimitFromTheOther() {
        JiffSpan everything = new JiffSpan()
            .years(19998)
            .months(11)
            .days(30)
            .hours(23)
            .minutes(59)
            .seconds(59)
            .nanoseconds(999999999);
        Assert.areEqual(JiffDateTime.MAX, JiffDateTime.MIN.add(everything));
        Assert.areEqual(JiffDateTime.MIN, JiffDateTime.MAX.subtract(everything));
        Assert.areEqual(
            atHour(9999, 12, 31, 23),
            JiffDateTime.MIN.add(new JiffSpan().hours(175307615L))
        );
    }

    @IsTest
    static void addAndSubtractSpansMatchJiff() {
        // Produced by Jiff 1.0.0, and replayed against it by `npm run oracle:check`. Each row is
        //   start | span | checked_add | checked_sub | saturating_add | saturating_sub
        // with the start as `year,month,day,hour,minute,second,nanosecond` and the span as
        // its ten units from years down to nanoseconds. A result is the datetime as Jiff
        // prints it or the abbreviated error; a saturating result is `=` when it equals the
        // checked one, and otherwise the limit it stopped at.
        List<String> rows = new List<String>{
            '1995,12,7,3,24,30,3500|20,4,0,0,0,0,0,0,0,500|2016-04-07T03:24:30.000004|1975-08-07T03:24:30.000003|=|=',
            '2019,1,31,15,30,0,0|0,1,0,0,0,0,0,0,0,0|2019-02-28T15:30:00|2018-12-31T15:30:00|=|=',
            '2024,3,31,19,5,59,999999999|0,-1,0,0,0,0,0,0,0,0|2024-02-29T19:05:59.999999999|2024-04-30T19:05:59.999999999|=|=',
            '2024,3,31,13,13,13,13|9000,0,0,0,0,0,0,0,0,0|ERR:D:year|-006976-03-31T13:13:13.000000013|MAX|=',
            '2024,3,31,13,13,13,13|-19000,0,0,0,0,0,0,0,0,0|ERR:D:year|ERR:D:year|MIN|MAX',
            '2024,3,31,13,13,13,13|9000,0,0,0,1,0,0,0,0,0|ERR:D:year|-006976-03-31T12:13:13.000000013|MAX|=',
            '2024,3,31,13,13,13,13|0,0,0,0,0,0,0,0,0,0|2024-03-31T13:13:13.000000013|2024-03-31T13:13:13.000000013|=|=',
            '2024,2,29,0,0,0,0|1,0,0,0,0,0,0,0,0,0|2025-02-28T00:00:00|2023-02-28T00:00:00|=|=',
            '2024,2,28,23,0,0,0|0,0,0,0,1,0,0,0,0,0|2024-02-29T00:00:00|2024-02-28T22:00:00|=|=',
            '2024,2,28,23,0,0,0|0,0,0,0,25,0,0,0,0,0|2024-03-01T00:00:00|2024-02-27T22:00:00|=|=',
            '2024,3,1,0,30,0,0|0,0,0,0,-1,0,0,0,0,0|2024-02-29T23:30:00|2024-03-01T01:30:00|=|=',
            '2024,1,31,23,30,0,0|0,1,0,0,1,0,0,0,0,0|2024-03-01T00:30:00|2023-12-31T22:30:00|=|=',
            '2024,3,31,0,30,0,0|0,-1,0,0,-1,0,0,0,0,0|2024-02-28T23:30:00|2024-04-30T01:30:00|=|=',
            '2023,12,31,23,59,59,999999999|0,0,0,0,0,0,0,0,0,1|2024-01-01T00:00:00|2023-12-31T23:59:59.999999998|=|=',
            '2024,1,1,0,0,0,0|0,0,0,0,0,0,0,0,0,-1|2023-12-31T23:59:59.999999999|2024-01-01T00:00:00.000000001|=|=',
            '9999,12,31,23,59,59,999999999|0,0,0,0,0,0,0,0,0,1|ERR:O:year|9999-12-31T23:59:59.999999998|MAX|=',
            '-9999,1,1,0,0,0,0|0,0,0,0,0,0,0,0,0,-1|ERR:O:year|-009999-01-01T00:00:00.000000001|MIN|=',
            '9999,12,31,23,59,59,999999999|0,0,0,1,0,0,0,0,0,0|ERR:D:year|9999-12-30T23:59:59.999999999|MAX|=',
            '9999,12,31,23,59,59,999999999|0,0,0,2,0,0,0,0,0,0|ERR:D:epoch|9999-12-29T23:59:59.999999999|MAX|=',
            '-9999,1,1,0,0,0,0|0,0,0,-1,0,0,0,0,0,0|ERR:D:year|-009999-01-02T00:00:00|MIN|=',
            '-9999,1,1,0,0,0,0|0,0,0,-2,0,0,0,0,0,0|ERR:D:epoch|-009999-01-03T00:00:00|MIN|=',
            '9999,12,31,23,59,59,999999999|0,0,0,1,0,0,0,0,0,1|ERR:D:year|9999-12-30T23:59:59.999999998|MAX|=',
            '9999,12,31,23,59,59,999999999|0,0,0,0,48,0,0,0,0,0|ERR:O:epoch|9999-12-29T23:59:59.999999999|MAX|=',
            '-9999,1,1,0,0,0,0|0,0,0,0,-48,0,0,0,0,0|ERR:O:epoch|-009999-01-03T00:00:00|MIN|=',
            '9999,12,31,23,59,59,999999999|0,0,0,1,24,0,0,0,0,0|ERR:D:year|9999-12-29T23:59:59.999999999|MAX|=',
            '9999,12,31,23,59,59,999999999|0,-1,0,0,-800,0,0,0,0,0|9999-10-28T15:59:59.999999999|ERR:D:year|=|MAX',
            '-9999,1,1,0,0,0,0|0,0,0,0,175307616,0,0,0,0,0|ERR:O:epoch|ERR:O:epoch|MAX|MIN',
            '-9999,1,1,0,0,0,0|0,0,0,0,175307615,0,0,0,0,0|9999-12-31T23:00:00|ERR:O:epoch|=|MIN',
            '9999,12,31,23,59,59,999999999|0,0,0,0,-175307616,0,0,0,0,0|ERR:O:epoch|ERR:O:epoch|MIN|MAX',
            '9999,12,31,23,59,59,999999999|0,0,0,0,-175307615,-59,-59,0,0,-999999999|-009999-01-01T00:00:00|ERR:O:epoch|=|MAX',
            '-9999,1,1,0,0,0,0|19998,11,0,30,23,59,59,0,0,999999999|9999-12-31T23:59:59.999999999|ERR:D:year|=|MIN',
            '9999,12,31,23,59,59,999999999|-19998,-11,0,-30,-23,-59,-59,0,0,-999999999|-009999-01-01T00:00:00|ERR:D:year|=|MAX',
            '-9999,1,1,0,0,0,0|0,0,0,7304483,23,59,59,0,0,999999999|9999-12-31T23:59:59.999999999|ERR:D:epoch|=|MIN',
            '-9999,1,1,0,0,0,0|0,0,0,7304484,0,0,0,0,0,0|ERR:D:epoch|ERR:D:epoch|MAX|MIN',
            '2024,6,19,12,0,0,0|0,0,0,0,175307616,10518456960,0,0,0,0|ERR:T:days|ERR:T:days|MAX|MIN',
            '2024,6,19,12,0,0,0|0,0,0,0,-175307616,-10518456960,0,0,0,0|ERR:T:days|ERR:T:days|MIN|MAX',
            '2024,6,19,12,0,0,0|9000,0,0,0,175307616,10518456960,0,0,0,0|ERR:T:days|ERR:T:days|MAX|MIN',
            '2024,6,19,12,0,0,0|0,0,0,0,0,0,0,0,0,9223372036854775807|2316-09-29T11:47:16.854775807|1732-03-10T12:12:43.145224193|=|=',
            '2024,6,19,12,0,0,0|0,0,0,0,0,0,0,0,0,-9223372036854775807|1732-03-10T12:12:43.145224193|2316-09-29T11:47:16.854775807|=|=',
            '2024,6,19,12,0,0,0|0,0,0,0,0,0,0,0,631107417600000000,0|ERR:O:epoch|ERR:O:epoch|MAX|MIN',
            '-9999,1,1,12,0,0,0|0,0,0,0,0,0,631107374399,0,0,0|9999-12-31T23:59:59|ERR:O:epoch|=|MIN',
            '-9999,1,1,12,0,0,0|0,0,0,0,0,0,631107374400,0,0,0|ERR:O:epoch|ERR:O:epoch|MAX|MIN',
            '2024,6,19,12,0,0,0|0,0,1,0,0,0,0,0,0,0|2024-06-26T12:00:00|2024-06-12T12:00:00|=|=',
            '2024,6,19,12,0,0,0|0,0,3,0,36,0,0,0,0,0|2024-07-12T00:00:00|2024-05-28T00:00:00|=|=',
            '0,1,1,0,0,0,0|0,0,0,0,0,0,0,0,0,-1|-000001-12-31T23:59:59.999999999|0000-01-01T00:00:00.000000001|=|=',
            '-1,12,31,23,59,59,999999999|0,0,0,0,0,0,0,0,0,1|0000-01-01T00:00:00|-000001-12-31T23:59:59.999999998|=|=',
            '1918,1,9,19,1,30,22449183|0,0,0,78,79,0,0,0,0,60590810728494|1918-04-01T18:51:20.833177677|1917-10-19T19:11:39.211720689|=|=',
            '1914,3,9,9,52,50,591826348|0,0,0,0,0,0,0,79950483,0,0|1914-03-10T08:05:21.074826348|1914-03-08T11:40:20.108826348|=|=',
            '2090,11,9,3,34,30,500000|0,0,0,0,0,0,0,0,0,0|2090-11-09T03:34:30.0005|2090-11-09T03:34:30.0005|=|=',
            '1958,10,15,10,22,8,500000|-25,0,0,-21,0,0,0,-80895057,0,-104906767012003|1933-09-22T06:45:26.176487997|1983-11-07T13:58:49.824512003|=|=',
            '1905,3,9,1,0,59,706726541|-4,0,0,-304,0,0,-43094,0,0,-146605046068799|1900-05-06T20:19:20.660657742|1910-01-09T05:42:38.75279534|=|=',
            '8503,4,30,1,7,28,936859899|0,0,39,0,0,0,0,0,0,0|8504-01-28T01:07:28.936859899|8502-07-31T01:07:28.936859899|=|=',
            '1925,2,21,22,24,36,166622381|0,0,12,0,82,0,22142,0,0,152911870184701|1925-05-22T09:02:10.036807082|1924-11-24T11:47:02.29643768|=|=',
            '2073,10,22,15,59,47,45947961|0,20,0,242,47,0,0,0,0,0|2076-02-21T14:59:47.045947961|2071-06-23T16:59:47.045947961|=|=',
            '1919,5,12,23,59,59,999999999|17,0,0,0,0,0,0,0,0,0|1936-05-12T23:59:59.999999999|1902-05-12T23:59:59.999999999|=|=',
            '1978,8,9,20,0,30,846587729|0,0,-46,0,-79,-2011,0,-72150076,0,-149771960011822|1977-09-14T13:50:48.810575907|1979-07-05T02:10:12.882599551|=|=',
            '1923,5,11,22,0,0,291040401|0,0,0,0,0,0,0,0,0,0|1923-05-11T22:00:00.291040401|1923-05-11T22:00:00.291040401|=|=',
            '1997,6,30,18,59,37,500000|0,0,0,0,0,0,0,0,0,103607373682414|1997-07-01T23:46:24.374182414|1997-06-29T14:12:49.626817586|=|=',
            '2033,5,29,11,55,29,552785722|0,0,18,0,0,0,0,0,0,0|2033-10-02T11:55:29.552785722|2033-01-23T11:55:29.552785722|=|=',
            '1940,4,30,19,35,53,858995863|1,0,0,0,42,2215,0,54818024,0,0|1941-05-04T17:44:31.882995863|1939-04-26T21:27:15.834995863|=|=',
            '1951,3,8,0,0,0,0|0,0,0,0,0,2368,0,0,0,0|1951-03-09T15:28:00|1951-03-06T08:32:00|=|=',
            '-8936,10,26,0,0,0,0|0,0,0,0,0,0,16767,13088048,0,22870531674154|-008936-10-26T14:38:45.579674154|-008936-10-25T09:21:14.420325846|=|=',
            '1911,4,30,14,19,56,486236221|0,0,0,365,0,0,75060,85821547,565505449,0|1912-05-01T11:10:43.538685221|1910-04-28T17:29:09.433787221|=|=',
            '2070,5,31,20,59,30,500|0,0,0,0,0,0,0,0,0,0|2070-05-31T20:59:30.0000005|2070-05-31T20:59:30.0000005|=|=',
            '2002,11,22,3,28,44,145398524|0,40,0,0,82,471,0,0,0,0|2006-03-25T21:19:44.145398524|1999-07-18T09:37:44.145398524|=|=',
            '2012,12,10,15,47,25,0|0,-30,-46,0,0,0,0,0,0,0|2009-07-23T15:47:25|2016-04-27T15:47:25|=|=',
            '1954,9,25,15,0,41,1|0,0,0,59,17,0,63635,0,0,0|1954-11-25T01:41:16.000000001|1954-07-27T04:20:06.000000001|=|=',
            '2041,10,7,20,39,59,1|0,38,0,0,0,0,0,0,0,0|2044-12-07T20:39:59.000000001|2038-08-07T20:39:59.000000001|=|=',
            '2073,10,19,20,59,44,1|0,0,0,0,-63,-2995,-176500,0,0,-119548208254884|2073-10-11T17:50:35.791745117|2073-10-28T00:08:52.208254885|=|=',
            '3027,3,30,7,57,45,250582312|0,0,-14,-302,-98,0,0,0,0,0|3026-02-19T05:57:45.250582312|3028-05-07T09:57:45.250582312|=|=',
            '-9704,4,30,23,59,59,999999999|27,0,0,161,0,0,80839,44597481,0,0|-009677-10-10T10:50:36.480999999|-009732-11-19T13:09:23.518999999|=|=',
            '3,4,15,17,42,56,211500451|0,-24,0,-217,0,0,0,-87950405,0,0|0000-09-09T17:17:05.806500451|0005-11-19T18:08:46.616500451|=|=',
            '2006,8,31,4,47,27,1|10,26,0,167,0,0,155497,0,0,0|2019-04-17T23:59:04.000000001|1994-01-12T09:35:50.000000001|=|=',
            '-2,6,24,23,59,59,999999999|0,0,17,0,44,0,0,0,0,0|-000002-10-23T19:59:59.999999999|-000002-02-24T03:59:59.999999999|=|=',
            '2088,5,31,2,1,44,760051798|-28,0,0,0,-38,0,0,0,0,0|2060-05-29T12:01:44.760051798|2116-06-01T16:01:44.760051798|=|=',
            '2061,2,17,23,59,59,999999999|0,0,0,-159,0,-2913,0,0,-1923015415,-195158684109534|2060-09-07T16:42:18.300475465|2061-07-31T07:17:41.699524533|=|=',
            '2007,2,28,15,33,27,65434650|-23,0,0,0,0,-332,0,0,0,0|1984-02-28T10:01:27.06543465|2030-02-28T21:05:27.06543465|=|=',
            '2052,2,17,11,0,18,134668124|0,0,0,0,-36,-1466,-121760,-40927972,0,0|2052-02-13T01:22:50.162668124|2052-02-21T20:37:46.106668124|=|=',
            '1970,7,25,8,56,25,123456789|0,0,0,0,0,0,0,0,0,-143904995808525|1970-07-23T16:58:00.127648264|1970-07-27T00:54:50.119265314|=|=',
            '1917,4,30,1,17,30,999999999|0,0,0,0,8,0,46484,0,0,143720607822708|1917-05-02T14:07:35.607822707|1917-04-27T12:27:26.392177291|=|=',
            '2014,4,11,6,26,45,999999999|0,0,0,0,28,1023,0,0,0,96481403769362|2014-04-14T06:17:47.403769361|2014-04-08T06:35:44.596230637|=|=',
            '2024,1,31,15,11,59,999999999|0,0,0,0,0,0,0,-56345787,0,0|2024-01-30T23:32:54.212999999|2024-02-01T06:51:05.786999999|=|=',
            '2007,2,28,13,0,48,500000000|0,0,0,0,0,0,38097,56240907,2193273518,0|2007-03-01T15:49:39.680518|2007-02-27T10:11:57.319482|=|=',
            '1942,9,25,12,27,0,500000|0,0,0,0,0,0,72592,0,0,0|1942-09-26T08:36:52.0005|1942-09-24T16:17:08.0005|=|=',
            '2041,11,7,20,39,59,721608781|0,18,0,334,21,0,93554,0,0,0|2044-04-07T19:39:13.721608781|2039-06-06T21:40:45.721608781|=|=',
            '1940,3,12,16,4,0,453369282|-12,0,0,0,0,-1878,0,0,0,0|1928-03-11T08:46:00.453369282|1952-03-13T23:22:00.453369282|=|=',
            '2038,12,6,23,26,37,29879523|0,0,0,0,0,1125,0,0,0,176370102042633|2038-12-09T19:11:07.131922156|2038-12-04T03:42:06.92783689|=|=',
            '1981,9,30,23,22,59,5894288|-6,0,0,0,-44,0,-33906,-61794091,0,-82268797577491|1975-09-27T01:56:50.117316797|1987-10-04T20:49:07.894471779|=|=',
            '1902,1,31,0,0,0,0|13,0,0,0,0,0,100640,0,0,0|1915-02-01T03:57:20|1889-01-29T20:02:40|=|=',
            '1944,5,31,6,0,39,1|0,0,0,0,0,-1103,-37265,-27015279,0,0|1944-05-29T17:46:18.721000001|1944-06-01T18:14:59.279000001|=|=',
            '2655,12,10,23,59,0,0|0,0,0,72,0,0,0,0,0,164835153264825|2656-02-22T21:46:15.153264825|2655-09-28T02:11:44.846735175|=|=',
            '2086,12,31,23,59,59,999999999|14,0,0,0,0,0,0,0,0,194658357774018|2101-01-03T06:04:18.357774017|2072-12-29T17:55:41.642225981|=|=',
            '2084,5,16,13,47,39,500000|0,0,-30,0,-22,-760,-169168,0,0,0|2083-10-16T04:08:11.0005|2084-12-15T23:27:07.0005|=|=',
            '1944,5,14,0,0,0,0|0,0,0,-12,0,0,-76295,0,0,-170645669397533|1944-04-29T03:24:19.330602467|1944-05-28T20:35:40.669397533|=|=',
            '1950,8,26,1,59,9,491397422|0,0,-11,0,0,0,0,0,0,-4930239400685|1950-06-10T00:36:59.251996737|1950-11-11T03:21:19.730798107|=|=',
            '-5137,8,31,14,30,0,964728010|0,35,0,0,70,1061,74860,0,0,0|-005134-08-05T02:58:40.96472801|-005140-09-26T02:01:20.96472801|=|=',
            '2012,7,24,15,18,0,1|0,0,0,0,-65,0,0,-54728665,-3227895877,0|2012-07-21T06:12:03.439123001|2012-07-28T00:23:56.560877001|=|=',
            '1966,8,21,8,30,0,353475223|0,0,0,0,-4,0,0,-15742522,0,0|1966-08-21T00:07:37.831475223|1966-08-21T16:52:22.875475223|=|=',
            '4705,3,31,0,14,33,277866275|0,0,0,0,0,2234,46467,0,0,64764714288326|4705-04-02T20:22:24.992154601|4705-03-28T04:06:41.563577949|=|=',
            '0,8,25,0,0,0,0|-26,-29,0,-261,-92,-1144,-116992,0,0,0|-000029-07-02T00:26:08|0029-10-18T23:33:52|=|=',
            '-1,7,11,18,57,30,500000000|0,10,0,0,5,1235,0,0,0,0|0000-05-12T20:32:30.5|-000002-09-10T17:22:30.5|=|=',
            '3,9,9,21,9,30,297617230|0,0,0,0,-68,-1105,0,0,0,0|0003-09-06T06:44:30.29761723|0003-09-13T11:34:30.29761723|=|=',
            '2043,2,13,1,40,38,684226415|3,0,60,0,0,0,0,0,0,0|2047-04-09T01:40:38.684226415|2038-12-20T01:40:38.684226415|=|=',
            '5467,4,4,12,47,1,123456789|-7,0,-56,0,-58,0,0,-24219792,-384632997,0|5459-03-06T19:56:56.698459789|5475-05-04T05:37:05.548453789|=|=',
            '1957,11,9,23,8,40,1|0,-32,0,0,-29,0,0,0,0,0|1955-03-08T18:08:40.000000001|1960-07-11T04:08:40.000000001|=|=',
            '7599,10,28,8,23,59,582475750|0,-23,0,0,0,0,-96600,0,0,0|7597-11-27T05:33:59.58247575|7601-09-29T11:13:59.58247575|=|='
        };
        Assert.isTrue(rows.size() >= 100, 'expected the full vector set');
        for (String row : rows) {
            List<String> f = row.split('\\|');
            JiffDateTime start = parseCivil(f.get(0));
            JiffSpan span = parseSpan(f.get(1));
            Assert.areEqual(f.get(1), fields(span), 'construction of ' + row);
            String added = tryAdd(start, span);
            String subtracted = trySubtract(start, span);
            Assert.areEqual(expand(f.get(2)), added, 'sum of ' + row);
            Assert.areEqual(expand(f.get(3)), subtracted, 'difference of ' + row);
            Assert.areEqual(
                saturated(f.get(4), added),
                start.saturatingAdd(span).toString(),
                'saturating sum of ' + row
            );
            Assert.areEqual(
                saturated(f.get(5), subtracted),
                start.saturatingSubtract(span).toString(),
                'saturating difference of ' + row
            );
        }
    }

    // ---- add(JiffSignedDuration) -----------------------------------------

    @IsTest
    static void addsAnAbsoluteDuration() {
        JiffDateTime dt = atHour(2024, 2, 29, 0);
        JiffSignedDuration dur = JiffSignedDuration.fromHours(25);
        Assert.areEqual(atHour(2024, 3, 1, 1), dt.add(dur));
        Assert.areEqual(atHour(2024, 2, 27, 23), dt.add(dur.negate()));
        Assert.areEqual(atHour(2024, 3, 1, 0), dt.add(JiffSignedDuration.fromHours(24)));
        Assert.areEqual(dt, dt.add(JiffSignedDuration.ZERO));
    }

    @IsTest
    static void aDurationThatLeavesTheSupportedRangeFails() {
        JiffDateTime dt = civil(2024, 3, 31, 13, 13, 13, 13);
        // More days than a span can hold: reported by the time of day, with no context.
        Assert.areEqual('ERR:' + DAYS_RANGE, tryAdd(dt, JiffSignedDuration.MAX));
        Assert.areEqual('ERR:' + DAYS_RANGE, tryAdd(dt, JiffSignedDuration.MIN));
        // Otherwise the date reports the carried days it cannot take.
        Assert.areEqual(
            'ERR:failed to add overflowing duration: ' + YEAR_RANGE,
            tryAdd(JiffDateTime.MAX, JiffSignedDuration.fromNanos(1))
        );
        Assert.areEqual(
            'ERR:failed to add overflowing duration: ' + YEAR_RANGE,
            tryAdd(JiffDateTime.MIN, JiffSignedDuration.fromNanos(-1))
        );
        Assert.areEqual(
            'ERR:failed to add overflowing duration: ' + EPOCH_DAY_RANGE,
            tryAdd(JiffDateTime.MAX, JiffSignedDuration.fromHours(48))
        );
        Assert.areEqual(
            'ERR:failed to add overflowing duration: number of days derived from duration ' +
                'exceed\'s Jiff\'s datetime limits: ' +
                EPOCH_DAY_RANGE,
            tryAdd(JiffDateTime.MIN, JiffSignedDuration.fromHours(24 * 2932897L))
        );
    }

    @IsTest
    static void addAndSubtractDurationsMatchJiff() {
        // Produced by Jiff 1.0.0, and replayed against it by `npm run oracle:check`. Each row is
        //   start | seconds,nanoseconds | checked_add | checked_sub | saturating_add | saturating_sub
        // in the notation of `addAndSubtractSpansMatchJiff`.
        List<String> rows = new List<String>{
            '2024,2,29,0,0,0,0|90000,0|2024-03-01T01:00:00|2024-02-27T23:00:00|=|=',
            '2024,2,29,0,0,0,0|-90000,0|2024-02-27T23:00:00|2024-03-01T01:00:00|=|=',
            '1995,12,7,3,24,30,3500|86400,3500|1995-12-08T03:24:30.000007|1995-12-06T03:24:30|=|=',
            '2024,2,29,0,0,0,0|86400,0|2024-03-01T00:00:00|2024-02-28T00:00:00|=|=',
            '2024,3,31,13,13,13,13|0,0|2024-03-31T13:13:13.000000013|2024-03-31T13:13:13.000000013|=|=',
            '2024,3,31,13,13,13,13|9223372036854775807,999999999|ERR:days|ERR:days|MAX|MIN',
            '2024,3,31,13,13,13,13|-9223372036854775808,-999999999|ERR:days|ERR:U:secs|MIN|MAX',
            '2024,3,31,13,13,13,13|-9223372036854775808,0|ERR:days|ERR:U:secs|MIN|MAX',
            '2024,3,31,13,13,13,13|-9223372036854775807,0|ERR:days|ERR:days|MIN|MAX',
            '2024,3,31,13,13,13,13|-9223372036854775807,-999999999|ERR:days|ERR:days|MIN|MAX',
            '2024,3,31,13,13,13,13|9223372036854775807,0|ERR:days|ERR:days|MAX|MIN',
            '2024,3,31,13,13,13,13|0,1|2024-03-31T13:13:13.000000014|2024-03-31T13:13:13.000000012|=|=',
            '2024,3,31,13,13,13,13|0,-14|2024-03-31T13:13:12.999999999|2024-03-31T13:13:13.000000027|=|=',
            '2024,3,31,13,13,13,13|0,-13|2024-03-31T13:13:13|2024-03-31T13:13:13.000000026|=|=',
            '9999,12,31,23,59,59,999999999|0,1|ERR:OD:year|9999-12-31T23:59:59.999999998|MAX|=',
            '-9999,1,1,0,0,0,0|0,-1|ERR:OD:year|-009999-01-01T00:00:00.000000001|MIN|=',
            '9999,12,31,23,59,59,999999999|1,0|ERR:OD:year|9999-12-31T23:59:58.999999999|MAX|=',
            '-9999,1,1,0,0,0,0|-1,0|ERR:OD:year|-009999-01-01T00:00:01|MIN|=',
            '9999,12,31,23,59,59,999999999|86400,0|ERR:OD:year|9999-12-30T23:59:59.999999999|MAX|=',
            '9999,12,31,23,59,59,999999999|172800,0|ERR:OD:epoch|9999-12-29T23:59:59.999999999|MAX|=',
            '-9999,1,1,0,0,0,0|-172800,0|ERR:OD:epoch|-009999-01-03T00:00:00|MIN|=',
            '-9999,1,1,0,0,0,0|631107417599,999999999|ERR:OD:DD:epoch|ERR:OD:DD:epoch|MAX|MIN',
            '-9999,1,1,0,0,0,0|631107417600,0|ERR:OD:DD:epoch|ERR:OD:DD:epoch|MAX|MIN',
            '9999,12,31,23,59,59,999999999|-631107417599,-999999999|ERR:OD:DD:epoch|ERR:OD:DD:epoch|MIN|MAX',
            '9999,12,31,23,59,59,999999999|-631107417600,0|ERR:OD:DD:epoch|ERR:OD:DD:epoch|MIN|MAX',
            '-9999,1,1,0,0,0,0|253402300800,0|ERR:OD:DD:epoch|ERR:OD:epoch|MAX|MIN',
            '-9999,1,1,0,0,0,0|253402214400,0|-001970-12-31T00:00:00|ERR:OD:epoch|=|MIN',
            '9999,12,31,23,59,59,999999999|-377705203200,0|ERR:OD:DD:epoch|ERR:OD:DD:epoch|MIN|MAX',
            '9999,12,31,23,59,59,999999999|-377705116800,0|-001970-12-31T23:59:59.999999999|ERR:OD:DD:epoch|=|MAX',
            '2024,3,31,13,13,13,13|631107417600,0|ERR:OD:DD:epoch|ERR:OD:DD:epoch|MAX|MIN',
            '2024,3,31,13,13,13,13|631107504000,0|ERR:days|ERR:days|MAX|MIN',
            '2024,3,31,13,13,13,13|-631107504000,0|ERR:days|ERR:days|MIN|MAX',
            '2023,12,31,23,59,59,999999999|0,1|2024-01-01T00:00:00|2023-12-31T23:59:59.999999998|=|=',
            '2024,1,1,0,0,0,0|0,-1|2023-12-31T23:59:59.999999999|2024-01-01T00:00:00.000000001|=|=',
            '2024,1,1,0,0,0,0|0,-999999999|2023-12-31T23:59:59.000000001|2024-01-01T00:00:00.999999999|=|=',
            '2024,1,1,0,0,0,0|86399,999999999|2024-01-01T23:59:59.999999999|2023-12-31T00:00:00.000000001|=|=',
            '2024,1,1,0,0,0,0|86400,0|2024-01-02T00:00:00|2023-12-31T00:00:00|=|=',
            '2070,11,30,0,19,33,237096703|-83659396,-51743180|2068-04-05T17:36:17.185353523|2073-07-25T07:02:49.288839883|=|=',
            '2066,2,21,12,30,30,500|-20779838594,0|1407-08-29T03:07:16.0000005|2724-08-18T21:53:44.0000005|=|=',
            '1990,7,13,4,0,31,741261462|-97156,-367863967|1990-07-12T01:01:15.373397495|1990-07-14T06:59:48.109125429|=|=',
            '2003,8,16,21,25,4,251299268|66993687,209834974|2005-09-30T06:46:31.461134242|2001-07-02T12:03:37.041464294|=|=',
            '2084,10,31,11,59,55,864853917|-63639,-729854875|2084-10-30T18:19:16.134999042|2084-11-01T05:40:35.594708792|=|=',
            '1974,5,31,11,2,6,999999999|96327,3723812|1974-06-01T13:47:34.003723811|1974-05-30T08:16:39.996276187|=|=',
            '2024,9,30,10,32,34,140390068|154630,0|2024-10-02T05:29:44.140390068|2024-09-28T15:35:24.140390068|=|=',
            '1925,5,31,0,0,0,0|39243799,205502814|1926-08-28T05:03:19.205502814|1924-03-02T18:56:40.794497186|=|=',
            '1915,1,10,23,59,59,999999999|158908,843362027|1915-01-12T20:08:28.843362026|1915-01-09T03:51:31.156637972|=|=',
            '-2129,3,31,16,6,50,413006363|182139,240744054|-002129-04-02T18:42:29.653750417|-002129-03-29T13:31:11.172262309|=|=',
            '1948,1,27,10,0,4,994816426|18018542,486554221|1948-08-22T23:09:07.481370647|1947-07-02T20:51:02.508262205|=|=',
            '3285,9,13,20,53,59,0|-99376,-431404656|3285-09-12T17:17:42.568595344|3285-09-15T00:30:15.431404656|=|=',
            '2029,3,29,0,0,0,0|-131688,-699962215|2029-03-27T11:25:11.300037785|2029-03-30T12:34:48.699962215|=|=',
            '2043,11,24,23,59,59,999999999|49844544,0|2045-06-23T21:42:23.999999999|2042-04-27T02:17:35.999999999|=|=',
            '1947,2,28,18,22,0,605088378|4959162,0|1947-04-27T03:54:42.605088378|1947-01-02T08:49:18.605088378|=|=',
            '1905,2,28,0,13,35,226533252|28925475793,29543389|2821-10-08T14:36:48.256076641|0988-07-18T09:50:22.196989863|=|=',
            '-7040,5,31,19,50,45,619296400|18596752673,559437422|-006451-09-22T00:28:39.178733822|-007629-02-09T15:12:52.059858978|=|=',
            '1991,12,23,0,0,0,0|125397,628222625|1991-12-24T10:49:57.628222625|1991-12-21T13:10:02.371777375|=|=',
            '2058,12,15,16,36,41,907715848|83502667,0|2061-08-08T03:47:48.907715848|2056-04-23T05:25:34.907715848|=|=',
            '2053,10,18,17,58,31,177894038|153771,589502527|2053-10-20T12:41:22.767396565|2053-10-16T23:15:39.588391511|=|=',
            '-3,8,31,11,59,51,506092570|-83140,-744345859|-000003-08-30T12:54:10.761746711|-000003-09-01T11:05:32.250438429|=|=',
            '2047,3,29,18,29,15,901080413|70093280,0|2049-06-18T00:50:35.901080413|2045-01-07T12:07:55.901080413|=|=',
            '2004,2,11,4,30,56,284753172|-37962,0|2004-02-10T17:58:14.284753172|2004-02-11T15:03:38.284753172|=|=',
            '2071,10,31,10,16,59,1|-32059346792,0|1055-11-30T04:10:27.000000001|3087-10-02T16:23:31.000000001|=|=',
            '2021,12,25,11,56,35,564946539|136557,385429900|2021-12-27T01:52:32.950376439|2021-12-23T22:00:38.179516639|=|=',
            '2067,8,31,6,59,30,648260615|-77630283,-790142241|2065-03-15T19:01:26.858118374|2070-02-14T18:57:34.438402856|=|=',
            '2018,6,30,16,18,38,500|-51125,0|2018-06-30T02:06:33.0000005|2018-07-01T06:30:43.0000005|=|=',
            '-3,12,25,23,53,10,879433375|21817499,0|-000002-09-04T12:18:09.879433375|-000003-04-17T11:28:11.879433375|=|=',
            '2041,9,30,0,0,0,0|-87319377,-803405557|2038-12-24T08:37:02.196594443|2044-07-06T15:22:57.803405557|=|=',
            '-1,11,25,20,13,59,500000|-45265966,-171411414|-000002-06-19T22:21:12.829088586|0001-05-02T18:06:45.171911414|=|=',
            '-1731,5,6,13,0,56,500000000|-72695,0|-001731-05-05T16:49:21.5|-001731-05-07T09:12:31.5|=|=',
            '0,3,16,0,0,0,0|161024,0|0000-03-17T20:43:44|0000-03-14T03:16:16|=|=',
            '1997,10,9,0,0,0,0|-66901102,-851485191|1995-08-26T16:21:37.148514809|1999-11-22T07:38:22.851485191|=|=',
            '1920,7,31,3,15,37,316881135|-90291,-233992191|1920-07-30T02:10:46.082888944|1920-08-01T04:20:28.550873326|=|=',
            '1991,2,27,7,53,47,500|-59873440,-527360410|1989-04-05T08:23:06.47264009|1993-01-20T07:24:27.52736091|=|=',
            '8350,8,31,18,0,42,450118631|26016198022,236480576|9175-02-01T03:41:04.686599207|7526-03-31T08:20:20.213638055|=|=',
            '2064,1,5,23,44,43,193663537|84774,360993128|2064-01-06T23:17:37.554656665|2064-01-05T00:11:48.832670409|=|=',
            '1959,10,31,0,0,0,0|-24562722259,-326798502|1181-06-20T05:35:40.673201498|2738-03-11T18:24:19.326798502|=|=',
            '2041,9,30,5,26,13,396670769|-36218808029,-277766514|0894-01-07T01:25:44.118904255|3189-06-23T09:26:42.674437283|=|=',
            '-7476,2,29,3,38,30,1|12537691331,0|-007079-06-19T07:40:41.000000001|-007874-11-09T23:36:19.000000001|=|='
        };
        Assert.isTrue(rows.size() >= 70, 'expected the full vector set');
        for (String row : rows) {
            List<String> f = row.split('\\|');
            JiffDateTime start = parseCivil(f.get(0));
            JiffSignedDuration duration = parseDuration(f.get(1));
            String added = tryAdd(start, duration);
            String subtracted = trySubtract(start, duration);
            Assert.areEqual(expand(f.get(2)), added, 'sum of ' + row);
            Assert.areEqual(expand(f.get(3)), subtracted, 'difference of ' + row);
            Assert.areEqual(
                saturated(f.get(4), added),
                start.saturatingAdd(duration).toString(),
                'saturating sum of ' + row
            );
            Assert.areEqual(
                saturated(f.get(5), subtracted),
                start.saturatingSubtract(duration).toString(),
                'saturating difference of ' + row
            );
        }
    }

    // ---- subtract --------------------------------------------------------

    @IsTest
    static void subtractsASpan() {
        JiffDateTime dt = civil(1995, 12, 7, 3, 24, 30, 3500);
        Assert.areEqual(
            civil(1975, 8, 7, 3, 24, 30, 3000),
            dt.subtract(new JiffSpan().years(20).months(4).nanoseconds(500))
        );
    }

    @IsTest
    static void subtractsAnAbsoluteDuration() {
        JiffDateTime dt = civil(1995, 12, 7, 3, 24, 30, 3500);
        Assert.areEqual(
            civil(1995, 12, 6, 3, 24, 30, 0),
            dt.subtract(JiffSignedDuration.newInstance(24 * 60 * 60L, 3500))
        );
        Assert.areEqual(
            atHour(2024, 2, 27, 23),
            atHour(2024, 2, 29, 0).subtract(JiffSignedDuration.fromHours(25))
        );
    }

    @IsTest
    static void subtractingTheMostNegativeDurationFailsLikeJiff() {
        // Its negation does not fit in a signed duration.
        String expected =
            'ERR:unsigned duration exceeds Jiff\'s limits: parameter \'signed duration seconds\' ' +
            'is not in the required range of -9223372036854775808..=9223372036854775807';
        JiffDateTime dt = civil(2024, 3, 31, 13, 13, 13, 13);
        Assert.areEqual(expected, trySubtract(dt, JiffSignedDuration.MIN));
        Assert.areEqual(
            expected,
            trySubtract(dt, JiffSignedDuration.newInstance(JiffMath.LONG_MIN, 0))
        );
        Assert.areEqual('ERR:' + DAYS_RANGE, trySubtract(dt, JiffSignedDuration.MAX));
    }

    // ---- saturating arithmetic -------------------------------------------

    @IsTest
    static void saturatingAddStopsAtTheLimits() {
        JiffDateTime dt = civil(2024, 3, 31, 13, 13, 13, 13);
        Assert.areEqual(JiffDateTime.MAX, dt.saturatingAdd(new JiffSpan().years(9000)));
        Assert.areEqual(JiffDateTime.MIN, dt.saturatingAdd(new JiffSpan().years(-19000)));
        Assert.areEqual(JiffDateTime.MAX, dt.saturatingAdd(JiffSignedDuration.MAX));
        Assert.areEqual(JiffDateTime.MIN, dt.saturatingAdd(JiffSignedDuration.MIN));
        // Within range it is plain addition.
        Assert.areEqual(
            civil(2024, 4, 30, 13, 13, 13, 13),
            dt.saturatingAdd(new JiffSpan().months(1))
        );
        Assert.areEqual(
            civil(2024, 3, 31, 14, 13, 13, 13),
            dt.saturatingAdd(JiffSignedDuration.fromHours(1))
        );
    }

    @IsTest
    static void saturatingSubtractStopsAtTheLimits() {
        JiffDateTime dt = civil(2024, 3, 31, 13, 13, 13, 13);
        Assert.areEqual(JiffDateTime.MIN, dt.saturatingSubtract(new JiffSpan().years(19000)));
        Assert.areEqual(JiffDateTime.MAX, dt.saturatingSubtract(new JiffSpan().years(-9000)));
        Assert.areEqual(JiffDateTime.MIN, dt.saturatingSubtract(JiffSignedDuration.MAX));
        Assert.areEqual(JiffDateTime.MAX, dt.saturatingSubtract(JiffSignedDuration.MIN));
        // Within range it is plain subtraction.
        Assert.areEqual(
            civil(2024, 2, 29, 13, 13, 13, 13),
            dt.saturatingSubtract(new JiffSpan().months(1))
        );
        Assert.areEqual(
            civil(2024, 3, 31, 12, 13, 13, 13),
            dt.saturatingSubtract(JiffSignedDuration.fromHours(1))
        );
    }

    // ---- until -----------------------------------------------------------

    @IsTest
    static void untilUsesDaysAsTheLargestUnitByDefault() {
        JiffDateTime earlier = civil(2006, 8, 24, 22, 30, 0, 0);
        JiffDateTime later = atHour(2019, 1, 31, 21);
        Assert.areEqual(new JiffSpan().days(4542).hours(22).minutes(30), earlier.until(later));
        // Flipping the datetimes is fine, but you'll get a negative span.
        Assert.areEqual(new JiffSpan().days(-4542).hours(-22).minutes(-30), later.until(earlier));
        // A missing unit means days too.
        Assert.areEqual(earlier.until(later), earlier.until(later, (JiffUnit) null));
    }

    @IsTest
    static void untilCanUseBiggerUnits() {
        JiffDateTime dt1 = civil(1995, 12, 7, 3, 24, 30, 3500);
        JiffDateTime dt2 = civil(2019, 1, 31, 15, 30, 0, 0);
        Assert.areEqual('P8456DT12H5M29.9999965S', dt1.until(dt2).toString());
        Assert.areEqual('P23Y1M24DT12H5M29.9999965S', dt1.until(dt2, JiffUnit.YEAR).toString());
        Assert.areEqual('PT202956H5M29.9999965S', dt1.until(dt2, JiffUnit.HOUR).toString());
    }

    @IsTest
    static void unitsBiggerThanDaysAreNotAlwaysReversible() {
        JiffDateTime dt1 = atHour(2024, 3, 2, 0);
        JiffDateTime dt2 = atHour(2024, 5, 1, 0);
        JiffSpan span = dt1.until(dt2, JiffUnit.MONTH);
        Assert.areEqual(new JiffSpan().months(1).days(29), span);
        // Not the same as the original datetime!
        Assert.areEqual(atHour(2024, 3, 3, 0), dt2.subtract(span));
        // But in the default configuration, days are always the biggest unit and
        // reversibility is guaranteed.
        span = dt1.until(dt2);
        Assert.areEqual(new JiffSpan().days(60), span);
        Assert.areEqual(dt1, dt2.subtract(span));
    }

    @IsTest
    static void untilMatchesJiffsOwnTests() {
        JiffDateTime a = atHour(9999, 12, 30, 3);
        JiffDateTime b = atHour(9999, 12, 31, 2);
        Assert.areEqual(new JiffSpan().hours(23), a.until(b));

        a = atHour(-9999, 1, 2, 2);
        b = atHour(-9999, 1, 1, 3);
        Assert.areEqual(new JiffSpan().hours(-23), a.until(b));

        a = civil(1995, 12, 7, 3, 24, 30, 3500);
        b = civil(2019, 1, 31, 15, 30, 0, 0);
        JiffSpan clock = new JiffSpan()
            .hours(12)
            .minutes(5)
            .seconds(29)
            .milliseconds(999)
            .microseconds(996)
            .nanoseconds(500);
        Assert.areEqual(clock.days(8456), a.until(b));
        Assert.areEqual(clock.years(23).months(1).days(24), a.until(b, JiffUnit.YEAR));
        Assert.areEqual(clock.years(23).months(1).days(24).negate(), b.until(a, JiffUnit.YEAR));
        Assert.areEqual(
            new JiffSpan().nanoseconds(730641929999996500L),
            a.until(b, JiffUnit.NANOSECOND)
        );

        a = JiffDateTime.MIN;
        b = JiffDateTime.MAX;
        Assert.areEqual('ERR:' + ERROR_TEXT.get('nanos'), tryUntil(a, b, JiffUnit.NANOSECOND));
        Assert.areEqual(
            new JiffSpan().microseconds(631107417600000000L - 1).nanoseconds(999),
            a.until(b, JiffUnit.MICROSECOND)
        );
    }

    @IsTest
    static void untilCountsMonthsOfDifferentLengths() {
        JiffDateTime jan1 = atHour(2020, 1, 1, 0);
        JiffDateTime feb1 = atHour(2020, 2, 1, 0);
        JiffDateTime mar1 = atHour(2020, 3, 1, 0);
        Assert.areEqual(new JiffSpan().days(31), jan1.until(feb1));
        Assert.areEqual(new JiffSpan().months(1), jan1.until(feb1, JiffUnit.MONTH));
        Assert.areEqual(new JiffSpan().days(29), feb1.until(mar1));
        Assert.areEqual(new JiffSpan().months(1), feb1.until(mar1, JiffUnit.MONTH));
        Assert.areEqual(new JiffSpan().days(60), jan1.until(mar1));
        Assert.areEqual(new JiffSpan().months(2), jan1.until(mar1, JiffUnit.MONTH));
    }

    @IsTest
    static void untilFailsWhenTheDifferenceDoesNotFitTheUnit() {
        Assert.areEqual(
            'ERR:' + ERROR_TEXT.get('months'),
            tryUntil(JiffDateTime.MIN, JiffDateTime.MAX, JiffUnit.MONTH)
        );
        Assert.areEqual(
            'ERR:' + ERROR_TEXT.get('nanos'),
            tryUntil(JiffDateTime.MAX, JiffDateTime.MIN, JiffUnit.NANOSECOND)
        );
        // Every other unit can hold the distance between the limits.
        Assert.areEqual(
            'P19998Y11M30DT23H59M59.999999999S',
            JiffDateTime.MIN.until(JiffDateTime.MAX, JiffUnit.YEAR).toString()
        );
        Assert.areEqual(
            'P1043497W4DT23H59M59.999999999S',
            JiffDateTime.MIN.until(JiffDateTime.MAX, JiffUnit.WEEK).toString()
        );
        Assert.areEqual(
            'P7304483DT23H59M59.999999999S',
            JiffDateTime.MIN.until(JiffDateTime.MAX).toString()
        );
    }

    @IsTest
    static void untilInNanosecondsReachesExactlyTheLargestSpan() {
        // A span holds at most 9,223,372,036,854,775,807 nanoseconds, which is how far
        // `fits` is from `start`. `tooFar` is one nanosecond later.
        JiffDateTime start = atHour(2000, 1, 1, 0);
        JiffDateTime fits = civil(2292, 4, 10, 23, 47, 16, 854775807);
        JiffDateTime tooFar = civil(2292, 4, 10, 23, 47, 16, 854775808);
        Assert.areEqual(
            new JiffSpan().nanoseconds(9223372036854775807L),
            start.until(fits, JiffUnit.NANOSECOND)
        );
        Assert.areEqual(
            new JiffSpan().nanoseconds(-9223372036854775807L),
            fits.until(start, JiffUnit.NANOSECOND)
        );
        Assert.areEqual(
            new JiffSpan().nanoseconds(-9223372036854775807L),
            start.since(fits, JiffUnit.NANOSECOND)
        );
        Assert.areEqual(
            new JiffSpan().nanoseconds(9223372036854775807L),
            fits.since(start, JiffUnit.NANOSECOND)
        );
        String outOfRange = 'ERR:' + ERROR_TEXT.get('nanos');
        Assert.areEqual(outOfRange, tryUntil(start, tooFar, JiffUnit.NANOSECOND));
        Assert.areEqual(outOfRange, tryUntil(tooFar, start, JiffUnit.NANOSECOND));
        // Further out too: a sum that wrapped around a Long would land on a legal negative
        // count here, where one past the limit wraps to the one value that is still rejected.
        List<JiffDateTime> furtherOut = new List<JiffDateTime>{
            civil(2292, 4, 10, 23, 47, 16, 854775809),
            civil(2292, 4, 10, 23, 47, 16, 999999999),
            civil(2292, 4, 10, 23, 47, 17, 0)
        };
        for (JiffDateTime far : furtherOut) {
            Assert.areEqual(outOfRange, tryUntil(start, far, JiffUnit.NANOSECOND), 'until ' + far);
            Assert.areEqual(outOfRange, tryUntil(far, start, JiffUnit.NANOSECOND), 'from ' + far);
        }
        try {
            JiffSpan unexpected = start.since(tooFar, JiffUnit.NANOSECOND);
            Assert.fail('expected the difference not to fit, but got ' + unexpected);
        } catch (JiffException e) {
            Assert.areEqual(ERROR_TEXT.get('nanos'), e.getMessage());
        }
        // One unit up there is room to spare.
        Assert.areEqual(
            new JiffSpan().microseconds(9223372036854775L).nanoseconds(808),
            start.until(tooFar, JiffUnit.MICROSECOND)
        );
        Assert.areEqual(
            new JiffSpan().microseconds(-9223372036854775L).nanoseconds(-808),
            tooFar.until(start, JiffUnit.MICROSECOND)
        );
    }

    @IsTest
    static void untilAndDurationUntilMatchJiff() {
        // Produced by Jiff 1.0.0, and replayed against it by `npm run oracle:check`. Each row is
        //   dt1 | dt2 | dt1.duration_until(dt2) | largest unit | dt1.until((unit, dt2))
        // with the duration as `seconds,nanoseconds`, the unit as its position from
        // nanoseconds (0) to years (9), and the span as its ten units from years down to
        // nanoseconds, or the abbreviated error.
        List<String> rows = new List<String>{
            '1995,12,7,3,24,30,3500|2019,1,31,15,30,0,0|730641929,999996500|0|0,0,0,0,0,0,0,0,0,730641929999996500',
            '1995,12,7,3,24,30,3500|2019,1,31,15,30,0,0|730641929,999996500|1|0,0,0,0,0,0,0,0,730641929999996,500',
            '1995,12,7,3,24,30,3500|2019,1,31,15,30,0,0|730641929,999996500|2|0,0,0,0,0,0,0,730641929999,996,500',
            '1995,12,7,3,24,30,3500|2019,1,31,15,30,0,0|730641929,999996500|3|0,0,0,0,0,0,730641929,999,996,500',
            '1995,12,7,3,24,30,3500|2019,1,31,15,30,0,0|730641929,999996500|4|0,0,0,0,0,12177365,29,999,996,500',
            '1995,12,7,3,24,30,3500|2019,1,31,15,30,0,0|730641929,999996500|5|0,0,0,0,202956,5,29,999,996,500',
            '1995,12,7,3,24,30,3500|2019,1,31,15,30,0,0|730641929,999996500|6|0,0,0,8456,12,5,29,999,996,500',
            '1995,12,7,3,24,30,3500|2019,1,31,15,30,0,0|730641929,999996500|7|0,0,1208,0,12,5,29,999,996,500',
            '1995,12,7,3,24,30,3500|2019,1,31,15,30,0,0|730641929,999996500|8|0,277,0,24,12,5,29,999,996,500',
            '1995,12,7,3,24,30,3500|2019,1,31,15,30,0,0|730641929,999996500|9|23,1,0,24,12,5,29,999,996,500',
            '2019,1,31,15,30,0,0|1995,12,7,3,24,30,3500|-730641929,-999996500|0|0,0,0,0,0,0,0,0,0,-730641929999996500',
            '2019,1,31,15,30,0,0|1995,12,7,3,24,30,3500|-730641929,-999996500|1|0,0,0,0,0,0,0,0,-730641929999996,-500',
            '2019,1,31,15,30,0,0|1995,12,7,3,24,30,3500|-730641929,-999996500|2|0,0,0,0,0,0,0,-730641929999,-996,-500',
            '2019,1,31,15,30,0,0|1995,12,7,3,24,30,3500|-730641929,-999996500|3|0,0,0,0,0,0,-730641929,-999,-996,-500',
            '2019,1,31,15,30,0,0|1995,12,7,3,24,30,3500|-730641929,-999996500|4|0,0,0,0,0,-12177365,-29,-999,-996,-500',
            '2019,1,31,15,30,0,0|1995,12,7,3,24,30,3500|-730641929,-999996500|5|0,0,0,0,-202956,-5,-29,-999,-996,-500',
            '2019,1,31,15,30,0,0|1995,12,7,3,24,30,3500|-730641929,-999996500|6|0,0,0,-8456,-12,-5,-29,-999,-996,-500',
            '2019,1,31,15,30,0,0|1995,12,7,3,24,30,3500|-730641929,-999996500|7|0,0,-1208,0,-12,-5,-29,-999,-996,-500',
            '2019,1,31,15,30,0,0|1995,12,7,3,24,30,3500|-730641929,-999996500|8|0,-277,0,-24,-12,-5,-29,-999,-996,-500',
            '2019,1,31,15,30,0,0|1995,12,7,3,24,30,3500|-730641929,-999996500|9|-23,-1,0,-24,-12,-5,-29,-999,-996,-500',
            '-9999,1,1,0,0,0,0|9999,12,31,23,59,59,999999999|631107417599,999999999|0|ERR:nanos',
            '-9999,1,1,0,0,0,0|9999,12,31,23,59,59,999999999|631107417599,999999999|1|0,0,0,0,0,0,0,0,631107417599999999,999',
            '-9999,1,1,0,0,0,0|9999,12,31,23,59,59,999999999|631107417599,999999999|2|0,0,0,0,0,0,0,631107417599999,999,999',
            '-9999,1,1,0,0,0,0|9999,12,31,23,59,59,999999999|631107417599,999999999|3|0,0,0,0,0,0,631107417599,999,999,999',
            '-9999,1,1,0,0,0,0|9999,12,31,23,59,59,999999999|631107417599,999999999|4|0,0,0,0,0,10518456959,59,999,999,999',
            '-9999,1,1,0,0,0,0|9999,12,31,23,59,59,999999999|631107417599,999999999|5|0,0,0,0,175307615,59,59,999,999,999',
            '-9999,1,1,0,0,0,0|9999,12,31,23,59,59,999999999|631107417599,999999999|6|0,0,0,7304483,23,59,59,999,999,999',
            '-9999,1,1,0,0,0,0|9999,12,31,23,59,59,999999999|631107417599,999999999|7|0,0,1043497,4,23,59,59,999,999,999',
            '-9999,1,1,0,0,0,0|9999,12,31,23,59,59,999999999|631107417599,999999999|8|ERR:months',
            '-9999,1,1,0,0,0,0|9999,12,31,23,59,59,999999999|631107417599,999999999|9|19998,11,0,30,23,59,59,999,999,999',
            '9999,12,31,23,59,59,999999999|-9999,1,1,0,0,0,0|-631107417599,-999999999|0|ERR:nanos',
            '9999,12,31,23,59,59,999999999|-9999,1,1,0,0,0,0|-631107417599,-999999999|1|0,0,0,0,0,0,0,0,-631107417599999999,-999',
            '9999,12,31,23,59,59,999999999|-9999,1,1,0,0,0,0|-631107417599,-999999999|6|0,0,0,-7304483,-23,-59,-59,-999,-999,-999',
            '9999,12,31,23,59,59,999999999|-9999,1,1,0,0,0,0|-631107417599,-999999999|7|0,0,-1043497,-4,-23,-59,-59,-999,-999,-999',
            '9999,12,31,23,59,59,999999999|-9999,1,1,0,0,0,0|-631107417599,-999999999|8|ERR:months',
            '9999,12,31,23,59,59,999999999|-9999,1,1,0,0,0,0|-631107417599,-999999999|9|-19998,-11,0,-30,-23,-59,-59,-999,-999,-999',
            '2024,5,8,3,0,0,0|2024,5,9,2,0,0,0|82800,0|6|0,0,0,0,23,0,0,0,0,0',
            '2024,5,8,3,0,0,0|2024,5,9,2,0,0,0|82800,0|7|0,0,0,0,23,0,0,0,0,0',
            '2024,5,8,3,0,0,0|2024,5,9,2,0,0,0|82800,0|8|0,0,0,0,23,0,0,0,0,0',
            '2024,5,8,3,0,0,0|2024,5,9,2,0,0,0|82800,0|9|0,0,0,0,23,0,0,0,0,0',
            '2024,5,9,2,0,0,0|2024,5,8,3,0,0,0|-82800,0|6|0,0,0,0,-23,0,0,0,0,0',
            '2024,5,9,2,0,0,0|2024,5,8,3,0,0,0|-82800,0|7|0,0,0,0,-23,0,0,0,0,0',
            '2024,5,9,2,0,0,0|2024,5,8,3,0,0,0|-82800,0|8|0,0,0,0,-23,0,0,0,0,0',
            '2024,5,9,2,0,0,0|2024,5,8,3,0,0,0|-82800,0|9|0,0,0,0,-23,0,0,0,0,0',
            '2024,5,8,2,0,0,0|2024,5,9,3,0,0,0|90000,0|6|0,0,0,1,1,0,0,0,0,0',
            '2024,5,8,2,0,0,0|2024,5,9,3,0,0,0|90000,0|7|0,0,0,1,1,0,0,0,0,0',
            '2024,5,8,2,0,0,0|2024,5,9,3,0,0,0|90000,0|8|0,0,0,1,1,0,0,0,0,0',
            '2024,5,8,2,0,0,0|2024,5,9,3,0,0,0|90000,0|9|0,0,0,1,1,0,0,0,0,0',
            '2024,5,9,3,0,0,0|2024,5,8,2,0,0,0|-90000,0|6|0,0,0,-1,-1,0,0,0,0,0',
            '2024,5,9,3,0,0,0|2024,5,8,2,0,0,0|-90000,0|7|0,0,0,-1,-1,0,0,0,0,0',
            '2024,5,9,3,0,0,0|2024,5,8,2,0,0,0|-90000,0|8|0,0,0,-1,-1,0,0,0,0,0',
            '2024,5,9,3,0,0,0|2024,5,8,2,0,0,0|-90000,0|9|0,0,0,-1,-1,0,0,0,0,0',
            '2024,5,8,2,0,0,0|2024,5,8,3,0,0,0|3600,0|6|0,0,0,0,1,0,0,0,0,0',
            '2024,5,8,2,0,0,0|2024,5,8,3,0,0,0|3600,0|7|0,0,0,0,1,0,0,0,0,0',
            '2024,5,8,2,0,0,0|2024,5,8,3,0,0,0|3600,0|8|0,0,0,0,1,0,0,0,0,0',
            '2024,5,8,2,0,0,0|2024,5,8,3,0,0,0|3600,0|9|0,0,0,0,1,0,0,0,0,0',
            '2024,5,8,3,0,0,0|2024,5,8,2,0,0,0|-3600,0|6|0,0,0,0,-1,0,0,0,0,0',
            '2024,5,8,3,0,0,0|2024,5,8,2,0,0,0|-3600,0|7|0,0,0,0,-1,0,0,0,0,0',
            '2024,5,8,3,0,0,0|2024,5,8,2,0,0,0|-3600,0|8|0,0,0,0,-1,0,0,0,0,0',
            '2024,5,8,3,0,0,0|2024,5,8,2,0,0,0|-3600,0|9|0,0,0,0,-1,0,0,0,0,0',
            '2024,5,8,3,0,0,0|2024,5,8,3,0,0,0|0,0|6|0,0,0,0,0,0,0,0,0,0',
            '2024,5,8,3,0,0,0|2024,5,8,3,0,0,0|0,0|7|0,0,0,0,0,0,0,0,0,0',
            '2024,5,8,3,0,0,0|2024,5,8,3,0,0,0|0,0|8|0,0,0,0,0,0,0,0,0,0',
            '2024,5,8,3,0,0,0|2024,5,8,3,0,0,0|0,0|9|0,0,0,0,0,0,0,0,0,0',
            '2024,1,31,12,0,0,0|2024,3,1,11,0,0,0|2588400,0|6|0,0,0,29,23,0,0,0,0,0',
            '2024,1,31,12,0,0,0|2024,3,1,11,0,0,0|2588400,0|7|0,0,4,1,23,0,0,0,0,0',
            '2024,1,31,12,0,0,0|2024,3,1,11,0,0,0|2588400,0|8|0,0,0,29,23,0,0,0,0,0',
            '2024,1,31,12,0,0,0|2024,3,1,11,0,0,0|2588400,0|9|0,0,0,29,23,0,0,0,0,0',
            '2024,1,31,12,0,0,0|2024,2,29,11,0,0,0|2502000,0|6|0,0,0,28,23,0,0,0,0,0',
            '2024,1,31,12,0,0,0|2024,2,29,11,0,0,0|2502000,0|7|0,0,4,0,23,0,0,0,0,0',
            '2024,1,31,12,0,0,0|2024,2,29,11,0,0,0|2502000,0|8|0,0,0,28,23,0,0,0,0,0',
            '2024,1,31,12,0,0,0|2024,2,29,11,0,0,0|2502000,0|9|0,0,0,28,23,0,0,0,0,0',
            '2024,1,31,12,0,0,0|2024,2,29,13,0,0,0|2509200,0|6|0,0,0,29,1,0,0,0,0,0',
            '2024,1,31,12,0,0,0|2024,2,29,13,0,0,0|2509200,0|7|0,0,4,1,1,0,0,0,0,0',
            '2024,1,31,12,0,0,0|2024,2,29,13,0,0,0|2509200,0|8|0,0,0,29,1,0,0,0,0,0',
            '2024,1,31,12,0,0,0|2024,2,29,13,0,0,0|2509200,0|9|0,0,0,29,1,0,0,0,0,0',
            '2024,3,31,12,0,0,0|2024,2,29,13,0,0,0|-2674800,0|6|0,0,0,-30,-23,0,0,0,0,0',
            '2024,3,31,12,0,0,0|2024,2,29,13,0,0,0|-2674800,0|7|0,0,-4,-2,-23,0,0,0,0,0',
            '2024,3,31,12,0,0,0|2024,2,29,13,0,0,0|-2674800,0|8|0,0,0,-30,-23,0,0,0,0,0',
            '2024,3,31,12,0,0,0|2024,2,29,13,0,0,0|-2674800,0|9|0,0,0,-30,-23,0,0,0,0,0',
            '2024,3,31,12,0,0,0|2024,3,1,13,0,0,0|-2588400,0|6|0,0,0,-29,-23,0,0,0,0,0',
            '2024,3,31,12,0,0,0|2024,3,1,13,0,0,0|-2588400,0|7|0,0,-4,-1,-23,0,0,0,0,0',
            '2024,3,31,12,0,0,0|2024,3,1,13,0,0,0|-2588400,0|8|0,0,0,-29,-23,0,0,0,0,0',
            '2024,3,31,12,0,0,0|2024,3,1,13,0,0,0|-2588400,0|9|0,0,0,-29,-23,0,0,0,0,0',
            '2024,3,2,0,0,0,0|2024,5,1,0,0,0,0|5184000,0|6|0,0,0,60,0,0,0,0,0,0',
            '2024,3,2,0,0,0,0|2024,5,1,0,0,0,0|5184000,0|7|0,0,8,4,0,0,0,0,0,0',
            '2024,3,2,0,0,0,0|2024,5,1,0,0,0,0|5184000,0|8|0,1,0,29,0,0,0,0,0,0',
            '2024,3,2,0,0,0,0|2024,5,1,0,0,0,0|5184000,0|9|0,1,0,29,0,0,0,0,0,0',
            '2020,1,1,0,0,0,0|2020,3,1,0,0,0,0|5184000,0|6|0,0,0,60,0,0,0,0,0,0',
            '2020,1,1,0,0,0,0|2020,3,1,0,0,0,0|5184000,0|7|0,0,8,4,0,0,0,0,0,0',
            '2020,1,1,0,0,0,0|2020,3,1,0,0,0,0|5184000,0|8|0,2,0,0,0,0,0,0,0,0',
            '2020,1,1,0,0,0,0|2020,3,1,0,0,0,0|5184000,0|9|0,2,0,0,0,0,0,0,0,0',
            '2023,2,28,23,59,59,999999999|2024,2,29,0,0,0,0|31536000,1|6|0,0,0,365,0,0,0,0,0,1',
            '2023,2,28,23,59,59,999999999|2024,2,29,0,0,0,0|31536000,1|7|0,0,52,1,0,0,0,0,0,1',
            '2023,2,28,23,59,59,999999999|2024,2,29,0,0,0,0|31536000,1|8|0,12,0,0,0,0,0,0,0,1',
            '2023,2,28,23,59,59,999999999|2024,2,29,0,0,0,0|31536000,1|9|1,0,0,0,0,0,0,0,0,1',
            '2024,2,29,0,0,0,0|2023,2,28,23,59,59,999999999|-31536000,-1|6|0,0,0,-365,0,0,0,0,0,-1',
            '2024,2,29,0,0,0,0|2023,2,28,23,59,59,999999999|-31536000,-1|7|0,0,-52,-1,0,0,0,0,0,-1',
            '2024,2,29,0,0,0,0|2023,2,28,23,59,59,999999999|-31536000,-1|8|0,-11,0,-28,0,0,0,0,0,-1',
            '2024,2,29,0,0,0,0|2023,2,28,23,59,59,999999999|-31536000,-1|9|0,-11,0,-28,0,0,0,0,0,-1',
            '2024,1,1,0,0,0,0|2025,4,1,0,0,0,0|39398400,0|6|0,0,0,456,0,0,0,0,0,0',
            '2024,1,1,0,0,0,0|2025,4,1,0,0,0,0|39398400,0|7|0,0,65,1,0,0,0,0,0,0',
            '2024,1,1,0,0,0,0|2025,4,1,0,0,0,0|39398400,0|8|0,15,0,0,0,0,0,0,0,0',
            '2024,1,1,0,0,0,0|2025,4,1,0,0,0,0|39398400,0|9|1,3,0,0,0,0,0,0,0,0',
            '9999,12,30,3,0,0,0|9999,12,31,2,0,0,0|82800,0|6|0,0,0,0,23,0,0,0,0,0',
            '9999,12,30,3,0,0,0|9999,12,31,2,0,0,0|82800,0|7|0,0,0,0,23,0,0,0,0,0',
            '9999,12,30,3,0,0,0|9999,12,31,2,0,0,0|82800,0|8|0,0,0,0,23,0,0,0,0,0',
            '9999,12,30,3,0,0,0|9999,12,31,2,0,0,0|82800,0|9|0,0,0,0,23,0,0,0,0,0',
            '-9999,1,2,2,0,0,0|-9999,1,1,3,0,0,0|-82800,0|6|0,0,0,0,-23,0,0,0,0,0',
            '-9999,1,2,2,0,0,0|-9999,1,1,3,0,0,0|-82800,0|7|0,0,0,0,-23,0,0,0,0,0',
            '-9999,1,2,2,0,0,0|-9999,1,1,3,0,0,0|-82800,0|8|0,0,0,0,-23,0,0,0,0,0',
            '-9999,1,2,2,0,0,0|-9999,1,1,3,0,0,0|-82800,0|9|0,0,0,0,-23,0,0,0,0,0',
            '2006,8,24,22,30,0,0|2019,1,31,21,0,0,0|392509800,0|6|0,0,0,4542,22,30,0,0,0,0',
            '2006,8,24,22,30,0,0|2019,1,31,21,0,0,0|392509800,0|7|0,0,648,6,22,30,0,0,0,0',
            '2006,8,24,22,30,0,0|2019,1,31,21,0,0,0|392509800,0|8|0,149,0,6,22,30,0,0,0,0',
            '2006,8,24,22,30,0,0|2019,1,31,21,0,0,0|392509800,0|9|12,5,0,6,22,30,0,0,0,0',
            '1732,2,22,0,0,0,0|2024,6,19,0,0,0,0|9224841600,0|0|ERR:nanos',
            '1732,2,22,0,0,0,0|2024,6,20,0,0,0,0|9224928000,0|0|ERR:nanos',
            '1732,2,22,0,0,0,0|2024,6,20,0,0,0,0|9224928000,0|1|0,0,0,0,0,0,0,0,9224928000000000,0',
            '2000,1,1,0,0,0,0|2292,4,10,23,47,16,854775807|9223372036,854775807|0|0,0,0,0,0,0,0,0,0,9223372036854775807',
            '2292,4,10,23,47,16,854775807|2000,1,1,0,0,0,0|-9223372036,-854775807|0|0,0,0,0,0,0,0,0,0,-9223372036854775807',
            '2000,1,1,0,0,0,0|2292,4,10,23,47,16,854775808|9223372036,854775808|0|ERR:nanos',
            '2292,4,10,23,47,16,854775808|2000,1,1,0,0,0,0|-9223372036,-854775808|0|ERR:nanos',
            '2000,1,1,0,0,0,0|2292,4,10,23,47,16,854775808|9223372036,854775808|1|0,0,0,0,0,0,0,0,9223372036854775,808',
            '2292,4,10,23,47,16,854775808|2000,1,1,0,0,0,0|-9223372036,-854775808|1|0,0,0,0,0,0,0,0,-9223372036854775,-808',
            '2038,9,22,0,0,0,0|143,8,26,16,30,49,500000000|-59802737350,-500000000|0|ERR:nanos',
            '2067,8,31,23,59,59,999999999|2067,6,29,17,5,54,122505639|-5468045,-877494360|1|0,0,0,0,0,0,0,0,-5468045877494,-360',
            '2073,10,12,0,0,0,0|2044,12,11,12,38,30,500000000|-909919289,-500000000|2|0,0,0,0,0,0,0,-909919289500,0,0',
            '1969,3,13,5,0,59,0|1969,3,18,18,55,45,17790790|482086,17790790|3|0,0,0,0,0,0,482086,17,790,790',
            '2080,12,8,14,42,49,999999999|2080,11,15,13,26,10,563872620|-1991799,-436127379|4|0,0,0,0,0,-33196,-39,-436,-127,-379',
            '2076,3,1,23,59,59,999999999|2076,1,14,13,20,35,738068780|-4099164,-261931219|5|0,0,0,0,-1138,-39,-24,-261,-931,-219',
            '2078,2,3,18,34,36,946403557|2078,1,24,10,6,4,876711717|-894512,-69691840|6|0,0,0,-10,-8,-28,-32,-69,-691,-840',
            '2036,4,30,3,31,48,165429214|2000,8,17,0,0,0,0|-1126668708,-165429214|7|0,0,-1862,-6,-3,-31,-48,-165,-429,-214',
            '2070,2,1,0,0,0,0|2070,3,7,20,22,30,383971834|3010950,383971834|8|0,1,0,6,20,22,30,383,971,834',
            '-2521,7,30,0,0,0,0|2040,12,4,8,33,41,221260522|143942344421,221260522|9|4561,4,0,4,8,33,41,221,260,522',
            '1962,10,12,21,30,59,1|2055,2,27,1,30,59,808487373|2915150400,808487372|0|0,0,0,0,0,0,0,0,0,2915150400808487372',
            '1975,3,31,1,0,3,500000|3,9,7,0,0,0,0|-62216470803,-500000|1|0,0,0,0,0,0,0,0,-62216470803000500,0',
            '1,4,30,0,0,0,0|1928,9,9,18,31,0,881126457|60821692260,881126457|2|0,0,0,0,0,0,0,60821692260881,126,457',
            '-5829,10,22,7,0,0,394922334|1960,8,8,0,0,0,0|245790608399,605077666|3|0,0,0,0,0,0,245790608399,605,77,666',
            '2054,4,17,0,0,0,0|1939,11,14,1,0,57,425729705|-3610911542,-574270295|4|0,0,0,0,0,-60181859,-2,-574,-270,-295',
            '1925,7,6,3,50,43,500|1913,4,30,23,59,59,999999999|-384407443,-501|5|0,0,0,0,-106779,-50,-43,0,0,-501',
            '1,3,31,12,0,54,0|2074,12,31,23,59,59,999999999|65441390345,999999999|6|0,0,0,757423,11,59,5,999,999,999',
            '2018,9,30,17,51,44,999999999|2611,9,10,2,35,47,1|18711420242,2|7|0,0,30938,1,8,44,2,0,0,2',
            '2084,1,31,5,0,26,235148030|2084,1,9,7,35,22,324270287|-1891503,-910877743|8|0,0,0,-21,-21,-25,-3,-910,-877,-743',
            '1932,2,29,5,11,59,184748586|1931,12,20,23,22,13,812198241|-6068985,-372550345|9|0,-2,0,-8,-5,-49,-45,-372,-550,-345',
            '1944,1,31,23,59,59,999999999|-3,6,8,0,0,0,0|-61430313599,-999999999|0|ERR:nanos',
            '2095,9,8,0,0,0,0|2044,8,24,9,36,52,842234326|-1610634187,-157765674|1|0,0,0,0,0,0,0,0,-1610634187157765,-674',
            '1900,12,31,1,59,30,698684125|1900,10,27,2,38,53,42233080|-5613637,-656451045|2|0,0,0,0,0,0,0,-5613637656,-451,-45',
            '1977,10,7,15,6,35,378364298|1977,12,13,5,27,40,255981327|5754064,877617029|3|0,0,0,0,0,0,5754064,877,617,29',
            '2033,9,27,4,30,54,587533228|2033,8,21,18,35,25,864010359|-3146128,-723522869|4|0,0,0,0,0,-52435,-28,-723,-522,-869',
            '608,6,8,22,0,16,500000000|1969,9,30,23,59,59,999999999|42958864783,499999999|5|0,0,0,0,11933017,59,43,499,999,999',
            '1969,7,19,1,59,50,594732376|1969,6,10,12,21,18,75191112|-3332312,-519541264|6|0,0,0,-38,-13,-38,-32,-519,-541,-264',
            '1971,3,16,10,59,3,813067872|2040,9,24,17,10,30,984732889|2194150287,171665017|7|0,0,3627,6,6,11,27,171,665,17',
            '2075,3,31,0,59,28,807767068|1943,6,30,0,0,0,0|-4157744368,-807767068|8|0,-1581,0,0,0,-59,-28,-807,-767,-68',
            '1933,12,14,21,56,0,45891676|1933,10,9,19,3,48,249373659|-5712731,-796518017|9|0,-2,0,-5,-2,-52,-11,-796,-518,-17',
            '2020,1,21,7,0,30,500|2020,1,19,23,39,37,100408992|-112852,-899591508|0|0,0,0,0,0,0,0,0,0,-112852899591508',
            '2023,3,21,13,48,58,310901074|1942,1,31,9,3,59,999999999|-2560394698,-310901075|1|0,0,0,0,0,0,0,0,-2560394698310901,-75',
            '2039,7,22,22,8,12,525505563|2041,7,31,19,30,59,123456789|63926566,597951226|2|0,0,0,0,0,0,0,63926566597,951,226',
            '2064,10,31,13,30,20,587145314|-1960,9,13,0,0,0,0|-126989386220,-587145314|3|0,0,0,0,0,0,-126989386220,-587,-145,-314',
            '2000,1,31,4,59,58,628960739|2049,2,26,10,5,59,123456789|1548651960,494496050|4|0,0,0,0,0,25810866,0,494,496,50',
            '2062,1,4,9,59,55,999999999|1940,11,12,11,22,25,207960087|-3823022250,-792039912|5|0,0,0,0,-1061950,-37,-30,-792,-39,-912',
            '1935,12,31,0,0,0,0|2076,8,2,5,30,0,500000|4436659800,500000|6|0,0,0,51350,5,30,0,0,500,0',
            '1,6,25,13,0,0,1|1922,8,2,23,59,59,999999999|60624154799,999999998|7|0,0,100238,2,10,59,59,999,999,998',
            '2094,10,26,13,50,0,500000000|2056,5,2,6,33,18,590174601|-1214464601,-909825399|8|0,-461,0,-24,-7,-16,-41,-909,-825,-399',
            '2064,2,21,23,59,59,999999999|2064,1,8,10,42,11,693178011|-3849468,-306821988|9|0,-1,0,-13,-13,-17,-48,-306,-821,-988',
            '2014,1,31,4,30,56,400311574|2013,11,30,0,38,50,976156424|-5370725,-424155150|0|0,0,0,0,0,0,0,0,0,-5370725424155150',
            '1940,8,20,1,54,0,952395903|5745,4,20,19,59,27,993479180|120063751527,41083277|1|0,0,0,0,0,0,0,0,120063751527041083,277',
            '1903,9,2,1,43,59,274246278|1903,8,15,14,2,26,658983746|-1510892,-615262532|2|0,0,0,0,0,0,0,-1510892615,-262,-532',
            '-8208,11,13,14,41,13,396598366|1969,12,18,7,31,29,0|321158019015,603401634|3|0,0,0,0,0,0,321158019015,603,401,634',
            '1,5,31,7,59,41,844795295|1,5,11,23,49,13,417869294|-1671028,-426926001|4|0,0,0,0,0,-27850,-28,-426,-926,-1',
            '2081,9,30,12,30,42,500|2081,9,5,10,35,4,220174508|-2166937,-779825992|5|0,0,0,0,-601,-55,-37,-779,-825,-992',
            '2042,2,28,14,5,15,0|2042,4,14,10,43,45,650205795|3875910,650205795|6|0,0,0,44,20,38,30,650,205,795',
            '2013,2,28,0,0,0,0|1926,11,27,6,55,18,667069536|-2722007081,-332930464|7|0,0,-4500,-4,-17,-4,-41,-332,-930,-464',
            '1998,11,30,19,0,45,500000|298,8,31,1,0,19,613807435|-53654724025,-386692565|8|0,-20402,0,-30,-18,0,-25,-386,-692,-565',
            '2039,2,10,0,0,0,0|-6217,10,5,8,50,1,123456789|-260513680198,-876543211|9|-8255,-4,0,-4,-15,-9,-58,-876,-543,-211',
            '-2,2,28,8,40,30,999999999|-3,12,28,18,28,39,463052977|-5321511,-536947022|0|0,0,0,0,0,0,0,0,0,-5321511536947022',
            '2003,6,30,14,23,59,535519431|2003,8,15,15,4,8,672367211|3976809,136847780|1|0,0,0,0,0,0,0,0,3976809136847,780',
            '1999,5,1,23,30,2,892755913|9620,3,10,13,52,51,467011347|240491082168,574255434|2|0,0,0,0,0,0,0,240491082168574,255,434',
            '0,6,20,12,0,59,653858979|1900,8,6,18,22,38,619486684|59962227698,965627705|3|0,0,0,0,0,0,59962227698,965,627,705',
            '2040,12,31,22,20,1,123456789|1930,8,22,0,0,0,0|-3482778001,-123456789|4|0,0,0,0,0,-58046300,-1,-123,-456,-789',
            '-8956,8,31,15,39,59,537925457|3,5,31,23,59,59,999999999|282710766000,462074542|5|0,0,0,0,78530768,20,0,462,74,542',
            '2001,5,21,0,0,0,0|1909,7,31,10,0,0,500000000|-2897128799,-500000000|6|0,0,0,-33531,-13,-59,-59,-500,0,0',
            '2062,1,5,9,25,22,81068585|2061,11,30,22,55,47,544349079|-3061774,-536719506|7|0,0,-5,0,-10,-29,-34,-536,-719,-506',
            '2062,2,4,12,3,2,403197915|1906,6,7,11,23,59,500|-4912360743,-403197415|8|0,-1867,0,-27,0,-39,-3,-403,-197,-415',
            '1709,6,29,6,14,55,500|1988,3,31,20,30,55,123456789|8796694560,123456289|9|278,9,0,2,14,16,0,123,456,289',
            '2065,6,30,20,57,39,353377977|1951,4,3,8,35,0,576302443|-3605257358,-777075534|0|0,0,0,0,0,0,0,0,0,-3605257358777075534',
            '2031,2,6,23,59,29,375149312|1927,4,30,6,31,59,636422519|-3274882049,-738726793|1|0,0,0,0,0,0,0,0,-3274882049738726,-793',
            '1996,2,3,16,30,2,46694043|2077,8,9,16,8,32,950699760|2572385910,904005717|2|0,0,0,0,0,0,0,2572385910904,5,717',
            '2071,11,28,23,59,59,999999999|2071,11,22,18,36,46,645628649|-537793,-354371350|3|0,0,0,0,0,0,-537793,-354,-371,-350',
            '2094,10,28,20,0,38,901648826|2094,10,5,20,46,9,236138771|-1984469,-665510055|4|0,0,0,0,0,-33074,-29,-665,-510,-55',
            '1925,3,11,1,15,42,622499427|2074,9,4,23,59,59,999999999|4717435457,377500572|5|0,0,0,0,1310398,44,17,377,500,572',
            '1994,5,25,0,0,0,0|1994,3,28,14,10,52,55917311|-4960147,-944082689|6|0,0,0,-57,-9,-49,-7,-944,-82,-689',
            '2020,1,27,10,10,17,930033140|2019,12,1,6,54,43,178517814|-4936534,-751515326|7|0,0,-8,-1,-3,-15,-34,-751,-515,-326',
            '-2555,10,24,20,0,25,604407738|-2555,9,7,13,57,15,801808272|-4082589,-802599466|8|0,-1,0,-17,-6,-3,-9,-802,-599,-466',
            '2047,2,28,23,59,59,999999999|2047,2,2,11,7,45,992405039|-2292734,-7594960|9|0,0,0,-26,-12,-52,-14,-7,-594,-960'
        };
        Assert.isTrue(rows.size() >= 180, 'expected the full vector set');
        List<JiffUnit> units = JiffUnit.values();
        for (String row : rows) {
            List<String> f = row.split('\\|');
            JiffDateTime dt1 = parseCivil(f.get(0));
            JiffDateTime dt2 = parseCivil(f.get(1));
            JiffSignedDuration duration = dt1.durationUntil(dt2);
            Assert.areEqual(parseDuration(f.get(2)), duration, 'duration of ' + row);
            // `duration_since` is `duration_until` with the operands swapped.
            Assert.areEqual(parseDuration(f.get(2)), dt2.durationSince(dt1), 'duration of ' + row);
            JiffUnit largest = units.get(Integer.valueOf(f.get(3)));
            String expected = expand(f.get(4));
            Assert.areEqual(expected, tryUntil(dt1, dt2, largest), 'span of ' + row);
            if (!expected.startsWith('ERR:')) {
                // For each of these rows Jiff was also seen to return the negated span from
                // `since`, and to arrive at the other datetime when the span is added back.
                JiffSpan span = parseSpan(expected);
                Assert.areEqual(span.negate(), dt1.since(dt2, largest), 'negated span of ' + row);
                Assert.areEqual(dt2, dt1.add(span), 'adding back the span of ' + row);
            }
        }
    }

    // ---- since -----------------------------------------------------------

    @IsTest
    static void sinceIsUntilSeenFromTheOtherSide() {
        JiffDateTime earlier = civil(2006, 8, 24, 22, 30, 0, 0);
        JiffDateTime later = atHour(2019, 1, 31, 21);
        Assert.areEqual(new JiffSpan().days(4542).hours(22).minutes(30), later.since(earlier));
        Assert.areEqual(new JiffSpan().days(-4542).hours(-22).minutes(-30), earlier.since(later));
    }

    @IsTest
    static void sinceUsesDaysAsTheLargestUnitWhenNoneIsGiven() {
        JiffDateTime earlier = civil(2006, 8, 24, 22, 30, 0, 0);
        JiffDateTime later = atHour(2019, 1, 31, 21);
        // A missing unit means days, as it does for `until`.
        Assert.areEqual(later.since(earlier), later.since(earlier, (JiffUnit) null));
        Assert.areEqual(
            new JiffSpan().days(4542).hours(22).minutes(30),
            later.since(earlier, (JiffUnit) null)
        );
        Assert.areEqual(
            new JiffSpan().days(-4542).hours(-22).minutes(-30),
            earlier.since(later, (JiffUnit) null)
        );
        Assert.areEqual(later.since(earlier, JiffUnit.DAY), later.since(earlier, (JiffUnit) null));
        Assert.areEqual(
            '-P2913114DT8H37M14.999999999S',
            civil(2024, 2, 29, 15, 22, 45, 0).since(JiffDateTime.MAX, (JiffUnit) null).toString()
        );
    }

    @IsTest
    static void sinceMatchesJiffsOwnTests() {
        JiffDateTime later = atHour(2024, 5, 9, 2);
        JiffDateTime earlier = atHour(2024, 5, 8, 3);
        Assert.areEqual(new JiffSpan().hours(23), later.since(earlier));

        later = atHour(2024, 5, 9, 3);
        earlier = atHour(2024, 5, 8, 2);
        Assert.areEqual(new JiffSpan().days(1).hours(1), later.since(earlier));

        later = atHour(2024, 5, 9, 2);
        earlier = atHour(2024, 5, 10, 3);
        Assert.areEqual(new JiffSpan().days(-1).hours(-1), later.since(earlier));

        later = atHour(2024, 5, 9, 3);
        earlier = atHour(2024, 5, 10, 2);
        Assert.areEqual(new JiffSpan().hours(-23), later.since(earlier));
    }

    @IsTest
    static void sinceWithALargestUnitCountsFromThisDatetime() {
        JiffDateTime dt1 = civil(1995, 12, 7, 3, 24, 30, 3500);
        JiffDateTime dt2 = civil(2019, 1, 31, 15, 30, 0, 0);
        Assert.areEqual('P23Y1M24DT12H5M29.9999965S', dt2.since(dt1, JiffUnit.YEAR).toString());
        // From April 30th back to February 29th is exactly two months, while from February
        // 29th forward to April 30th is two months and a day.
        JiffDateTime april = atHour(2020, 4, 30, 6);
        JiffDateTime february = atHour(2020, 2, 29, 5);
        Assert.areEqual(new JiffSpan().months(2).hours(1), april.since(february, JiffUnit.MONTH));
        Assert.areEqual(
            new JiffSpan().months(2).days(1).hours(1),
            february.until(april, JiffUnit.MONTH)
        );
    }

    // ---- durationUntil and durationSince ---------------------------------

    @IsTest
    static void durationUntilIsAnExactLengthOfTime() {
        JiffDateTime earlier = civil(2006, 8, 24, 22, 30, 0, 0);
        JiffDateTime later = atHour(2019, 1, 31, 21);
        JiffSignedDuration expected = JiffSignedDuration.fromHours(4542 * 24)
            .add(JiffSignedDuration.fromHours(22))
            .add(JiffSignedDuration.fromMins(30));
        Assert.areEqual(expected, earlier.durationUntil(later));
        // Flipping the datetimes is fine, but you'll get a negative duration.
        Assert.areEqual(expected.negate(), later.durationUntil(earlier));
    }

    @IsTest
    static void durationUntilCannotSeeMonthsOrYears() {
        JiffDateTime dt1 = atHour(2024, 1, 1, 0);
        JiffDateTime dt2 = atHour(2025, 4, 1, 0);
        Assert.areEqual(new JiffSpan().years(1).months(3), dt1.until(dt2, JiffUnit.YEAR));
        Assert.areEqual(JiffSignedDuration.fromHours(456 * 24), dt1.durationUntil(dt2));
        Assert.areEqual(
            JiffSignedDuration.fromSecs(31 * 24 * 60 * 60),
            atHour(2024, 7, 1, 0).durationUntil(atHour(2024, 8, 1, 0))
        );
    }

    @IsTest
    static void durationSinceSwapsTheOperands() {
        JiffDateTime earlier = civil(2006, 8, 24, 22, 30, 0, 0);
        JiffDateTime later = atHour(2019, 1, 31, 21);
        Assert.areEqual(
            JiffSignedDuration.fromHours(4542 * 24)
                .add(JiffSignedDuration.fromHours(22))
                .add(JiffSignedDuration.fromMins(30)),
            later.durationSince(earlier)
        );
    }

    @IsTest
    static void theLimitsAreAFiniteDurationApart() {
        JiffSignedDuration whole = JiffSignedDuration.newInstance(631107417599L, 999999999);
        Assert.areEqual(whole, JiffDateTime.MIN.durationUntil(JiffDateTime.MAX));
        Assert.areEqual(whole.negate(), JiffDateTime.MAX.durationUntil(JiffDateTime.MIN));
        Assert.areEqual(whole, JiffDateTime.MAX.durationSince(JiffDateTime.MIN));
    }
}
