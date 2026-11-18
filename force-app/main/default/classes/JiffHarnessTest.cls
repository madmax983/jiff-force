/**
 * Pins down the Apex language and platform behaviour the rest of the library relies on.
 *
 * These tests look trivial, and on the platform they are. Their job is to hold the local JVM
 * harness (tools/apexjvm) to the same answers a Salesforce org gives, so that a divergence
 * between the two shows up here rather than as a wrong date somewhere else.
 */
@IsTest
private class JiffHarnessTest {
    private enum Colour {
        RED,
        GREEN
    }

    private class Point {
        private final Integer x;
        private final Integer y;

        Point(Integer x, Integer y) {
            this.x = x;
            this.y = y;
        }

        public Boolean equals(Object other) {
            if (!(other instanceof Point)) {
                return false;
            }
            Point that = (Point) other;
            return this.x == that.x && this.y == that.y;
        }

        public Integer hashCode() {
            return 31 * x + y;
        }
    }

    @IsTest
    static void integerDivisionTruncatesTowardZero() {
        Assert.areEqual(2, 7 / 3);
        Assert.areEqual(-2, -7 / 3);
        Assert.areEqual(2L, 7L / 3L);
        Assert.areEqual(-2L, -7L / 3L);
    }

    @IsTest
    static void mathModTakesTheSignOfTheDividend() {
        Assert.areEqual(1, Math.mod(7, 3));
        Assert.areEqual(-1, Math.mod(-7, 3));
        Assert.areEqual(1L, Math.mod(7L, -3L));
        Assert.areEqual(-1L, Math.mod(-7L, 3L));
    }

    @IsTest
    static void integersWidenToLongInArithmetic() {
        Integer i = 2000000000;
        Long widened = i;
        Long product = widened * 4;
        Assert.areEqual(8000000000L, product);
        Long small = 86399L;
        Assert.areEqual(86399, small.intValue());
    }

    @IsTest
    static void stringEqualityOperatorIgnoresCaseButEqualsDoesNot() {
        String upper = 'UTC';
        String lower = 'utc';
        Assert.isTrue(upper == lower);
        Assert.isFalse(upper.equals(lower));
        Assert.isTrue(upper.equalsIgnoreCase(lower));
    }

    @IsTest
    static void stringHelpersBehaveAsDocumented() {
        Assert.areEqual('007', '7'.leftPad(3, '0'));
        Assert.areEqual('1234', '1234'.leftPad(3, '0'));
        Assert.areEqual(65, 'A'.charAt(0));
        Assert.areEqual('bc', 'abcd'.substring(1, 3));
        Assert.areEqual('it\'s', 'it' + '\'' + 's');
        Assert.areEqual('a-b', String.join(new List<String>{ 'a', 'b' }, '-'));
        Assert.areEqual('AZ', String.fromCharArray(new List<Integer>{ 65, 90 }));
        Assert.areEqual(2, 'a\\b'.indexOf('b'));
    }

    @IsTest
    static void collectionsSupportLiteralsAndIndexing() {
        List<Long> values = new List<Long>{ 3L, 1L, 2L };
        values.sort();
        Assert.areEqual(1L, values[0]);
        values[0] = 10L;
        Assert.areEqual(10L, values.get(0));
        Map<String, Integer> lookup = new Map<String, Integer>{ 'a' => 1, 'b' => 2 };
        Assert.areEqual(2, lookup.get('b'));
        Assert.isFalse(lookup.containsKey('A'));
        Assert.isNull(lookup.get('missing'));
    }

    @IsTest
    static void valueTypesWorkAsMapKeys() {
        Map<Point, String> names = new Map<Point, String>();
        names.put(new Point(1, 2), 'first');
        Assert.areEqual('first', names.get(new Point(1, 2)));
        Assert.isTrue(new Point(1, 2).equals(new Point(1, 2)));
    }

    @IsTest
    static void switchWorksOnEnumsAndIntegers() {
        Assert.areEqual('red', describe(Colour.RED));
        Assert.areEqual('other', describe(Colour.GREEN));
        Assert.areEqual(2, Colour.values().size());
        Assert.areEqual(1, Colour.GREEN.ordinal());
        Assert.areEqual('GREEN', Colour.GREEN.name());
    }

    private static String describe(Colour colour) {
        switch on colour {
            when RED {
                return 'red';
            }
            when else {
                return 'other';
            }
        }
    }

    private class Holder {
        private Integer optional;
        private final Long required;

        Holder(Long required) {
            this.required = required;
        }

        Boolean isUnset() {
            return optional == null;
        }

        void assign(Integer value) {
            optional = value;
        }

        Integer orZero() {
            return optional == null ? 0 : optional;
        }

        Integer orNull() {
            return optional;
        }
    }

    private static Integer lengthOrNull(String text) {
        if (text == null) {
            return null;
        }
        return text.length();
    }

    private static Long doubled(Long value) {
        return value == null ? null : value * 2;
    }

    @IsTest
    static void numbersCanBeNullWhereTheCodeAllowsIt() {
        Assert.isNull(lengthOrNull(null));
        Assert.areEqual(3, lengthOrNull('abc'));
        Integer missing = lengthOrNull(null);
        Assert.isTrue(missing == null);
        Assert.isNull(doubled(null));
        Assert.areEqual(10L, doubled(5L));
        Holder holder = new Holder(7L);
        Assert.isTrue(holder.isUnset());
        Assert.areEqual(0, holder.orZero());
        Assert.isNull(holder.orNull());
        holder.assign(4);
        Assert.areEqual(4, holder.orNull());
        Assert.isFalse(holder.isUnset());
        Assert.areEqual(4, holder.orZero());
        Map<String, Long> lookup = new Map<String, Long>{ 'a' => 1L };
        Long absent = lookup.get('b');
        Assert.isTrue(absent == null);
    }

    @IsTest
    static void customExceptionsCarryTheirMessage() {
        try {
            throw new JiffException('boom');
        } catch (JiffException e) {
            Assert.areEqual('boom', e.getMessage());
        }
    }

    @IsTest
    static void platformTimeZoneReportsHistoricalOffsets() {
        TimeZone newYork = TimeZone.getTimeZone('America/New_York');
        Assert.areEqual('America/New_York', newYork.getID());
        // 2024-01-15T12:00:00Z is standard time, 2024-07-15T12:00:00Z is daylight time.
        Assert.areEqual(-18000000, newYork.getOffset(Datetime.newInstance(1705320000000L)));
        Assert.areEqual(-14400000, newYork.getOffset(Datetime.newInstance(1721044800000L)));
        Assert.areEqual('GMT', TimeZone.getTimeZone('Not/AZone').getID());
    }

    @IsTest
    static void platformTimeZoneEchoesKnownIdsAndIsCaseSensitive() {
        // JiffTimeZone.get tells a known zone from the GMT fallback by the id coming back
        // unchanged. That has to hold for aliases, and for zones that really are GMT.
        for (
            String id : new List<String>{
                'GMT',
                'Etc/GMT',
                'Etc/UTC',
                'Etc/GMT+5',
                'Asia/Calcutta',
                'Asia/Kolkata',
                'Australia/Tasmania',
                'Europe/London'
            }
        ) {
            Assert.areEqual(id, TimeZone.getTimeZone(id).getID());
        }
        // Ids are matched exactly: a different letter case is an unknown zone.
        Assert.areEqual('GMT', TimeZone.getTimeZone('america/new_york').getID());
        Assert.areEqual('GMT', TimeZone.getTimeZone('').getID());
        Assert.areEqual(0, TimeZone.getTimeZone('Not/AZone').getOffset(Datetime.newInstance(0L)));
    }

    @IsTest
    static void platformTimeZoneOffsetsChangeAtTheExactMillisecond() {
        TimeZone newYork = TimeZone.getTimeZone('America/New_York');
        // 2024-03-10T07:00:00Z, when clocks went from 02:00 to 03:00.
        Assert.areEqual(-18000000, newYork.getOffset(Datetime.newInstance(1710053999999L)));
        Assert.areEqual(-14400000, newYork.getOffset(Datetime.newInstance(1710054000000L)));
        // Before the epoch.
        Assert.areEqual(-14400000, newYork.getOffset(Datetime.newInstance(-5767200001L)));
        Assert.areEqual(-18000000, newYork.getOffset(Datetime.newInstance(-5767200000L)));
        // Offsets that are not whole hours, and one of a whole day's difference.
        TimeZone kolkata = TimeZone.getTimeZone('Asia/Kolkata');
        Assert.areEqual(19800000, kolkata.getOffset(Datetime.newInstance(0L)));
        TimeZone apia = TimeZone.getTimeZone('Pacific/Apia');
        Assert.areEqual(-36000000, apia.getOffset(Datetime.newInstance(1325239199000L)));
        Assert.areEqual(50400000, apia.getOffset(Datetime.newInstance(1325239200000L)));
    }

    @IsTest
    static void platformTimeZoneRulesExtendAcrossTheWholeTimestampRange() {
        TimeZone newYork = TimeZone.getTimeZone('America/New_York');
        // Yearly rules keep applying: 9999-11-07T06:00:00Z is the last change JiffTimestamp
        // can see, and the offset is still defined at the limits of its range.
        Assert.areEqual(-14400000, newYork.getOffset(Datetime.newInstance(253397570399000L)));
        Assert.areEqual(-18000000, newYork.getOffset(Datetime.newInstance(253397570400000L)));
        Assert.areEqual(-18000000, newYork.getOffset(Datetime.newInstance(253402207200000L)));
        // Zone data differs between platforms before about 1900, so only the sign is pinned.
        Assert.isTrue(newYork.getOffset(Datetime.newInstance(-377705023201000L)) < 0);
    }

    @IsTest
    static void datetimeFormatsTimeZoneAbbreviations() {
        Datetime summer = Datetime.newInstance(1720493204000L);
        Datetime winter = Datetime.newInstance(1704941204000L);
        Assert.areEqual('EDT', summer.format('z', 'America/New_York'));
        Assert.areEqual('EST', winter.format('z', 'America/New_York'));
        Assert.areEqual('BST', summer.format('z', 'Europe/London'));
        Assert.areEqual('GMT', winter.format('z', 'Europe/London'));
        Assert.areEqual('AEST', summer.format('z', 'Australia/Sydney'));
        Assert.areEqual('AEDT', winter.format('z', 'Australia/Sydney'));
        Assert.areEqual('IST', summer.format('z', 'Asia/Kolkata'));
        // A zone the platform has no name for is written as an offset from GMT.
        Assert.areEqual('GMT-05:00', summer.format('z', 'Etc/GMT+5'));
        Assert.areEqual('GMT+14:00', summer.format('z', 'Etc/GMT-14'));
    }

    @IsTest
    static void userInfoReportsAZoneThePlatformCanLookUp() {
        String id = UserInfo.getTimeZone().getID();
        Assert.isTrue(String.isNotBlank(id));
        Assert.areEqual(id, TimeZone.getTimeZone(id).getID());
    }

    @IsTest
    static void systemClockAgreesWithDatetimeNow() {
        Long before = System.currentTimeMillis();
        Long now = Datetime.now().getTime();
        Long after = System.currentTimeMillis();
        Assert.isTrue(before <= now && now <= after);
        // Some time after 2023-11-14.
        Assert.isTrue(now > 1700000000000L);
    }

    private class Countdown implements Iterator<String>, Iterable<String> {
        private Integer remaining = 0;

        Countdown(Integer start) {
            this.remaining = start;
        }

        public Boolean hasNext() {
            return remaining > 0;
        }

        public String next() {
            remaining--;
            return String.valueOf(remaining + 1);
        }

        public Iterator<String> iterator() {
            return this;
        }
    }

    @IsTest
    static void forLoopsAcceptACustomIterable() {
        List<String> seen = new List<String>();
        for (String value : new Countdown(3)) {
            seen.add(value);
        }
        Assert.areEqual(new List<String>{ '3', '2', '1' }, seen);
        Iterator<String> cursor = new Countdown(1).iterator();
        Assert.isTrue(cursor.hasNext());
        Assert.areEqual('1', cursor.next());
        Assert.isFalse(cursor.hasNext());
    }

    @IsTest
    static void datetimeRoundTripsEpochMilliseconds() {
        Datetime instant = Datetime.newInstanceGmt(2024, 2, 29, 12, 30, 45);
        Assert.areEqual(1709209845000L, instant.getTime());
        Assert.areEqual(instant, Datetime.newInstance(1709209845000L));
        Assert.areEqual(29, instant.dayGmt());
    }
}
