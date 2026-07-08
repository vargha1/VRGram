package ratelimit

import (
    "testing"
    "time"
)

func TestBasicRateLimit(t *testing.T) {
    tb := NewTokenBucket(10, 5)
    // Burst: first 5 should be allowed
    for i := 0; i < 5; i++ {
        if !tb.Allow() {
            t.Fatalf("expected allow at attempt %d", i)
        }
    }
    // Next should be denied (empty bucket)
    if tb.Allow() {
        t.Fatal("expected deny after burst exhausted")
    }
    // Wait for refill
    time.Sleep(200 * time.Millisecond)
    if !tb.Allow() {
        t.Fatal("expected allow after refill")
    }
}
