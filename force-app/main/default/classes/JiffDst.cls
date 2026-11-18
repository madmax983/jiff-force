/**
 * Whether daylight saving time is in effect: `YES` during daylight saving ("summer") time and
 * `NO` during standard time.
 *
 * Returned by `JiffTimeZoneOffsetInfo.dst()` and `JiffTimeZoneTransition.dst()`. For a zone
 * backed by the platform the flag is inferred from the zone's offsets, because the platform
 * does not expose it; see `JiffTimeZone` for exactly how, and for where the inference can
 * differ from the time zone database.
 *
 * Jiff's `is_dst()` and `is_std()` are comparisons with `YES` and `NO` here, because Apex enums
 * cannot declare methods.
 *
 * Mirrors `jiff::tz::Dst`.
 */
public enum JiffDst {
    NO,
    YES
}
