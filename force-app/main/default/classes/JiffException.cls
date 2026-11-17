/**
 * The single exception type thrown by jiff-force.
 *
 * Jiff reports every failure through one `jiff::Error` type, and so does this port: out of range
 * values, overflow, unparseable input, ambiguous civil times that were asked to be rejected, and
 * invalid rounding configuration all surface as a `JiffException` with a descriptive message.
 *
 * Where Jiff offers both a panicking and a fallible variant of an operation (`Date::new` versus
 * `Date::constant`, `checked_add` versus `+`), the port offers only the checked behaviour: the
 * method throws `JiffException` instead of returning a `Result`.
 */
public class JiffException extends Exception {
}
