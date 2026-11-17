//! Configurations of Jiff's friendly duration printer, and the text mangling
//! used to turn printed durations into parser inputs. Shared by the span and
//! signed duration topics.

use jiff::fmt::friendly::{Designator, Direction, FractionalUnit, Spacing, SpanPrinter};
use jiff::Unit;

use crate::rng::Rng;
use crate::text::UNITS;

const DESIGNATORS: [(Designator, &str); 4] = [
    (Designator::Compact, "COMPACT"),
    (Designator::Verbose, "VERBOSE"),
    (Designator::Short, "SHORT_FORM"),
    (Designator::HumanTime, "HUMAN_TIME"),
];

const SPACINGS: [(Spacing, &str); 3] = [
    (Spacing::BetweenUnits, "BETWEEN_UNITS"),
    (Spacing::None, "NONE"),
    (
        Spacing::BetweenUnitsAndDesignators,
        "BETWEEN_UNITS_AND_DESIGNATORS",
    ),
];

const DIRECTIONS: [(Direction, &str); 4] = [
    (Direction::Auto, "AUTO"),
    (Direction::Sign, "SIGN"),
    (Direction::ForceSign, "FORCE_SIGN"),
    (Direction::Suffix, "SUFFIX"),
];

const FRACTIONAL_UNITS: [(FractionalUnit, &str); 5] = [
    (FractionalUnit::Hour, "HOUR"),
    (FractionalUnit::Minute, "MINUTE"),
    (FractionalUnit::Second, "SECOND"),
    (FractionalUnit::Millisecond, "MILLISECOND"),
    (FractionalUnit::Microsecond, "MICROSECOND"),
];

/// One configuration of the friendly printer. Each field is an index into
/// the table of its setting, where index 0 is the printer's default, or
/// `None` for a setting left alone.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct Config {
    pub designator: usize,
    pub spacing: usize,
    pub direction: usize,
    pub fractional: Option<usize>,
    pub comma: bool,
    pub hms: bool,
    pub padding: Option<u8>,
    pub precision: Option<u8>,
    /// An index into [`UNITS`].
    pub zero_unit: Option<usize>,
}

impl Config {
    /// The Jiff printer this configuration describes.
    pub fn printer(&self) -> SpanPrinter {
        let mut printer = SpanPrinter::new()
            .designator(DESIGNATORS[self.designator].0)
            .spacing(SPACINGS[self.spacing].0)
            .direction(DIRECTIONS[self.direction].0)
            .fractional(self.fractional.map(|index| FRACTIONAL_UNITS[index].0))
            .comma_after_designator(self.comma)
            .hours_minutes_seconds(self.hms)
            .precision(self.precision);
        if let Some(digits) = self.padding {
            printer = printer.padding(digits);
        }
        if let Some(index) = self.zero_unit {
            let unit: Unit = UNITS[index].0;
            printer = printer.zero_unit(unit);
        }
        printer
    }

    /// The configuration as a vector field: the settings that differ from
    /// the default as `name=value` pairs separated by `;`, or `default`.
    pub fn name(&self) -> String {
        let mut settings = Vec::new();
        if self.designator != 0 {
            settings.push(format!("designator={}", DESIGNATORS[self.designator].1));
        }
        if self.spacing != 0 {
            settings.push(format!("spacing={}", SPACINGS[self.spacing].1));
        }
        if self.direction != 0 {
            settings.push(format!("direction={}", DIRECTIONS[self.direction].1));
        }
        if let Some(index) = self.fractional {
            settings.push(format!("fractional={}", FRACTIONAL_UNITS[index].1));
        }
        if self.comma {
            settings.push("comma=1".to_owned());
        }
        if self.hms {
            settings.push("hms=1".to_owned());
        }
        if let Some(digits) = self.padding {
            settings.push(format!("padding={digits}"));
        }
        if let Some(digits) = self.precision {
            settings.push(format!("precision={digits}"));
        }
        if let Some(index) = self.zero_unit {
            settings.push(format!("zero={}", UNITS[index].1));
        }
        if settings.is_empty() {
            "default".to_owned()
        } else {
            settings.join(";")
        }
    }
}

/// Every configuration that changes exactly one setting from the default,
/// preceded by the default itself.
pub fn single_setting_configs() -> Vec<Config> {
    let base = Config::default();
    let mut configs = vec![base];
    configs.extend((1..DESIGNATORS.len()).map(|designator| Config { designator, ..base }));
    configs.extend((1..SPACINGS.len()).map(|spacing| Config { spacing, ..base }));
    configs.extend((1..DIRECTIONS.len()).map(|direction| Config { direction, ..base }));
    configs.extend((0..FRACTIONAL_UNITS.len()).map(|index| Config {
        fractional: Some(index),
        ..base
    }));
    configs.push(Config {
        comma: true,
        ..base
    });
    configs.push(Config { hms: true, ..base });
    configs.extend([0, 1, 3, 25].map(|digits| Config {
        padding: Some(digits),
        ..base
    }));
    // Precision only shows when something is fractional.
    configs.extend([0, 1, 3, 9, 12].map(|digits| Config {
        precision: Some(digits),
        fractional: Some(2),
        ..base
    }));
    configs.extend((0..UNITS.len()).map(|index| Config {
        zero_unit: Some(index),
        ..base
    }));
    configs
}

/// A configuration with each setting independently left at its default or
/// set to a random value.
pub fn arbitrary_config(rng: &mut Rng) -> Config {
    let index = |rng: &mut Rng, len: usize| {
        let last = i64::try_from(len).unwrap_or(1) - 1;
        usize::try_from(rng.range(0, last)).unwrap_or(0)
    };
    let mut config = Config::default();
    if rng.range(0, 1) == 0 {
        config.designator = index(rng, DESIGNATORS.len());
    }
    if rng.range(0, 1) == 0 {
        config.spacing = index(rng, SPACINGS.len());
    }
    if rng.range(0, 1) == 0 {
        config.direction = index(rng, DIRECTIONS.len());
    }
    if rng.range(0, 2) == 0 {
        config.fractional = Some(index(rng, FRACTIONAL_UNITS.len()));
    }
    config.comma = rng.range(0, 3) == 0;
    config.hms = rng.range(0, 3) == 0;
    if rng.range(0, 3) == 0 {
        config.padding = u8::try_from(rng.range(0, 4)).ok();
    }
    if rng.range(0, 2) == 0 {
        config.precision = u8::try_from(rng.range(0, 10)).ok();
    }
    if rng.range(0, 3) == 0 {
        config.zero_unit = Some(index(rng, UNITS.len()));
    }
    config
}

/// Damages `text` in one small way: a character dropped, doubled, swapped
/// for one from `alphabet` or inserted from it, or the text cut short. Most
/// results are no longer valid, and some are valid but mean something else,
/// which is what makes them good parser inputs.
pub fn mangle(rng: &mut Rng, text: &str, alphabet: &str) -> String {
    let mut chars: Vec<char> = text.chars().collect();
    let letters: Vec<char> = alphabet.chars().collect();
    if chars.is_empty() || letters.is_empty() {
        return text.to_owned();
    }
    let last = i64::try_from(chars.len()).unwrap_or(1) - 1;
    let at = usize::try_from(rng.range(0, last)).unwrap_or(0);
    let letter = *rng.pick(&letters);
    match rng.range(0, 4) {
        0 => {
            chars.remove(at);
        }
        1 => chars.insert(at, chars[at]),
        2 => chars[at] = letter,
        3 => chars.insert(at, letter),
        _ => chars.truncate(at.max(1)),
    }
    chars.into_iter().collect()
}

#[cfg(test)]
mod tests {
    use jiff::ToSpan;

    use super::*;

    #[test]
    fn the_default_configuration_is_the_default_printer() {
        let config = Config::default();
        assert_eq!(config.name(), "default");
        let span = 1.year().months(2).hours(3);
        assert_eq!(config.printer().span_to_string(&span), format!("{span:#}"));
        assert_eq!(config.printer().span_to_string(&0.seconds()), "0s");
    }

    #[test]
    fn a_configuration_names_every_setting_it_changes() {
        let config = Config {
            designator: 1,
            spacing: 1,
            direction: 2,
            fractional: Some(0),
            comma: true,
            hms: true,
            padding: Some(2),
            precision: Some(3),
            zero_unit: Some(4),
        };
        assert_eq!(
            config.name(),
            "designator=VERBOSE;spacing=NONE;direction=FORCE_SIGN;fractional=HOUR;comma=1;\
             hms=1;padding=2;precision=3;zero=MINUTE"
        );
    }

    #[test]
    fn settings_reach_the_printer() {
        let verbose = Config {
            designator: 1,
            comma: true,
            ..Config::default()
        };
        assert_eq!(
            verbose.printer().span_to_string(&1.year().months(2)),
            "1year, 2months"
        );
        let clock = Config {
            hms: true,
            ..Config::default()
        };
        assert_eq!(clock.printer().span_to_string(&1.hour()), "01:00:00");
        let zero = Config {
            zero_unit: Some(5),
            ..Config::default()
        };
        assert_eq!(zero.printer().span_to_string(&0.seconds()), "0h");
    }

    #[test]
    fn single_setting_configs_are_distinct_and_start_with_the_default() {
        let configs = single_setting_configs();
        assert_eq!(configs[0], Config::default());
        let mut names: Vec<String> = configs.iter().map(Config::name).collect();
        let total = names.len();
        names.sort();
        names.dedup();
        assert_eq!(names.len(), total);
    }

    #[test]
    fn mangling_changes_the_length_by_at_most_one_or_truncates() {
        let mut rng = Rng::new(21);
        for _ in 0..500 {
            let mangled = mangle(&mut rng, "P1Y2M3DT4H5M6S", "PT1.");
            assert!(!mangled.is_empty());
            assert!(mangled.chars().count() <= 15);
        }
        assert_eq!(mangle(&mut rng, "", "abc"), "");
        assert_eq!(mangle(&mut rng, "abc", ""), "abc");
    }
}
