/**
 * How a value that falls between two multiples of the rounding increment is resolved.
 *
 * - `CEIL` rounds toward positive infinity, `FLOOR` toward negative infinity.
 * - `EXPAND` rounds away from zero, `TRUNC` toward zero.
 * - The `HALF_*` modes round to the nearest multiple, and use the named rule only to break an
 *   exact tie. `HALF_EXPAND` is what most people mean by "rounding"; `HALF_EVEN` is banker's
 *   rounding.
 *
 * Mirrors `jiff::RoundMode`.
 */
public enum JiffRoundMode {
    CEIL,
    FLOOR,
    EXPAND,
    TRUNC,
    HALF_CEIL,
    HALF_FLOOR,
    HALF_EXPAND,
    HALF_TRUNC,
    HALF_EVEN
}
