//! A tiny deterministic generator so that vector files are reproducible
//! byte for byte without pulling in a dependency.

/// `SplitMix64`: small, fast and well distributed enough for picking test inputs.
pub struct Rng(u64);

impl Rng {
    pub const fn new(seed: u64) -> Self {
        Self(seed)
    }

    pub const fn next_u64(&mut self) -> u64 {
        self.0 = self.0.wrapping_add(0x9E37_79B9_7F4A_7C15);
        let mut z = self.0;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
        z ^ (z >> 31)
    }

    /// A value in `lo..=hi`.
    pub fn range(&mut self, lo: i64, hi: i64) -> i64 {
        debug_assert!(lo <= hi);
        let width = u128::from(lo.abs_diff(hi)) + 1;
        let offset = u128::from(self.next_u64()) % width;
        // `offset` is at most `hi - lo`, so the sum cannot leave `lo..=hi`.
        let value = i128::from(lo) + i128::try_from(offset).unwrap_or(0);
        i64::try_from(value).unwrap_or(hi)
    }

    /// One element of a non-empty slice.
    pub fn pick<'a, T>(&mut self, items: &'a [T]) -> &'a T {
        let last = i64::try_from(items.len()).unwrap_or(1) - 1;
        let index = usize::try_from(self.range(0, last)).unwrap_or(0);
        &items[index]
    }
}
