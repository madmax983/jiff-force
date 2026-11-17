//! Generates golden test vectors for jiff-force by running the real Jiff
//! crate, pinned to the release the port tracks.
//!
//! The output is a set of Apex data classes (`JiffOracle*Data.cls`). Hand
//! written Apex tests (`JiffOracle*Test.cls`) replay every row against the
//! port, which makes the Rust implementation the oracle for the Apex one.
//!
//! Usage: `cargo run --manifest-path oracle/Cargo.toml` from the repository
//! root, or `npm run oracle`, which also formats the result.
//!
//! Some hand written tests carry their vectors inline instead. With `--check`
//! (`npm run oracle:check`) nothing is generated; those rows are replayed
//! against Jiff and every expected value that differs is reported.

mod civil;
mod duration;
mod emit;
mod replay;
mod rng;

use std::path::PathBuf;

use anyhow::{ensure, Context, Result};

use crate::rng::Rng;

/// Fixed so that regenerating produces identical files.
const SEED: u64 = 0x4A49_4646_2D46_4F52;

fn main() -> Result<()> {
    let mut check = false;
    let mut classes_arg = None;
    for arg in std::env::args_os().skip(1) {
        if arg == "--check" {
            check = true;
        } else {
            classes_arg = Some(PathBuf::from(arg));
        }
    }
    let classes_dir = classes_dir(classes_arg)?;
    if check {
        return replay::check(&classes_dir);
    }
    let mut rng = Rng::new(SEED);
    emit::write_data_class(
        &classes_dir,
        "Date",
        civil::COLUMNS,
        &civil::rows(&mut rng)?,
    )?;
    emit::write_data_class(
        &classes_dir,
        "Duration",
        duration::ARITHMETIC_COLUMNS,
        &duration::arithmetic_rows(&mut rng),
    )?;
    emit::write_data_class(
        &classes_dir,
        "DurationRound",
        duration::ROUND_COLUMNS,
        &duration::round_rows(&mut rng),
    )?;
    Ok(())
}

/// The Apex classes directory: the one given on the command line, or the
/// default location relative to this crate.
fn classes_dir(given: Option<PathBuf>) -> Result<PathBuf> {
    let dir = given.unwrap_or_else(|| {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../force-app/main/default/classes")
    });
    let dir = dir
        .canonicalize()
        .with_context(|| format!("locating {}", dir.display()))?;
    ensure!(dir.is_dir(), "{} is not a directory", dir.display());
    Ok(dir)
}
