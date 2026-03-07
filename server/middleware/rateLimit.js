function resolveClientIp(req) {
  const forwarded = req.headers["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.trim()) {
    return forwarded.split(",")[0].trim();
  }

  return req.ip || req.socket?.remoteAddress || "unknown";
}

function createRateLimiter({
  windowMs = 15 * 60 * 1000,
  max = 100,
  message = "Too many requests, please try again later.",
  statusCode = 429,
  keyGenerator,
  skip,
} = {}) {
  const buckets = new Map();

  const sweepIntervalMs = Math.max(windowMs, 30 * 1000);
  const sweepTimer = setInterval(() => {
    const now = Date.now();
    for (const [key, bucket] of buckets.entries()) {
      if (bucket.resetAt <= now) {
        buckets.delete(key);
      }
    }
  }, sweepIntervalMs);

  if (typeof sweepTimer.unref === "function") {
    sweepTimer.unref();
  }

  const defaultKeyGenerator = (req) => {
    const ip = resolveClientIp(req);
    return `${ip}:${req.method}:${req.baseUrl || req.path || req.originalUrl || ""}`;
  };

  return (req, res, next) => {
    if (req.method === "OPTIONS") {
      return next();
    }

    if (typeof skip === "function" && skip(req)) {
      return next();
    }

    const now = Date.now();
    const key = String((keyGenerator || defaultKeyGenerator)(req));

    let bucket = buckets.get(key);
    if (!bucket || bucket.resetAt <= now) {
      bucket = {
        count: 0,
        resetAt: now + windowMs,
      };
    }

    bucket.count += 1;
    buckets.set(key, bucket);

    const remaining = Math.max(0, max - bucket.count);
    res.setHeader("X-RateLimit-Limit", String(max));
    res.setHeader("X-RateLimit-Remaining", String(remaining));
    res.setHeader("X-RateLimit-Reset", String(Math.ceil(bucket.resetAt / 1000)));

    if (bucket.count > max) {
      return res.status(statusCode).json({
        message,
        retryAfterMs: Math.max(0, bucket.resetAt - now),
      });
    }

    return next();
  };
}

module.exports = {
  createRateLimiter,
};
