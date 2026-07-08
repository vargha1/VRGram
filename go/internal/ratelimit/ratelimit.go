package ratelimit

import (
    "sync"
    "time"
)

type TokenBucket struct {
    mu        sync.Mutex
    rate      float64       // tokens per second
    burst     int           // max tokens
    tokens    float64
    lastCheck time.Time
}

func NewTokenBucket(rate int, burst int) *TokenBucket {
    return &TokenBucket{
        rate:      float64(rate),
        burst:     burst,
        tokens:    float64(burst),
        lastCheck: time.Now(),
    }
}

func (tb *TokenBucket) Allow() bool {
    return tb.AllowN(1)
}

func (tb *TokenBucket) AllowN(n int) bool {
    tb.mu.Lock()
    defer tb.mu.Unlock()

    now := time.Now()
    elapsed := now.Sub(tb.lastCheck).Seconds()
    tb.lastCheck = now
    tb.tokens += elapsed * tb.rate
    if tb.tokens > float64(tb.burst) {
        tb.tokens = float64(tb.burst)
    }

    if tb.tokens >= float64(n) {
        tb.tokens -= float64(n)
        return true
    }
    return false
}

// Per-IP rate limiter with sharded buckets
type IPRateLimiter struct {
    mu      sync.Mutex
    limit   int
    burst   int
    buckets map[string]*TokenBucket
}

func NewIPRateLimiter(limit, burst int) *IPRateLimiter {
    return &IPRateLimiter{
        limit:   limit,
        burst:   burst,
        buckets: make(map[string]*TokenBucket),
    }
}

func (rl *IPRateLimiter) Allow(ip string) bool {
    rl.mu.Lock()
    tb, ok := rl.buckets[ip]
    if !ok {
        tb = NewTokenBucket(rl.limit, rl.burst)
        rl.buckets[ip] = tb
    }
    rl.mu.Unlock()
    return tb.Allow()
}
