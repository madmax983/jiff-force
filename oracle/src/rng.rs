//! A tiny deterministic generator so that vector files are reproducible
//! byte for byte without pulling in a dependency.

/// `SplitMix64`: small, fast and well distributed enough for picking test inputs.
pub struct Rng(u64);

impl Rng {
    pub const fn new(seed: u64) -> Self {
        Self(seed)
    }

    /// A generator for one named topic: the same seed and name always give
    /// the same stream, and different names give unrelated streams.
    pub fn for_topic(seed: u64, topic: &str) -> Self {
        // FNV-1a over the name, folded into the seed.
        let hash = topic.bytes().fold(0xCBF2_9CE4_8422_2325_u64, |hash, byte| {
            (hash ^ u64::from(byte)).wrapping_mul(0x0000_0100_0000_01B3)
        });
        Self(seed ^ hash)
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_same_seed_gives_the_same_stream() {
        let mut a = Rng::new(42);
        let mut b = Rng::new(42);
        for _ in 0..100 {
            assert_eq!(a.next_u64(), b.next_u64());
        }
    }

    #[test]
    fn topics_have_streams_of_their_own() {
        let mut date = Rng::for_topic(1, "Date");
        let mut date_again = Rng::for_topic(1, "Date");
        let mut time = Rng::for_topic(1, "Time");
        let first = date.next_u64();
        assert_eq!(first, date_again.next_u64());
        assert_ne!(first, time.next_u64());
    }

    #[test]
    fn range_is_inclusive_and_covers_the_extremes() {
        let mut rng = Rng::new(3);
        let mut seen = [false; 3];
        for _ in 0..200 {
            let value = rng.range(-1, 1);
            assert!((-1..=1).contains(&value));
            seen[usize::try_from(value + 1).unwrap()] = true;
        }
        assert_eq!(seen, [true; 3]);
        assert_eq!(rng.range(5, 5), 5);
        // The full width of an i64 must not overflow.
        let _ = rng.range(i64::MIN, i64::MAX);
    }

    #[test]
    fn pick_returns_an_element_of_the_slice() {
        let mut rng = Rng::new(9);
        let items = [10, 20, 30];
        for _ in 0..50 {
            assert!(items.contains(rng.pick(&items)));
        }
    }
}
