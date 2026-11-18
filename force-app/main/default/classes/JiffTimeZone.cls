/**
 * A time zone: the rules that say which UTC offset a region's clocks use at any instant.
 *
 *     JiffTimeZone tz = JiffTimeZone.get('America/New_York');
 *     JiffTimestamp ts = JiffTimestamp.fromSecond(1720493204L);
 *     tz.toOffset(ts);                // -04
 *     tz.toDateTime(ts);              // 2024-07-08T22:46:44
 *     tz.toTimestamp(JiffDateTime.newInstance(2024, 7, 8, 22, 46, 44, 0));  // back to ts
 *
 * There are four kinds of time zone:
 *
 * - `JiffTimeZone.UTC`, which is always at offset zero.
 * - `JiffTimeZone.fixed(offset)`, which is always at the given offset.
 * - `JiffTimeZone.get(name)`, a zone from the IANA Time Zone Database such as
 *   `Europe/London`, whose offset changes over time. `JiffTimeZone.userTimeZone()` is the
 *   running user's zone, and takes the place of Jiff's `TimeZone::system()`.
 * - `JiffTimeZone.unknown()`, a placeholder that behaves like UTC but says that the real time
 *   zone could not be determined. It prints as `Etc/Unknown`.
 *
 * Going from an instant to a civil datetime always has one answer. Going from a civil
 * datetime to an instant may have none (a gap) or two (a fold); `toAmbiguousTimestamp`
 * reports which, and `toTimestamp` resolves it the way most people expect.
 *
 * ## Named zones are backed by the platform
 *
 * Jiff ships its own copy of the time zone database. This port does not: a named zone asks
 * the platform, and the only question the platform answers is "what is the offset at this
 * instant?" (`System.TimeZone.getOffset`). Everything else is derived from that, which has
 * consequences worth knowing:
 *
 * - **Results follow the platform's zone data**, not a particular Jiff release. They can
 *   differ for recent rule changes, and for dates before 1970, where zone data is patchy
 *   (the platform may know nothing before about 1900).
 * - **Names are case sensitive.** Jiff accepts `america/new_york`; here only `UTC` and
 *   `Etc/Unknown` are matched without regard to case, because the platform offers no way to
 *   find the canonical spelling.
 * - **Only names the database could contain are looked up.** The platform knows ids of its
 *   own that are not in the database, and which ones depends on the runtime: abbreviations
 *   (`PST`, `BST`, `IST`), custom offsets (`GMT+05:00`, or `UTC+5`, which reads the sign the
 *   opposite way from a POSIX time zone) and names it merely tolerates (`Etc//UTC`, a name
 *   padded with a no-break space). Jiff knows none of them, so none is passed on: a name must
 *   be `Area/Location` under one of the database's areas (`America/New_York`, `Etc/GMT+5`),
 *   or one of its old single word names (`EST`, `Japan`, `PST8PDT`). Of those, the rarely
 *   used `GMT+0` and `GMT-0` are rejected too. Use `fixed` for a zone at a set offset.
 * - **Aliases are not resolved.** `Asia/Calcutta` and `Asia/Kolkata` behave identically but
 *   are not `equals`, and Jiff's `primary_iana_name`, `is_primary` and `location` are not
 *   available.
 * - **Civil datetimes are resolved by probing.** The offsets one day either side of the
 *   civil time (read as if it were UTC) are the candidates, and each is kept if it really
 *   is the offset at the instant it implies. This is exact unless a zone changes its offset
 *   twice within the same two days.
 * - **Abbreviations** come from the platform's locale data (`Datetime.format('z', name)`),
 *   so they are what the platform calls the zone, not what the database does: an instant in
 *   1880 may be labelled `EST` rather than `LMT`. When the platform has no name and falls
 *   back to the `GMT+05:45` form, the database's numeric style is used instead (`+0545`).
 * - **The daylight saving flag is inferred**, as described under `toOffsetInfo`.
 * - **Transitions are found by searching**, as described under `nextTransition`. A
 *   transition that changes only the abbreviation or the daylight saving flag, and not the
 *   offset, cannot be seen at all.
 *
 * Not ported: POSIX TZ strings and TZif data (`TimeZone::posix`, `TimeZone::tzif`).
 *
 * Instances are immutable.
 *
 * Mirrors `jiff::tz::TimeZone`.
 */
public class JiffTimeZone {
    private static final Integer KIND_UTC = 0;
    private static final Integer KIND_UNKNOWN = 1;
    private static final Integer KIND_FIXED = 2;
    private static final Integer KIND_NAMED = 3;

    // The range of JiffTimestamp, in seconds. Probes never leave it.
    private static final Long MIN_SECOND = -377705023201L;
    private static final Long MAX_SECOND = 253402207200L;
    private static final Long SECS_PER_DAY = 86400L;

    // Daylight saving inference: the offsets 13 and 26 weeks either side of an instant are
    // compared with the offset at the instant. Nearest first, so that most answers need one
    // or two probes.
    private static final List<Long> DST_PROBES = new List<Long>{
        -7862400L,
        7862400L,
        -15724800L,
        15724800L
    };
    // No zone has ever saved more than two hours of daylight. A larger difference is a change
    // of the zone's standard time, such as a move across the date line.
    private static final Integer MAX_DST_SAVING = 7200;

    // Transition search. Six days is just under the shortest stretch after which any zone in
    // the time zone database has returned to an offset it had left (seven days less an hour).
    private static final Long SCAN_STEP = 518400L;
    // 1800-01-01T00:00:00Z. The database's first transition is in 1844.
    private static final Long SCAN_FLOOR = -5364662400L;
    // 2100-01-01T00:00:00Z. Every explicitly listed transition in the database is earlier;
    // after it a zone either repeats a yearly rule forever or never changes again.
    private static final Long SCAN_HORIZON = 4102444800L;
    // 366 days: long enough to contain a transition of any yearly rule.
    private static final Long SCAN_YEAR = 31622400L;

    // The first component of every `Area/Location` name in the time zone database. The list is
    // closed in practice: new zones are added under these areas.
    private static final Set<String> AREAS = new Set<String>{
        'Africa',
        'America',
        'Antarctica',
        'Arctic',
        'Asia',
        'Atlantic',
        'Australia',
        'Brazil',
        'Canada',
        'Chile',
        'Etc',
        'Europe',
        'Indian',
        'Mexico',
        'Pacific',
        'US'
    };
    // The names in the database that have no area. They are kept for old software and no more
    // are added. `GMT+0` and `GMT-0` are left out on purpose: see the class notes. `UTC` is
    // matched before this list is consulted.
    private static final Set<String> SINGLE_NAMES = new Set<String>{
        'CET',
        'CST6CDT',
        'Cuba',
        'EET',
        'EST',
        'EST5EDT',
        'Egypt',
        'Eire',
        'Factory',
        'GB',
        'GB-Eire',
        'GMT',
        'GMT0',
        'Greenwich',
        'HST',
        'Hongkong',
        'Iceland',
        'Iran',
        'Israel',
        'Jamaica',
        'Japan',
        'Kwajalein',
        'Libya',
        'MET',
        'MST',
        'MST7MDT',
        'NZ',
        'NZ-CHAT',
        'Navajo',
        'PRC',
        'PST8PDT',
        'Poland',
        'Portugal',
        'ROC',
        'ROK',
        'Singapore',
        'Turkey',
        'UCT',
        'Universal',
        'W-SU',
        'WET',
        'Zulu'
    };

    /** The UTC time zone: offset zero, always. Its IANA name is `UTC`. */
    public static final JiffTimeZone UTC = new JiffTimeZone(KIND_UTC, JiffOffset.UTC, 'UTC', null);
    private static final JiffTimeZone UNKNOWN = new JiffTimeZone(
        KIND_UNKNOWN,
        JiffOffset.UTC,
        null,
        null
    );

    private final Integer kind;
    // The offset of a UTC, unknown or fixed zone. Null for a named zone.
    private final JiffOffset fixedOffset;
    // `UTC`, or the IANA name of a named zone. Null for fixed and unknown zones.
    private final String name;
    // The platform zone behind a named zone. Null otherwise.
    private final TimeZone platformZone;

    private JiffTimeZone(Integer kind, JiffOffset fixedOffset, String name, TimeZone platformZone) {
        this.kind = kind;
        this.fixedOffset = fixedOffset;
        this.name = name;
        this.platformZone = platformZone;
    }

    // ---- construction ---------------------------------------------------

    /**
     * A time zone that is always at the given offset. It has no name, no daylight saving time
     * and no transitions. An offset of zero gives `UTC`.
     */
    public static JiffTimeZone fixed(JiffOffset offset) {
        if (offset == null) {
            throw new JiffException('a fixed time zone needs an offset');
        }
        return offset.isZero() ? UTC : new JiffTimeZone(KIND_FIXED, offset, null, null);
    }

    /**
     * Looks up a zone in the platform's copy of the IANA Time Zone Database by name, for
     * example `Asia/Tokyo`. Throws `JiffException` when the platform does not know the name.
     *
     * The name must be spelled exactly as the database spells it; see the class notes. `UTC`
     * in any letter case gives `JiffTimeZone.UTC`, and `Etc/Unknown` gives `unknown()`.
     */
    public static JiffTimeZone get(String ianaName) {
        JiffTimeZone zone = lookup(ianaName);
        if (zone == null) {
            throw new JiffException(
                'failed to find time zone `' + ianaName + '` in time zone database'
            );
        }
        return zone;
    }

    /**
     * The running user's time zone, from `UserInfo.getTimeZone()`. This is the port's
     * counterpart to Jiff's `TimeZone::system()`. Like it, this never fails: if the platform
     * reports a zone that cannot be looked up, the result is `unknown()`.
     */
    public static JiffTimeZone userTimeZone() {
        TimeZone zone = UserInfo.getTimeZone();
        return lookupOrUnknown(zone == null ? null : zone.getID());
    }

    /**
     * A placeholder for "the time zone could not be determined". It behaves exactly like UTC,
     * but has no IANA name, is not equal to `UTC`, and prints as `Etc/Unknown` so that the
     * failure stays visible.
     */
    public static JiffTimeZone unknown() {
        return UNKNOWN;
    }

    @TestVisible
    private static JiffTimeZone lookupOrUnknown(String ianaName) {
        JiffTimeZone zone = lookup(ianaName);
        return zone == null ? UNKNOWN : zone;
    }

    /** Resolves a name to a zone, or returns null when the platform does not know it. */
    private static JiffTimeZone lookup(String ianaName) {
        if (ianaName == null) {
            return null;
        }
        if (ianaName.equalsIgnoreCase('UTC')) {
            return UTC;
        }
        if (ianaName.equalsIgnoreCase('Etc/Unknown')) {
            return UNKNOWN;
        }
        // The platform accepts ids that are not in the time zone database: abbreviations,
        // `GMT+05:00` style offsets, names with stray characters. Jiff does not.
        if (!isDatabaseName(ianaName)) {
            return null;
        }
        // The platform answers an unrecognised id with its GMT zone instead of an error. A
        // recognised id, including a genuine alias of GMT, is echoed back unchanged.
        TimeZone zone = TimeZone.getTimeZone(ianaName);
        if (zone == null || !ianaName.equals(zone.getID())) {
            return null;
        }
        return new JiffTimeZone(KIND_NAMED, null, ianaName, zone);
    }

    /**
     * Whether `name` is spelled the way the time zone database spells its names: one of the
     * single word names, or an area followed by one or more `/` separated components made of
     * ASCII letters, digits, `_`, `-` and `+`. Whether such a zone exists is for the platform
     * to say; this only keeps the platform's own inventions away from it.
     */
    private static Boolean isDatabaseName(String name) {
        Integer slash = name.indexOf('/');
        if (slash < 0) {
            return SINGLE_NAMES.contains(name);
        }
        if (!AREAS.contains(name.substring(0, slash))) {
            return false;
        }
        Integer componentStart = slash + 1;
        for (Integer i = componentStart; i < name.length(); i++) {
            Integer ch = name.charAt(i);
            if (ch == 47) {
                if (i == componentStart) {
                    return false;
                }
                componentStart = i + 1;
            } else if (
                !(ch >= 97 &&
                ch <= 122) &&
                !(ch >= 65 &&
                ch <= 90) &&
                !(ch >= 48 &&
                ch <= 57) &&
                ch != 95 &&
                ch != 45 &&
                ch != 43
            ) {
                return false;
            }
        }
        // The last component must not be empty either.
        return componentStart < name.length();
    }

    // ---- identity -------------------------------------------------------

    /**
     * The IANA name of this zone, such as `America/New_York` or `UTC`. Null for fixed offset
     * zones and for the unknown zone.
     */
    public String ianaName() {
        return name;
    }

    /** Whether this is the placeholder returned by `unknown()`. */
    public Boolean isUnknown() {
        return kind == KIND_UNKNOWN;
    }

    // ---- instant to civil -----------------------------------------------

    /** The UTC offset this zone uses at the given instant. */
    public JiffOffset toOffset(JiffTimestamp timestamp) {
        if (kind != KIND_NAMED) {
            return fixedOffset;
        }
        return JiffOffset.fromSeconds(offsetAt(floorSecond(timestamp)));
    }

    /**
     * The offset at the given instant together with the zone's abbreviation and whether
     * daylight saving time is in effect.
     *
     * `UTC` and the unknown zone report the abbreviation `UTC`; a fixed zone reports its offset
     * (`-05`). None of them has daylight saving time.
     *
     * For a named zone the abbreviation comes from the platform (see the class notes), and
     * the daylight saving flag is inferred, because the platform does not expose it. An
     * instant is reported as daylight saving time when the zone's offset 13 or 26 weeks
     * earlier or later is lower than its offset at the instant, by no more than two hours.
     * That is right for ordinary summer time. It differs from the time zone database when:
     *
     * - the zone data models the *lower* offset as daylight saving time ("negative DST"). The
     *   database is published in two forms, and the one most operating systems install does
     *   this for Irish winter time in `Europe/Dublin` and for Ramadan in `Africa/Casablanca`;
     *   the flag is then the opposite of that data's. (The copy bundled with Jiff uses the
     *   other form, with which the inference agrees.)
     * - a zone moved its standard time forward by up to two hours for good. Instants in the 26
     *   weeks after such a move are reported as daylight saving time.
     * - daylight saving time lasted without a break for a year or more (United States "War
     *   Time", 1942 to 1945), or the database flags a period as daylight saving time that has
     *   the same offset as standard time. No lower offset is seen, so the flag is `NO`.
     * - the standard time between two daylight saving periods lasted less than 13 weeks, which
     *   the four probes can miss.
     */
    public JiffTimeZoneOffsetInfo toOffsetInfo(JiffTimestamp timestamp) {
        if (kind == KIND_FIXED) {
            return new JiffTimeZoneOffsetInfo(fixedOffset, fixedOffset.toString(), JiffDst.NO);
        }
        if (kind != KIND_NAMED) {
            return new JiffTimeZoneOffsetInfo(JiffOffset.UTC, 'UTC', JiffDst.NO);
        }
        return infoAt(floorSecond(timestamp));
    }

    /**
     * This zone's offset, if it never changes. Throws for a named zone, whose offset depends
     * on the instant.
     */
    public JiffOffset toFixedOffset() {
        if (kind == KIND_NAMED) {
            throw new JiffException(
                'cannot convert non-fixed IANA time zone to offset ' +
                'without a timestamp or civil datetime'
            );
        }
        return fixedOffset;
    }

    /** The civil datetime that clocks in this zone show at the given instant. */
    public JiffDateTime toDateTime(JiffTimestamp timestamp) {
        return toOffset(timestamp).toDateTime(timestamp);
    }

    // ---- civil to instant -----------------------------------------------

    /**
     * Finds the instant or instants at which clocks in this zone show the given civil
     * datetime, without choosing between them. The result says whether the datetime is
     * unambiguous, falls in a gap, or falls in a fold, and offers each way of resolving it.
     */
    public JiffAmbiguousTimestamp toAmbiguousTimestamp(JiffDateTime dt) {
        if (kind != KIND_NAMED) {
            return JiffAmbiguousTimestamp.newInstance(
                dt,
                JiffAmbiguousOffset.unambiguous(fixedOffset)
            );
        }
        // The civil time read as if it were UTC. The true instant is this minus the offset.
        Long local = dt.toEpochSecond();
        // No offset is as large as a day, so these two instants are on either side of every
        // instant the civil time could denote.
        Integer before = offsetAt(clamp(local - SECS_PER_DAY));
        Integer after = offsetAt(clamp(local + SECS_PER_DAY));
        if (before == after) {
            return ambiguous(dt, JiffAmbiguousOffset.unambiguous(JiffOffset.fromSeconds(before)));
        }
        // A transition is nearby. A candidate offset is real if it is the offset in effect at
        // the instant it implies.
        Boolean beforeFits = offsetAt(clamp(local - before)) == before;
        Boolean afterFits = offsetAt(clamp(local - after)) == after;
        JiffOffset beforeOffset = JiffOffset.fromSeconds(before);
        JiffOffset afterOffset = JiffOffset.fromSeconds(after);
        if (beforeFits && afterFits) {
            return ambiguous(dt, JiffAmbiguousOffset.fold(beforeOffset, afterOffset));
        }
        if (beforeFits) {
            return ambiguous(dt, JiffAmbiguousOffset.unambiguous(beforeOffset));
        }
        if (afterFits) {
            return ambiguous(dt, JiffAmbiguousOffset.unambiguous(afterOffset));
        }
        return ambiguous(dt, JiffAmbiguousOffset.gap(beforeOffset, afterOffset));
    }

    private static JiffAmbiguousTimestamp ambiguous(JiffDateTime dt, JiffAmbiguousOffset offset) {
        return JiffAmbiguousTimestamp.newInstance(dt, offset);
    }

    /**
     * The instant at which clocks in this zone show the given civil datetime, resolving a gap
     * or a fold with the `COMPATIBLE` strategy: a time skipped by the clocks moves forward by
     * the length of the gap, and a repeated time means its first occurrence. Throws only if
     * the instant is outside the range of `JiffTimestamp`.
     */
    public JiffTimestamp toTimestamp(JiffDateTime dt) {
        return toAmbiguousTimestamp(dt).compatible();
    }

    /**
     * Finds the zoned datetime or datetimes that have the given civil datetime in this zone,
     * without choosing between them. The result says whether the civil datetime is
     * unambiguous, falls in a gap, or falls in a fold, and offers each way of resolving it.
     *
     * This is `toAmbiguousTimestamp` with this time zone carried along, so that resolving it
     * gives a `JiffZonedDateTime` rather than a bare instant. (Jiff's
     * `into_ambiguous_zoned_datetime` is this same method.)
     */
    public JiffAmbiguousZonedDateTime toAmbiguousZonedDateTime(JiffDateTime dt) {
        return JiffAmbiguousZonedDateTime.newInstance(toAmbiguousTimestamp(dt), this);
    }

    /**
     * The zoned datetime with the given civil datetime in this zone, resolving a gap or a
     * fold with the `COMPATIBLE` strategy: a time skipped by the clocks moves forward by the
     * length of the gap, and a repeated time means its first occurrence.
     *
     *     JiffTimeZone tz = JiffTimeZone.get('America/New_York');
     *     tz.toZonedDateTime(JiffDateTime.newInstance(2024, 3, 10, 2, 30, 0, 0));
     *     // 2024-03-10T03:30:00-04:00[America/New_York]
     *
     * Throws only if the instant is outside the range of `JiffTimestamp`.
     */
    public JiffZonedDateTime toZonedDateTime(JiffDateTime dt) {
        return toAmbiguousZonedDateTime(dt).compatible();
    }

    // ---- transitions ----------------------------------------------------

    /**
     * The most recent change of this zone's offset strictly before the given instant, or null
     * if there is none. `UTC`, fixed and unknown zones never have one.
     *
     * Call it again with the transition's own timestamp to walk further back; this is the
     * port's counterpart to Jiff's `TimeZone::preceding` iterator. See `nextTransition` for
     * how transitions are found and what that costs.
     */
    public JiffTimeZoneTransition previousTransition(JiffTimestamp timestamp) {
        if (kind != KIND_NAMED) {
            return null;
        }
        // The last second at which a transition would still be strictly before `timestamp`.
        Long newest = floorSecond(timestamp);
        if (timestamp.subsecNanosecond() == 0) {
            newest -= 1;
        }
        if (newest <= SCAN_FLOOR) {
            return null;
        }
        Integer current = offsetAt(newest);
        Long same = newest;
        if (newest > SCAN_HORIZON + SCAN_YEAR) {
            // Far in the future a zone either repeats a yearly rule or has stopped changing.
            // A year without a change therefore means there is none back to the horizon.
            JiffTimeZoneTransition recent = scanBack(same, newest - SCAN_YEAR, current);
            if (recent != null) {
                return recent;
            }
            same = SCAN_HORIZON + SCAN_YEAR;
        }
        return scanBack(same, SCAN_FLOOR, current);
    }

    /**
     * The first change of this zone's offset strictly after the given instant, or null if
     * there is none. `UTC`, fixed and unknown zones never have one.
     *
     * Call it again with the transition's own timestamp to walk further forward; this is the
     * port's counterpart to Jiff's `TimeZone::following` iterator.
     *
     * The platform does not list transitions, so they are found by probing the offset every
     * six days from the given instant and then bisecting to the exact second. The search is
     * bounded:
     *
     * - It covers 1800 through 2100. Nothing in the time zone database changes before 1844,
     *   and beyond 2100 a zone either repeats a yearly rule forever or never changes again, so
     *   past that point one further year is searched and no more.
     * - Two changes less than six days apart that cancel each other out would be missed. No
     *   zone in the database has ever done that; the closest are seven days less an hour.
     * - A transition that changes only the abbreviation or the daylight saving flag, with no
     *   change of offset, is invisible to the platform and is never reported.
     *
     * The cost is about 61 offset lookups for each year searched, plus about 25 once a change
     * is found. A zone that observes daylight saving time answers within a year. A zone whose
     * offset last changed decades ago, or never, is searched all the way to the bound, which
     * is up to about 18,000 lookups; avoid doing that in a loop.
     */
    public JiffTimeZoneTransition nextTransition(JiffTimestamp timestamp) {
        if (kind != KIND_NAMED) {
            return null;
        }
        // Nothing changes before the floor, so the search can start there.
        Long same = Math.max(floorSecond(timestamp), SCAN_FLOOR);
        Long ceiling = Math.min(Math.max(same, SCAN_HORIZON) + SCAN_YEAR, MAX_SECOND);
        Integer base = offsetAt(same);
        while (same < ceiling) {
            Long probe = Math.min(same + SCAN_STEP, ceiling);
            if (offsetAt(probe) != base) {
                return transitionAt(firstSecond(same, probe, base, false));
            }
            same = probe;
        }
        return null;
    }

    /**
     * Walks back from `same`, a second at which the offset is `current`, to `floor`. Returns
     * the transition that began the stretch of `current` offset containing `same`, or null
     * when the offset is still `current` at `floor`.
     */
    private JiffTimeZoneTransition scanBack(Long same, Long floor, Integer current) {
        Long newest = same;
        while (newest > floor) {
            Long probe = Math.max(newest - SCAN_STEP, floor);
            if (offsetAt(probe) != current) {
                return transitionAt(firstSecond(probe, newest, current, true));
            }
            newest = probe;
        }
        return null;
    }

    /**
     * Bisects for the first second in `low + 1 .. high` at which the offset equals `offset`
     * (when `wantEqual`) or differs from it (when not). The condition must be false at `low`
     * and true at `high`.
     */
    private Long firstSecond(Long low, Long high, Integer offset, Boolean wantEqual) {
        Long lo = low;
        Long hi = high;
        while (hi - lo > 1) {
            Long middle = lo + (hi - lo) / 2;
            if ((offsetAt(middle) == offset) == wantEqual) {
                hi = middle;
            } else {
                lo = middle;
            }
        }
        return hi;
    }

    private JiffTimeZoneTransition transitionAt(Long second) {
        return new JiffTimeZoneTransition(JiffTimestamp.fromSecond(second), infoAt(second));
    }

    // ---- platform access ------------------------------------------------

    /** The whole second containing `timestamp`, rounding toward the past. */
    private static Long floorSecond(JiffTimestamp timestamp) {
        return timestamp.subsecNanosecond() < 0 ? timestamp.asSecond() - 1 : timestamp.asSecond();
    }

    private static Long clamp(Long second) {
        return Math.min(Math.max(second, MIN_SECOND), MAX_SECOND);
    }

    /** The platform's offset for this named zone at a Unix second, in seconds. */
    private Integer offsetAt(Long second) {
        return platformZone.getOffset(Datetime.newInstance(second * 1000L)) / 1000;
    }

    private JiffTimeZoneOffsetInfo infoAt(Long second) {
        Integer offsetSeconds = offsetAt(second);
        return new JiffTimeZoneOffsetInfo(
            JiffOffset.fromSeconds(offsetSeconds),
            abbreviationAt(second, offsetSeconds),
            inferDst(second, offsetSeconds)
        );
    }

    private String abbreviationAt(Long second, Integer offsetSeconds) {
        String text = Datetime.newInstance(second * 1000L).format('z', name);
        // With no name for the zone the platform prints `GMT+05:45`. The time zone database
        // abbreviates such zones as `+0545`.
        if (text.startsWith('GMT+') || text.startsWith('GMT-')) {
            return numericAbbreviation(offsetSeconds);
        }
        return text;
    }

    /** An offset in the database's numeric abbreviation style: `+13`, `-0330`, `+055328`. */
    @TestVisible
    private static String numericAbbreviation(Integer offsetSeconds) {
        Integer magnitude = Math.abs(offsetSeconds);
        Integer minutes = Math.mod(magnitude / 60, 60);
        Integer seconds = Math.mod(magnitude, 60);
        String out = (offsetSeconds < 0 ? '-' : '+') + JiffMath.pad(magnitude / 3600, 2);
        if (minutes != 0 || seconds != 0) {
            out += JiffMath.pad(minutes, 2);
        }
        return seconds == 0 ? out : out + JiffMath.pad(seconds, 2);
    }

    private JiffDst inferDst(Long second, Integer offsetSeconds) {
        for (Long delta : DST_PROBES) {
            Integer saving = offsetSeconds - offsetAt(clamp(second + delta));
            if (saving > 0 && saving <= MAX_DST_SAVING) {
                return JiffDst.YES;
            }
        }
        return JiffDst.NO;
    }

    // ---- equality and text ----------------------------------------------

    /**
     * Whether two zones are the same kind with the same offset or the same name. Names are
     * compared exactly, so two aliases of one zone are not equal; see the class notes.
     */
    public Boolean equals(Object other) {
        if (!(other instanceof JiffTimeZone)) {
            return false;
        }
        JiffTimeZone that = (JiffTimeZone) other;
        if (kind != that.kind) {
            return false;
        }
        return kind == KIND_NAMED ? name.equals(that.name) : fixedOffset.equals(that.fixedOffset);
    }

    public Integer hashCode() {
        Long detail = kind == KIND_NAMED ? name.hashCode() : fixedOffset.hashCode();
        return JiffMath.floorMod(detail * 31 + kind, 1000000007L).intValue();
    }

    /**
     * The name of this zone for display: its IANA name, `UTC`, `Etc/Unknown`, or the offset of
     * a fixed zone (`-05`).
     */
    public override String toString() {
        if (kind == KIND_UNKNOWN) {
            return 'Etc/Unknown';
        }
        return kind == KIND_FIXED ? fixedOffset.toString() : name;
    }
}
