//! Replays the vector tables that live inside hand written Apex tests against
//! the real Jiff crate.
//!
//! `JiffDateTimeArithmeticTest` and `JiffDateTimeRoundTest` carry their
//! vectors inline, as lists of pipe separated rows, instead of reading them
//! from a generated `JiffOracle*Data` class. This module is what keeps those
//! rows honest: it reads them back out of the Apex source, recomputes every
//! expected value with Jiff and reports each one that differs, together with
//! what Jiff produces, so a row can be corrected or a new one filled in.
//!
//! Nothing about the tables is repeated here. The rows, and the abbreviations
//! they use for Jiff's error messages (`ERROR_TEXT`), are both read from the
//! test class, so what is compared with Jiff is exactly the text the Apex
//! test compares with the port.
//!
//! Usage: `npm run oracle:check`.

use std::collections::HashMap;
use std::fmt::Display;
use std::fs;
use std::path::Path;
use std::str::FromStr;

use anyhow::{anyhow, bail, ensure, Context, Result};
use jiff::civil::{DateTime, DateTimeRound};
use jiff::{RoundMode, SignedDuration, Span, Unit};

/// The position of a unit in a row, which is also its position in `JiffUnit`.
const UNITS: [Unit; 10] = [
    Unit::Nanosecond,
    Unit::Microsecond,
    Unit::Millisecond,
    Unit::Second,
    Unit::Minute,
    Unit::Hour,
    Unit::Day,
    Unit::Week,
    Unit::Month,
    Unit::Year,
];

/// The position of a rounding mode in a row, which is also its position in
/// `JiffRoundMode`.
const MODES: [RoundMode; 9] = [
    RoundMode::Ceil,
    RoundMode::Floor,
    RoundMode::Expand,
    RoundMode::Trunc,
    RoundMode::HalfCeil,
    RoundMode::HalfFloor,
    RoundMode::HalfExpand,
    RoundMode::HalfTrunc,
    RoundMode::HalfEven,
];

/// Checks every inline vector table and fails if any value differs from Jiff.
pub fn check(classes_dir: &Path) -> Result<()> {
    let mut report = Report::default();

    let arithmetic = TestClass::read(classes_dir, "JiffDateTimeArithmeticTest")?;
    arithmetic.replay("addAndSubtractSpansMatchJiff", &mut report, span_row)?;
    arithmetic.replay(
        "addAndSubtractDurationsMatchJiff",
        &mut report,
        duration_row,
    )?;
    arithmetic.replay("untilAndDurationUntilMatchJiff", &mut report, until_row)?;

    let rounding = TestClass::read(classes_dir, "JiffDateTimeRoundTest")?;
    rounding.replay("roundMatchesJiff", &mut report, round_row)?;

    println!(
        "checked {} values, {} mismatches",
        report.checked,
        report.mismatches.len()
    );
    for mismatch in &report.mismatches {
        println!("{mismatch}");
    }
    ensure!(
        report.mismatches.is_empty(),
        "{} expected values differ from jiff {}",
        report.mismatches.len(),
        crate::emit::jiff_version()
    );
    Ok(())
}

/// What has been compared so far, and what did not match.
#[derive(Default)]
struct Report {
    checked: usize,
    mismatches: Vec<String>,
}

impl Report {
    fn expect(&mut self, what: &str, row: &str, expected: &str, actual: &str) {
        self.checked += 1;
        if expected != actual {
            self.mismatches.push(format!(
                "MISMATCH in {what} of {row}\n  the test expects: {expected}\n  jiff gives:       {actual}"
            ));
        }
    }
}

// ---- one function per table --------------------------------------------

/// `start | span | checked_add | checked_sub | saturating_add | saturating_sub`
fn span_row(class: &TestClass, row: &str, report: &mut Report) -> Result<()> {
    let f = columns(row, 6)?;
    let (start, span) = (civil(f[0])?, span(f[1])?);
    let added = shown(start.checked_add(span));
    let subtracted = shown(start.checked_sub(span));
    report.expect("checked_add", row, &class.expand(f[2])?, &added);
    report.expect("checked_sub", row, &class.expand(f[3])?, &subtracted);
    report.expect(
        "saturating_add",
        row,
        &saturated(f[4], &added)?,
        &start.saturating_add(span).to_string(),
    );
    report.expect(
        "saturating_sub",
        row,
        &saturated(f[5], &subtracted)?,
        &start.saturating_sub(span).to_string(),
    );
    Ok(())
}

/// `start | seconds,nanoseconds | checked_add | checked_sub | saturating_add | saturating_sub`
fn duration_row(class: &TestClass, row: &str, report: &mut Report) -> Result<()> {
    let f = columns(row, 6)?;
    let (start, duration) = (civil(f[0])?, duration(f[1])?);
    let added = shown(start.checked_add(duration));
    let subtracted = shown(start.checked_sub(duration));
    report.expect("checked_add", row, &class.expand(f[2])?, &added);
    report.expect("checked_sub", row, &class.expand(f[3])?, &subtracted);
    report.expect(
        "saturating_add",
        row,
        &saturated(f[4], &added)?,
        &start.saturating_add(duration).to_string(),
    );
    report.expect(
        "saturating_sub",
        row,
        &saturated(f[5], &subtracted)?,
        &start.saturating_sub(duration).to_string(),
    );
    Ok(())
}

/// `dt1 | dt2 | dt1.duration_until(dt2) | largest unit | dt1.until((unit, dt2))`
///
/// The Apex test also asserts, for every row whose span exists, that `since`
/// returns the negated span and that adding the span to `dt1` gives `dt2`.
/// Those are facts about Jiff too, so they are checked here as well.
fn until_row(class: &TestClass, row: &str, report: &mut Report) -> Result<()> {
    let f = columns(row, 5)?;
    let (dt1, dt2) = (civil(f[0])?, civil(f[1])?);
    report.expect(
        "duration_until",
        row,
        f[2],
        &duration_fields(dt1.duration_until(dt2)),
    );
    report.expect(
        "duration_since",
        row,
        f[2],
        &duration_fields(dt2.duration_since(dt1)),
    );
    let largest = *pick(&UNITS, f[3])?;
    let until = dt1.until((largest, dt2));
    let actual = match &until {
        Ok(span) => span_fields(span),
        Err(error) => format!("ERR:{error}"),
    };
    report.expect("until", row, &class.expand(f[4])?, &actual);
    if let Ok(span) = until {
        let since = dt1.since((largest, dt2)).map(|s| span_fields(&s));
        report.expect(
            "since",
            row,
            &span_fields(&span.negate()),
            &since.unwrap_or_else(|error| format!("ERR:{error}")),
        );
        report.expect(
            "adding the span back",
            row,
            &dt2.to_string(),
            &shown(dt1.checked_add(span)),
        );
    }
    Ok(())
}

/// `datetime | smallest unit | increment | mode | datetime.round(...)`
fn round_row(class: &TestClass, row: &str, report: &mut Report) -> Result<()> {
    let f = columns(row, 5)?;
    let options = DateTimeRound::new()
        .smallest(*pick(&UNITS, f[1])?)
        .increment(number(f[2])?)
        .mode(*pick(&MODES, f[3])?);
    report.expect(
        "round",
        row,
        &class.expand(f[4])?,
        &shown(civil(f[0])?.round(options)),
    );
    Ok(())
}

// ---- the notation of the rows ------------------------------------------

fn columns(row: &str, count: usize) -> Result<Vec<&str>> {
    let columns: Vec<&str> = row.split('|').collect();
    ensure!(
        columns.len() == count,
        "expected {count} columns in the row {row}"
    );
    Ok(columns)
}

fn number<T>(text: &str) -> Result<T>
where
    T: FromStr,
    T::Err: Display,
{
    text.parse()
        .map_err(|error| anyhow!("cannot read the number {text}: {error}"))
}

/// Splits `a,b,c` into exactly `count` parts.
fn parts(text: &str, count: usize) -> Result<Vec<&str>> {
    let parts: Vec<&str> = text.split(',').collect();
    ensure!(parts.len() == count, "expected {count} numbers in {text}");
    Ok(parts)
}

fn pick<'a, T>(items: &'a [T], index: &str) -> Result<&'a T> {
    items
        .get(number::<usize>(index)?)
        .with_context(|| format!("no item at position {index}"))
}

/// `year,month,day,hour,minute,second,nanosecond`
fn civil(text: &str) -> Result<DateTime> {
    let p = parts(text, 7)?;
    Ok(DateTime::new(
        number(p[0])?,
        number(p[1])?,
        number(p[2])?,
        number(p[3])?,
        number(p[4])?,
        number(p[5])?,
        number(p[6])?,
    )?)
}

/// The ten units of a span, from years down to nanoseconds.
fn span(text: &str) -> Result<Span> {
    let p = parts(text, 10)?;
    Ok(Span::new()
        .try_years(number::<i64>(p[0])?)?
        .try_months(number::<i64>(p[1])?)?
        .try_weeks(number::<i64>(p[2])?)?
        .try_days(number::<i64>(p[3])?)?
        .try_hours(number::<i64>(p[4])?)?
        .try_minutes(number::<i64>(p[5])?)?
        .try_seconds(number::<i64>(p[6])?)?
        .try_milliseconds(number::<i64>(p[7])?)?
        .try_microseconds(number::<i64>(p[8])?)?
        .try_nanoseconds(number::<i64>(p[9])?)?)
}

fn span_fields(span: &Span) -> String {
    format!(
        "{},{},{},{},{},{},{},{},{},{}",
        span.get_years(),
        span.get_months(),
        span.get_weeks(),
        span.get_days(),
        span.get_hours(),
        span.get_minutes(),
        span.get_seconds(),
        span.get_milliseconds(),
        span.get_microseconds(),
        span.get_nanoseconds()
    )
}

/// `seconds,nanoseconds`
fn duration(text: &str) -> Result<SignedDuration> {
    let p = parts(text, 2)?;
    Ok(SignedDuration::new(number(p[0])?, number(p[1])?))
}

fn duration_fields(duration: SignedDuration) -> String {
    format!("{},{}", duration.as_secs(), duration.subsec_nanos())
}

/// A result the way the rows write it: the datetime as Jiff prints it, or
/// `ERR:` and the whole error message.
fn shown(result: Result<DateTime, jiff::Error>) -> String {
    match result {
        Ok(datetime) => datetime.to_string(),
        Err(error) => format!("ERR:{error}"),
    }
}

/// A saturating column: `=` for the checked result, or the limit reached.
fn saturated(column: &str, checked: &str) -> Result<String> {
    match column {
        "=" => Ok(checked.to_owned()),
        "MIN" => Ok(DateTime::MIN.to_string()),
        "MAX" => Ok(DateTime::MAX.to_string()),
        other => bail!("unknown saturating column {other}"),
    }
}

// ---- reading the Apex test classes -------------------------------------

/// The pieces of Apex source this module cares about.
#[derive(Debug, Clone, PartialEq, Eq)]
enum Token {
    /// A string literal, unescaped.
    Text(String),
    /// An identifier, keyword or number.
    Word(String),
    Punct(char),
}

/// An Apex test class, read far enough to find its vector tables.
struct TestClass {
    name: String,
    tokens: Vec<Token>,
    /// The `ERROR_TEXT` map: abbreviation to the piece of a Jiff message.
    error_text: HashMap<String, String>,
}

impl TestClass {
    fn read(classes_dir: &Path, name: &str) -> Result<Self> {
        let path = classes_dir.join(format!("{name}.cls"));
        let source =
            fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
        Self::parse(name, &source)
    }

    fn parse(name: &str, source: &str) -> Result<Self> {
        let tokens = lex(source).with_context(|| format!("reading {name}"))?;
        let error_text = error_text(&tokens, &constants(&tokens))
            .with_context(|| format!("reading ERROR_TEXT of {name}"))?;
        Ok(Self {
            name: name.to_owned(),
            tokens,
            error_text,
        })
    }

    /// Runs `check` over every row of the table in the test method `method`.
    fn replay(
        &self,
        method: &str,
        report: &mut Report,
        check: fn(&Self, &str, &mut Report) -> Result<()>,
    ) -> Result<()> {
        let rows = self.rows(method)?;
        println!("{}.{method}: {} rows", self.name, rows.len());
        for row in &rows {
            check(self, row, report).with_context(|| format!("{}.{method}", self.name))?;
        }
        Ok(())
    }

    /// The strings of `List<String> rows = new List<String>{ ... }` in `method`.
    fn rows(&self, method: &str) -> Result<Vec<String>> {
        let missing = || anyhow!("{} has no vector table in {method}", self.name);
        let header = [word("void"), word(method), Token::Punct('(')];
        let body = find(&self.tokens, 0, &header).ok_or_else(missing)?;
        let opening = [
            word("rows"),
            Token::Punct('='),
            word("new"),
            word("List"),
            Token::Punct('<'),
            word("String"),
            Token::Punct('>'),
            Token::Punct('{'),
        ];
        let mut at = find(&self.tokens, body, &opening).ok_or_else(missing)?;
        let mut rows = Vec::new();
        loop {
            match (self.tokens.get(at), self.tokens.get(at + 1)) {
                (Some(Token::Text(row)), Some(Token::Punct(','))) => {
                    rows.push(row.clone());
                    at += 2;
                }
                (Some(Token::Text(row)), Some(Token::Punct('}'))) => {
                    rows.push(row.clone());
                    break;
                }
                _ => bail!(
                    "the table in {}.{method} is not a plain list of strings",
                    self.name
                ),
            }
        }
        Ok(rows)
    }

    /// Writes out an expected value in full: `ERR:O:year` becomes `ERR:`
    /// followed by the two pieces of the message joined the way Jiff joins an
    /// error and its cause. Anything else is already the value itself.
    fn expand(&self, expected: &str) -> Result<String> {
        let Some(codes) = expected.strip_prefix("ERR:") else {
            return Ok(expected.to_owned());
        };
        let mut texts = Vec::new();
        for code in codes.split(':') {
            let text = self
                .error_text
                .get(code)
                .with_context(|| format!("{} has no ERROR_TEXT for '{code}'", self.name))?;
            texts.push(text.as_str());
        }
        Ok(format!("ERR:{}", texts.join(": ")))
    }
}

fn word(text: &str) -> Token {
    Token::Word(text.to_owned())
}

/// The position just after the first occurrence of `pattern` at or after
/// `start`.
fn find(tokens: &[Token], start: usize, pattern: &[Token]) -> Option<usize> {
    let tail = tokens.get(start..)?;
    tail.windows(pattern.len())
        .position(|window| window == pattern)
        .map(|offset| start + offset + pattern.len())
}

/// Splits Apex source into tokens, dropping comments and white space.
fn lex(source: &str) -> Result<Vec<Token>> {
    let mut tokens = Vec::new();
    let mut chars = source.chars().peekable();
    while let Some(c) = chars.next() {
        if c.is_whitespace() {
            continue;
        }
        if c == '/' && chars.peek() == Some(&'/') {
            for skipped in chars.by_ref() {
                if skipped == '\n' {
                    break;
                }
            }
        } else if c == '/' && chars.peek() == Some(&'*') {
            chars.next();
            let mut previous = ' ';
            for skipped in chars.by_ref() {
                if previous == '*' && skipped == '/' {
                    break;
                }
                previous = skipped;
            }
        } else if c == '\'' {
            let mut text = String::new();
            loop {
                match chars.next() {
                    Some('\'') => break,
                    Some('\\') => match chars.next() {
                        Some(escaped @ ('\'' | '\\')) => text.push(escaped),
                        other => bail!("unsupported escape {other:?} in a string literal"),
                    },
                    Some(plain) => text.push(plain),
                    None => bail!("a string literal does not end"),
                }
            }
            tokens.push(Token::Text(text));
        } else if c.is_alphanumeric() || c == '_' {
            let mut text = String::from(c);
            while let Some(&next) = chars.peek() {
                if !(next.is_alphanumeric() || next == '_') {
                    break;
                }
                text.push(next);
                chars.next();
            }
            tokens.push(Token::Word(text));
        } else {
            tokens.push(Token::Punct(c));
        }
    }
    Ok(tokens)
}

/// Reads `'a' + NAME + 'b'` starting at `at`: string literals and names from
/// `known`, joined with `+`. Returns the text and the position after it, or
/// `None` if this is some other kind of expression.
fn text_expression(
    tokens: &[Token],
    mut at: usize,
    known: &HashMap<String, String>,
) -> Option<(String, usize)> {
    let mut text = String::new();
    loop {
        match tokens.get(at)? {
            Token::Text(literal) => text.push_str(literal),
            Token::Word(name) => text.push_str(known.get(name)?),
            Token::Punct(_) => return None,
        }
        at += 1;
        if tokens.get(at) != Some(&Token::Punct('+')) {
            return Some((text, at));
        }
        at += 1;
    }
}

/// Every `final String NAME = <text expression>;` in the class.
fn constants(tokens: &[Token]) -> HashMap<String, String> {
    let mut known = HashMap::new();
    let declaration = [word("final"), word("String")];
    let mut at = 0;
    while let Some(after) = find(tokens, at, &declaration) {
        at = after;
        let (Some(Token::Word(name)), Some(Token::Punct('='))) =
            (tokens.get(after), tokens.get(after + 1))
        else {
            continue;
        };
        if let Some((text, end)) = text_expression(tokens, after + 2, &known) {
            if tokens.get(end) == Some(&Token::Punct(';')) {
                known.insert(name.clone(), text);
            }
        }
    }
    known
}

/// The entries of `ERROR_TEXT = new Map<String, String>{ 'code' => text, ... }`.
fn error_text(
    tokens: &[Token],
    constants: &HashMap<String, String>,
) -> Result<HashMap<String, String>> {
    let opening = [
        word("ERROR_TEXT"),
        Token::Punct('='),
        word("new"),
        word("Map"),
        Token::Punct('<'),
        word("String"),
        Token::Punct(','),
        word("String"),
        Token::Punct('>'),
        Token::Punct('{'),
    ];
    let mut at = find(tokens, 0, &opening).context("the class has no ERROR_TEXT map")?;
    let mut entries = HashMap::new();
    loop {
        let (Some(Token::Text(code)), Some(Token::Punct('=')), Some(Token::Punct('>'))) =
            (tokens.get(at), tokens.get(at + 1), tokens.get(at + 2))
        else {
            bail!("expected an entry of the form 'code' => text");
        };
        let (text, end) = text_expression(tokens, at + 3, constants)
            .with_context(|| format!("cannot read the text for '{code}'"))?;
        entries.insert(code.clone(), text);
        match tokens.get(end) {
            Some(Token::Punct(',')) => at = end + 1,
            Some(Token::Punct('}')) => return Ok(entries),
            _ => bail!("the entry for '{code}' does not end with a comma or a brace"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CLASS: &str = r"
        @IsTest
        private class DemoTest {
            private static final String YEAR_RANGE = 'parameter \'year\' is out of range';

            // Jiff's own words, which a careless reader would take for a string's start.
            private static final Map<String, String> ERROR_TEXT = new Map<String, String>{
                'D' => 'failed to add span to date',
                'year' => YEAR_RANGE,
                'long' => 'a text that ' +
                'spans two lines'
            };

            @IsTest
            static void otherTable() {
                List<String> rows = new List<String>{ 'not|this' };
            }

            @IsTest
            static void addMatchesJiff() {
                /* start | span | sum */
                List<String> rows = new List<String>{
                    '2024,2,29,0,0,0,0|0,0,0,1,0,0,0,0,0,0|2024-03-01T00:00:00',
                    '9999,12,31,0,0,0,0|0,0,0,1,0,0,0,0,0,0|ERR:D:year'
                };
                Assert.isTrue(rows.size() >= 2, 'expected the full vector set');
            }
        }
    ";

    #[test]
    fn finds_the_rows_of_the_named_method_only() -> Result<()> {
        let class = TestClass::parse("DemoTest", CLASS)?;
        assert_eq!(
            class.rows("addMatchesJiff")?,
            [
                "2024,2,29,0,0,0,0|0,0,0,1,0,0,0,0,0,0|2024-03-01T00:00:00",
                "9999,12,31,0,0,0,0|0,0,0,1,0,0,0,0,0,0|ERR:D:year",
            ]
        );
        assert_eq!(class.rows("otherTable")?, ["not|this"]);
        assert!(class.rows("noSuchMethod").is_err());
        Ok(())
    }

    #[test]
    fn expands_error_abbreviations_with_the_text_from_the_class() -> Result<()> {
        let class = TestClass::parse("DemoTest", CLASS)?;
        assert_eq!(
            class.expand("ERR:D:year")?,
            "ERR:failed to add span to date: parameter 'year' is out of range"
        );
        assert_eq!(class.expand("ERR:long")?, "ERR:a text that spans two lines");
        assert_eq!(class.expand("2024-03-01T00:00:00")?, "2024-03-01T00:00:00");
        assert!(class.expand("ERR:unheard-of").is_err());
        Ok(())
    }

    #[test]
    fn reports_a_value_that_differs_from_jiff() -> Result<()> {
        let class = TestClass::parse("DemoTest", CLASS)?;
        let mut report = Report::default();
        let right =
            "2024,2,29,0,0,0,0|0,0,0,1,0,0,0,0,0,0|2024-03-01T00:00:00|2024-02-28T00:00:00|=|=";
        span_row(&class, right, &mut report)?;
        assert_eq!((report.checked, report.mismatches.len()), (4, 0));
        let wrong =
            "2024,2,29,0,0,0,0|0,0,0,1,0,0,0,0,0,0|2024-03-02T00:00:00|2024-02-28T00:00:00|=|MIN";
        span_row(&class, wrong, &mut report)?;
        assert_eq!((report.checked, report.mismatches.len()), (8, 2));
        assert!(report.mismatches[0].contains("jiff gives:       2024-03-01T00:00:00"));
        Ok(())
    }
}
