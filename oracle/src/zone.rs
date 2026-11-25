//! Vectors for `TimeZone`: the offset at an instant, and how a civil datetime
//! maps back to instants, for a fixed list of well known zones from 1970
//! through 2037.
//!
//! The port takes its zone rules from the platform it runs on rather than
//! from Jiff's bundled copy of the time zone database, so these vectors only
//! hold where the two agree. The zones and the period are chosen so that
//! they do: every rule in them has been settled for years.

use anyhow::{ensure, Result};
use jiff::civil::DateTime;
use jiff::tz::{AmbiguousOffset, Offset, TimeZone};
use jiff::{SignedDuration, Timestamp};

use crate::gen;
use crate::rng::Rng;
use crate::text::{self, or_err, row};

pub const TRANSITION_COLUMNS: &str = "zone|instant of a transition, in seconds|\
     offset one second earlier|offset at the instant|\
     a civil datetime at or inside the gap or fold|its offsets|compatible|earlier|later|\
     a civil datetime just outside it|its offsets|compatible|earlier|later  \
     (offsets are seconds; a datetime's offsets are U:offset when unambiguous, \
     G:before:after in a gap, F:before:after in a fold; the three strategies give \
     timestamps as secs,nanos)";

pub const OFFSET_COLUMNS: &str = "zone|instant as secs,nanos|offset in seconds";

pub const CIVIL_COLUMNS: &str = "zone|civil datetime|its offsets (U:offset, G:before:after \
     or F:before:after, in seconds)|compatible|earlier|later  (timestamps as secs,nanos)";

/// Every zone the vectors cover.
pub const ZONES: [&str; 9] = [
    "America/New_York",
    "Europe/London",
    "Europe/Dublin",
    "Australia/Sydney",
    "Asia/Kolkata",
    "America/Sao_Paulo",
    "Pacific/Apia",
    "Asia/Tokyo",
    "UTC",
];

/// 1970-01-01T00:00:00Z and 2038-01-01T00:00:00Z: the period covered.
pub const FIRST_SECOND: i64 = 0;
pub const END_SECOND: i64 = 2_145_916_800;

/// One change of a zone's offset.
pub struct Transition {
    pub second: i64,
    pub before: Offset,
    pub after: Offset,
}

/// The transitions of `zone` within the period at which its offset changes.
/// Transitions that only change the abbreviation or the daylight saving flag
/// are of no interest here: the port cannot see them.
pub fn transitions(zone: &TimeZone) -> Result<Vec<Transition>> {
    let mut found = Vec::new();
    for transition in zone.following(Timestamp::from_second(FIRST_SECOND)?) {
        let second = transition.timestamp().as_second();
        if second >= END_SECOND {
            break;
        }
        ensure!(
            transition.timestamp().subsec_nanosecond() == 0,
            "a transition that is not on a whole second"
        );
        let before = zone.to_offset(Timestamp::from_second(second - 1)?);
        let after = transition.offset();
        ensure!(
            after == zone.to_offset(transition.timestamp()),
            "a transition's offset is the offset at its instant"
        );
        if before != after {
            found.push(Transition {
                second,
                before,
                after,
            });
        }
    }
    Ok(found)
}

fn offsets(offset: AmbiguousOffset) -> String {
    match offset {
        AmbiguousOffset::Unambiguous { offset } => format!("U:{}", offset.seconds()),
        AmbiguousOffset::Gap { before, after } => {
            format!("G:{}:{}", before.seconds(), after.seconds())
        }
        AmbiguousOffset::Fold { before, after } => {
            format!("F:{}:{}", before.seconds(), after.seconds())
        }
    }
}

/// The five fields that describe how `zone` resolves a civil datetime.
fn civil_fields(zone: &TimeZone, datetime: DateTime) -> [String; 5] {
    let ambiguous = zone.to_ambiguous_timestamp(datetime);
    [
        text::datetime(datetime),
        offsets(ambiguous.offset()),
        or_err(ambiguous.compatible(), text::timestamp),
        or_err(ambiguous.earlier(), text::timestamp),
        or_err(ambiguous.later(), text::timestamp),
    ]
}

/// The clock reading at `second` (plus `nanos`) under `offset`.
fn wall_clock(second: i64, nanos: i32, offset: Offset) -> Result<DateTime> {
    Ok(offset.to_datetime(Timestamp::new(second, nanos)?))
}

/// The row for one transition: the offsets either side of it, one civil
/// datetime inside the gap or fold it creates, and one just outside.
///
/// The clock readings that the transition skips or repeats run from `start`
/// (inclusive) to `end` (exclusive). `turn` picks which of several positions
/// is probed, so that a zone's transitions between them cover every one.
fn transition_row(
    name: &str,
    zone: &TimeZone,
    transition: &Transition,
    turn: usize,
) -> Result<String> {
    let Transition {
        second,
        before,
        after,
    } = *transition;
    let (low, high) = if before.seconds() < after.seconds() {
        (before, after)
    } else {
        (after, before)
    };
    let start = wall_clock(second, 0, low)?;
    let end = wall_clock(second, 0, high)?;
    let width = i64::from(high.seconds() - low.seconds());
    let inside = match turn % 5 {
        0 => start,
        1 => start.checked_add(SignedDuration::from_nanos(1))?,
        2 => start.checked_add(SignedDuration::from_secs(width / 2))?,
        3 => end.checked_sub(SignedDuration::from_nanos(1))?,
        _ => end.checked_sub(SignedDuration::from_secs(1))?,
    };
    let outside = match turn % 6 {
        0 => end,
        1 => start.checked_sub(SignedDuration::from_nanos(1))?,
        2 => start.checked_sub(SignedDuration::from_secs(1))?,
        3 => end.checked_add(SignedDuration::from_secs(1))?,
        4 => start.checked_sub(SignedDuration::from_hours(1))?,
        _ => end.checked_add(SignedDuration::from_hours(1))?,
    };
    let mut fields = vec![
        name.to_owned(),
        second.to_string(),
        text::offset(before),
        text::offset(after),
    ];
    fields.extend(civil_fields(zone, inside));
    fields.extend(civil_fields(zone, outside));
    Ok(row(fields))
}

fn transition_rows(names: &[&str]) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    for name in names {
        let zone = TimeZone::get(name)?;
        for (turn, transition) in transitions(&zone)?.iter().enumerate() {
            rows.push(transition_row(name, &zone, transition, turn)?);
        }
    }
    Ok(rows)
}

pub fn americas_rows(_: &mut Rng) -> Result<Vec<String>> {
    transition_rows(&["America/New_York", "America/Sao_Paulo"])
}

pub fn europe_rows(_: &mut Rng) -> Result<Vec<String>> {
    transition_rows(&["Europe/London", "Europe/Dublin"])
}

pub fn pacific_rows(_: &mut Rng) -> Result<Vec<String>> {
    transition_rows(&["Australia/Sydney", "Pacific/Apia"])
}

pub fn offset_rows(rng: &mut Rng) -> Result<Vec<String>> {
    let mut rows = Vec::new();
    for name in ZONES {
        let zone = TimeZone::get(name)?;
        let mut instants = vec![
            Timestamp::from_second(FIRST_SECOND)?,
            Timestamp::new(END_SECOND - 1, 999_999_999)?,
        ];
        while instants.len() < 40 {
            instants.push(Timestamp::new(
                rng.range(FIRST_SECOND, END_SECOND - 1),
                gen::subsec(rng),
            )?);
        }
        for instant in instants {
            rows.push(row([
                name.to_owned(),
                text::timestamp(instant),
                text::offset(zone.to_offset(instant)),
            ]));
        }
    }
    Ok(rows)
}

pub fn civil_rows(rng: &mut Rng) -> Result<Vec<String>> {
    // A few days in from either end of the period, so that no reading
    // denotes an instant outside it whatever the zone's offset.
    let first = FIRST_SECOND + 3 * 86_400;
    let last = END_SECOND - 3 * 86_400;
    let mut rows = Vec::new();
    for name in ZONES {
        let zone = TimeZone::get(name)?;
        let mut readings = vec![
            wall_clock(first, 0, Offset::UTC)?,
            wall_clock(last, 999_999_999, Offset::UTC)?,
        ];
        while readings.len() < 40 {
            readings.push(wall_clock(
                rng.range(first, last),
                gen::subsec(rng),
                Offset::UTC,
            )?);
        }
        for reading in readings {
            let mut fields = vec![name.to_owned()];
            fields.extend(civil_fields(&zone, reading));
            rows.push(row(fields));
        }
    }
    Ok(rows)
}

#[cfg(test)]
mod tests {
    use jiff::civil::date;

    use super::*;

    #[test]
    fn the_period_is_1970_through_2037() -> Result<()> {
        assert_eq!(
            Timestamp::from_second(FIRST_SECOND)?.to_string(),
            "1970-01-01T00:00:00Z"
        );
        assert_eq!(
            Timestamp::from_second(END_SECOND)?.to_string(),
            "2038-01-01T00:00:00Z"
        );
        Ok(())
    }

    #[test]
    fn new_york_changes_its_offset_twice_a_year() -> Result<()> {
        let zone = TimeZone::get("America/New_York")?;
        let found = transitions(&zone)?;
        assert_eq!(found.len(), 136);
        assert!(found.iter().all(|t| t.before != t.after));
        assert!(found.windows(2).all(|pair| pair[0].second < pair[1].second));
        Ok(())
    }

    #[test]
    fn zones_without_daylight_saving_have_no_transitions() -> Result<()> {
        for name in ["Asia/Tokyo", "Asia/Kolkata", "UTC"] {
            assert!(transitions(&TimeZone::get(name)?)?.is_empty(), "{name}");
        }
        Ok(())
    }

    #[test]
    fn civil_fields_describe_gaps_folds_and_ordinary_times() -> Result<()> {
        let zone = TimeZone::get("America/New_York")?;
        assert_eq!(
            civil_fields(&zone, date(2024, 3, 10).at(2, 30, 0, 0)),
            [
                "2024-03-10T02:30:00",
                "G:-18000:-14400",
                "1710055800,0",
                "1710052200,0",
                "1710055800,0"
            ]
        );
        assert_eq!(
            civil_fields(&zone, date(2024, 11, 3).at(1, 30, 0, 0)),
            [
                "2024-11-03T01:30:00",
                "F:-14400:-18000",
                "1730611800,0",
                "1730611800,0",
                "1730615400,0"
            ]
        );
        assert_eq!(
            civil_fields(&zone, date(2024, 7, 1).at(12, 0, 0, 0)),
            [
                "2024-07-01T12:00:00",
                "U:-14400",
                "1719849600,0",
                "1719849600,0",
                "1719849600,0"
            ]
        );
        Ok(())
    }

    #[test]
    fn a_transition_row_probes_inside_and_outside_the_gap() -> Result<()> {
        let zone = TimeZone::get("America/New_York")?;
        let spring_2024 = Transition {
            second: 1_710_054_000,
            before: Offset::from_hours(-5)?,
            after: Offset::from_hours(-4)?,
        };
        assert_eq!(
            transition_row("America/New_York", &zone, &spring_2024, 0)?,
            "America/New_York|1710054000|-18000|-14400|\
             2024-03-10T02:00:00|G:-18000:-14400|1710054000,0|1710050400,0|1710054000,0|\
             2024-03-10T03:00:00|U:-14400|1710054000,0|1710054000,0|1710054000,0"
        );
        Ok(())
    }
}
