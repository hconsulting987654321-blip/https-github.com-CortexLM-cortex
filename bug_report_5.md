# [BUG] [v0.0.7] `TokenBucket` TOCTOU race in `try_acquire()` and `available_tokens()` allows over-consumption beyond burst_size

## Description
In `src/cortex-engine/src/ratelimit.rs`, the `TokenBucket` struct uses three separate `Mutex<T>` fields: `tokens`, `last_refill`, and `current_rate`. The `refill()` method acquires all three locks sequentially (last_refill → tokens → current_rate), performs the refill calculation, then releases all locks. Both `try_acquire()` and `available_tokens()` call `refill()` and then **re-acquire** the `tokens` mutex independently.

This creates a Time-Of-Check-Time-Of-Use (TOCTOU) race: between `refill()` releasing the `tokens` lock and `try_acquire()` re-acquiring it, another concurrent caller can also call `refill()` and see the same token balance. Both callers then each consume a token, resulting in over-consumption beyond the configured `burst_size`.

## Location
- **File**: `src/cortex-engine/src/ratelimit.rs`
- **Functions**: `TokenBucket::refill()`, `TokenBucket::try_acquire()`, `TokenBucket::available_tokens()`

## Buggy Code
```rust
pub struct TokenBucket {
    config: RateLimitConfig,
    tokens: Mutex<f64>,          // Mutex A
    last_refill: Mutex<Instant>, // Mutex B
    current_rate: Mutex<f64>,    // Mutex C
}

async fn refill(&self) {
    let mut last = self.last_refill.lock().await;       // Lock B
    let mut tokens = self.tokens.lock().await;           // Lock A (while B held)
    let rate = *self.current_rate.lock().await;          // Lock C (while B, A held)

    let now = Instant::now();
    let elapsed = now.duration_since(*last).as_secs_f64();
    let new_tokens = elapsed * rate;

    *tokens = (*tokens + new_tokens).min(self.config.burst_size as f64);
    *last = now;
    // All three locks released here
}

pub async fn try_acquire(&self) -> bool {
    self.refill().await;
    // ^^^ refill() acquires B -> A -> C, performs refill, releases all locks
    // GAP: another task can call refill() + try_acquire() here

    let mut tokens = self.tokens.lock().await;  // Re-acquire Lock A
    if *tokens >= 1.0 {
        *tokens -= 1.0;
        true
    } else {
        false
    }
}

pub async fn available_tokens(&self) -> f64 {
    self.refill().await;
    // Same GAP as above
    *self.tokens.lock().await  // Re-acquire Lock A -- stale view possible
}
```

## Race Scenario
1. `TokenBucket` has `burst_size = 10`, currently `tokens = 0.0`, and 1 second has elapsed since last refill at rate 10.0/s
2. **Task A** calls `try_acquire()` → `refill()` runs: adds 10 tokens, sets `tokens = 10.0`, releases all locks
3. **Task B** calls `try_acquire()` → `refill()` runs: `elapsed` is ~0.0 seconds (just refilled), adds ~0 tokens, `tokens` stays at `10.0`, releases all locks
4. **Task A** re-acquires `tokens` lock: sees `10.0 >= 1.0`, sets `tokens = 9.0` ✓
5. **Task B** re-acquires `tokens` lock: sees `9.0 >= 1.0`, sets `tokens = 8.0` ✓

This is the mild case. The severe case:

1. `tokens = 1.0` (just 1 token left), `burst_size = 5`
2. **Task A** calls `try_acquire()` → `refill()` adds 0.5 tokens → `tokens = 1.5`, releases locks
3. **Task B** calls `try_acquire()` → `refill()` runs in the gap, doesn't change much → `tokens ≈ 1.5`, releases locks
4. **Task A** acquires `tokens`: `1.5 >= 1.0` → consumes → `tokens = 0.5`
5. **Task B** acquires `tokens`: `0.5 < 1.0` → **rejected**

But with slightly different timing:
1. `tokens = 1.0`, both tasks enter `try_acquire()` simultaneously
2. Both call `refill()`, both add small amounts, both release locks
3. Both then try to acquire: first one gets it, second doesn't

The race means the rate limiter is **non-atomic** -- the check (refill + read balance) and the use (decrement) are separated by a lock release/reacquire gap. Under concurrent load, this leads to unpredictable token consumption that can exceed the intended rate.

## `FixedWindow` Has the Same Pattern
```rust
pub async fn try_acquire(&self) -> bool {
    self.maybe_reset().await;
    // maybe_reset() acquires window_start, possibly count, releases both
    // GAP: another task can call maybe_reset() + try_acquire() here

    let mut count = self.count.lock().await;  // Re-acquire count
    if *count < self.max_requests {
        *count += 1;
        true
    } else {
        false
    }
}
```

The window can reset between `maybe_reset()` and the count check, allowing tasks at the window boundary to either exceed the limit or be incorrectly rejected.

## Expected Behavior
The refill-and-consume operation should be atomic. Either:
1. Use a single `Mutex` protecting all state together, or
2. Keep the `tokens` lock held from `refill()` through the consumption in `try_acquire()`

## Actual Behavior
The `tokens` lock is released between `refill()` and the consumption check, creating a window for concurrent modification.

## Impact
- **Severity**: Medium
- **Consequence**: Under concurrent load, the rate limiter allows more requests through than the configured `burst_size` and `requests_per_second` intend, undermining the purpose of rate limiting. API rate limits or tool execution throttles may be exceeded, potentially causing upstream 429 errors or resource exhaustion.
