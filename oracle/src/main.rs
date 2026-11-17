//! Generates golden test vectors for jiff-force by running the real Jiff
//! crate, pinned to the release the port tracks.
//!
//! The output is a set of Apex data classes (`JiffOracle*Data.cls`). Hand
//! written Apex tests (`JiffOracle*Test.cls`) replay every row against the
//! port, which makes the Rust implementation the oracle for the Apex one.
//!
//! Usage: `cargo run --manifest-path oracle/Cargo.toml` from the repository
//! root, or `npm run oracle`, which also formats the result.

mod civil;
mod duration;
mod emit;
mod rng;

use std::path::PathBuf;

use anyhow::{ensure, Context, Result};

use crate::rng::Rng;

/// Fixed so that regenerating produces identical files.
const SEED: u64 = 0x4A49_4646_2D46_4F52;

fn main() -> Result<()> {
    let classes_dir = classes_dir()?;
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

/// The Apex classes directory: the first argument, or the default location
/// relative to this crate.
fn classes_dir() -> Result<PathBuf> {
    let dir = std::env::args_os().nth(1).map_or_else(
        || PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../force-app/main/default/classes"),
        PathBuf::from,
    );
    let dir = dir
        .canonicalize()
        .with_context(|| format!("locating {}", dir.display()))?;
    ensure!(dir.is_dir(), "{} is not a directory", dir.display());
    Ok(dir)
}
