/**
 * What to do when a datetime carries both a UTC offset and a time zone and the two disagree,
 * as in `2024-06-14T17:30-05[America/New_York]` (New York is at `-04` on that date).
 *
 * - `ALWAYS_OFFSET` trusts the offset: the instant is the civil time at that offset, and the
 *   civil time is then recomputed in the time zone.
 * - `ALWAYS_TIME_ZONE` trusts the time zone and ignores the offset.
 * - `PREFER_OFFSET` uses the offset when it is one the time zone really has for that civil
 *   time, and otherwise falls back to the time zone.
 * - `REJECT` throws `JiffException` unless the offset is one the time zone really has for that
 *   civil time. This is Jiff's default.
 *
 * The strategy is applied when a zoned datetime is built from a civil datetime, an offset and a
 * time zone (Jiff's `OffsetConflict::resolve`), which is part of `JiffZonedDateTime`. Apex enums
 * cannot declare methods, so this type only names the strategies.
 *
 * Mirrors `jiff::tz::OffsetConflict`.
 */
public enum JiffOffsetConflict {
    ALWAYS_OFFSET,
    ALWAYS_TIME_ZONE,
    PREFER_OFFSET,
    REJECT
}
