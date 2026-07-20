/// Four AI strength tiers (rules doc §6). Both engines share one code path
/// per tier, varying only search depth/budget and injected randomness —
/// not a separate implementation per tier.
enum Difficulty { easy, medium, hard, impossible }
