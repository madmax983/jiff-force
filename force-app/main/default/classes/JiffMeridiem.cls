/**
 * A label to tell the hours of a 12-hour clock apart: `AM` ("ante meridiem", before midday)
 * for hours below 12 on a 24-hour clock and `PM` ("post meridiem", after midday) for the rest.
 *
 * `JiffBrokenDownTime.meridiem()` returns it, and `strptime` sets it when it parses `%p` or
 * `%P`.
 *
 * Mirrors `jiff::fmt::strtime::Meridiem`.
 */
public enum JiffMeridiem {
    AM,
    PM
}
