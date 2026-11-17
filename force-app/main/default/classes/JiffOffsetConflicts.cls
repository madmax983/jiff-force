/**
 * Resolves a civil datetime that comes with both a UTC offset and a time zone, which may
 * disagree, according to a `JiffOffsetConflict` strategy.
 *
 *     JiffDateTime dt = JiffDateTime.newInstance(2024, 6, 14, 17, 30, 0, 0);
 *     JiffOffset offset = JiffOffset.fromHours(-5);   // wrong: New York is at -04 here
 *     JiffTimeZone newYork = JiffTimeZone.get('America/New_York');
 *
 *     JiffOffsetConflicts.resolve(JiffOffsetConflict.ALWAYS_OFFSET, dt, offset, newYork)
 *         .unambiguous();   // 2024-06-14T18:30:00-04:00[America/New_York]
 *     JiffOffsetConflicts.resolve(JiffOffsetConflict.ALWAYS_TIME_ZONE, dt, offset, newYork)
 *         .unambiguous();   // 2024-06-14T17:30:00-04:00[America/New_York]
 *     JiffOffsetConflicts.resolve(JiffOffsetConflict.PREFER_OFFSET, dt, offset, newYork)
 *         .unambiguous();   // 2024-06-14T17:30:00-04:00[America/New_York]
 *     JiffOffsetConflicts.resolve(JiffOffsetConflict.REJECT, dt, offset, newYork);
 *     // throws JiffException
 *
 * The result is a `JiffAmbiguousZonedDateTime` rather than a zoned datetime, because settling
 * the offset does not always settle the instant: when the offset is ignored or turns out to be
 * wrong, the civil datetime may still fall in a gap or a fold of the time zone, and the caller
 * chooses how to disambiguate it.
 *
 * | Strategy           | Offset is valid for the zone | Offset is not valid for the zone   |
 * | ------------------ | ---------------------------- | ---------------------------------- |
 * | `ALWAYS_OFFSET`    | the offset decides           | the offset decides                 |
 * | `ALWAYS_TIME_ZONE` | the time zone decides        | the time zone decides              |
 * | `PREFER_OFFSET`    | the offset decides           | the time zone decides              |
 * | `REJECT`           | the offset decides           | throws                             |
 *
 * An offset is valid when it is the zone's one offset for the civil datetime, or one of the
 * two offsets of a fold. No offset is valid for a civil datetime in a gap.
 *
 * In Jiff these are methods of the `OffsetConflict` enum. Apex enums cannot declare methods,
 * so they are static methods here that take the strategy as their first argument.
 *
 * Mirrors `jiff::tz::OffsetConflict::resolve` and `jiff::tz::OffsetConflict::resolve_with`.
 */
public class JiffOffsetConflicts {
    /**
     * Decides whether the offset that came with a datetime counts as the same as an offset the
     * time zone really has. Pass an implementation to `resolveWith` when exact equality is too
     * strict, for example when the given offset was read from text that can only hold whole
     * minutes while the zone's offset has seconds.
     *
     * Stands in for the `is_equal` closure of `jiff::tz::OffsetConflict::resolve_with`.
     */
    public interface Equality {
        /**
         * Whether `given`, the offset that came with the datetime, should be treated as equal
         * to `candidate`, an offset of the time zone.
         */
        Boolean isEqual(JiffOffset given, JiffOffset candidate);
    }

    /**
     * Resolves `dt`, `offset` and `tz` with the given strategy, comparing offsets exactly, to
     * the second.
     *
     * Throws only with `JiffOffsetConflict.REJECT`, when the offset is not one the time zone
     * has for the civil datetime.
     */
    public static JiffAmbiguousZonedDateTime resolve(
        JiffOffsetConflict strategy,
        JiffDateTime dt,
        JiffOffset offset,
        JiffTimeZone tz
    ) {
        return resolveWith(strategy, dt, offset, tz, null);
    }

    /**
     * Like `resolve`, but with a caller supplied test for whether the given offset matches an
     * offset of the time zone. A null `isEqual` compares the offsets exactly.
     *
     * When the test accepts the given offset in a fold, the given offset itself is used. When
     * it accepts it for an unambiguous datetime, the time zone's own offset is used, so an
     * approximate match never changes the instant:
     *
     *     // Monrovia was 44 minutes and 30 seconds behind UTC until 1972. Text formats
     *     // round that to -00:45, which no longer matches exactly.
     *     JiffDateTime dt = JiffDateTime.newInstance(1970, 6, 1, 0, 0, 0, 0);
     *     JiffTimeZone tz = JiffTimeZone.get('Africa/Monrovia');
     *     JiffOffsetConflicts.resolveWith(
     *         JiffOffsetConflict.REJECT, dt, JiffOffset.fromSeconds(-45 * 60), tz, toTheMinute
     *     ).unambiguous().offset();   // -00:44:30
     */
    public static JiffAmbiguousZonedDateTime resolveWith(
        JiffOffsetConflict strategy,
        JiffDateTime dt,
        JiffOffset offset,
        JiffTimeZone tz,
        Equality isEqual
    ) {
        if (strategy == null) {
            throw new JiffException('offset conflict strategy must not be null');
        }
        if (dt == null || offset == null || tz == null) {
            throw new JiffException(
                'resolving an offset conflict needs a datetime, an offset and a time zone'
            );
        }
        switch on strategy {
            when ALWAYS_OFFSET {
                // The time zone only says how to show the instant; the offset chooses it.
                return pinned(dt, offset, tz);
            }
            when ALWAYS_TIME_ZONE {
                return tz.toAmbiguousZonedDateTime(dt);
            }
            when PREFER_OFFSET {
                return viaPrefer(dt, offset, tz, isEqual);
            }
            when else {
                // REJECT
                return viaReject(dt, offset, tz, isEqual);
            }
        }
    }

    /**
     * Uses the given offset when it is one of the two offsets of a fold. Every other case is
     * left to the time zone: an unambiguous datetime has only one possible offset anyway, and
     * all offsets are regarded as invalid in a gap.
     */
    private static JiffAmbiguousZonedDateTime viaPrefer(
        JiffDateTime dt,
        JiffOffset given,
        JiffTimeZone tz,
        Equality isEqual
    ) {
        JiffAmbiguousTimestamp ambiguous = tz.toAmbiguousTimestamp(dt);
        JiffAmbiguousOffset found = ambiguous.offset();
        if (
            found.isFold() &&
            (matches(isEqual, given, found.before()) || matches(isEqual, given, found.after()))
        ) {
            return pinned(dt, given, tz);
        }
        return JiffAmbiguousZonedDateTime.newInstance(ambiguous, tz);
    }

    private static JiffAmbiguousZonedDateTime viaReject(
        JiffDateTime dt,
        JiffOffset given,
        JiffTimeZone tz,
        Equality isEqual
    ) {
        JiffAmbiguousTimestamp ambiguous = tz.toAmbiguousTimestamp(dt);
        JiffAmbiguousOffset found = ambiguous.offset();
        if (found.isUnambiguous()) {
            if (!matches(isEqual, given, found.offset())) {
                throw new JiffException(
                    'datetime could not resolve to a timestamp since `reject` conflict ' +
                        'resolution was chosen, and because datetime has offset `' +
                        given +
                        '`, but the time zone `' +
                        tz +
                        '` for the given datetime unambiguously has offset `' +
                        found.offset() +
                        '`'
                );
            }
            return JiffAmbiguousZonedDateTime.newInstance(ambiguous, tz);
        }
        if (found.isGap()) {
            throw new JiffException(
                rejected(given, tz) +
                    'falls in a gap (between offsets `' +
                    found.before() +
                    '` and `' +
                    found.after() +
                    '`), and all offsets for a gap are regarded as invalid'
            );
        }
        if (!matches(isEqual, given, found.before()) && !matches(isEqual, given, found.after())) {
            throw new JiffException(
                rejected(given, tz) +
                    'falls in a fold between offsets `' +
                    found.before() +
                    '` and `' +
                    found.after() +
                    '`, neither of which match the offset'
            );
        }
        return pinned(dt, given, tz);
    }

    /** The start of the message for an offset rejected in a gap or a fold. */
    private static String rejected(JiffOffset given, JiffTimeZone tz) {
        return 'datetime could not resolve to timestamp since `reject` conflict resolution ' +
            'was chosen, and because datetime has offset `' +
            given +
            '`, but the time zone `' +
            tz +
            '` for the given datetime ';
    }

    private static Boolean matches(Equality isEqual, JiffOffset given, JiffOffset candidate) {
        return isEqual == null ? given.equals(candidate) : isEqual.isEqual(given, candidate);
    }

    /** The civil datetime at exactly `offset`, to be shown in `tz`. */
    private static JiffAmbiguousZonedDateTime pinned(
        JiffDateTime dt,
        JiffOffset offset,
        JiffTimeZone tz
    ) {
        return JiffAmbiguousZonedDateTime.newInstance(
            JiffAmbiguousTimestamp.newInstance(dt, JiffAmbiguousOffset.unambiguous(offset)),
            tz
        );
    }
}
