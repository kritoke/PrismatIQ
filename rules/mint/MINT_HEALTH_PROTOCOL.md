# Mint Health Protocol

## Pre-Development Verification

```bash
# Verify Mint installation
mint --version

# Expected: 0.28.1 or higher
```

## Session Start Ritual

```bash
# 1. Clear stale processes
pkill -9 -f mint || true

# 2. Clear cache
rm -rf frontend/.mint frontend/mint-packages.json

# 3. Install dependencies
mint install

# 4. Start development server
mint serve
```

## Deadlock Recovery

If server hangs:

```bash
# 1. Force kill
pkill -9 -f mint

# 2. Clear cache
rm -rf frontend/.mint frontend/mint-packages.json

# 3. Restart
mint install && mint serve
```

## Quality Gate

```bash
# Format code
mint format source/

# Type check
mint check

# Build
mint build --optimize
```

## Health Check Commands

```bash
# Check Mint version
mint --version

# Check dependencies
mint install

# Check for errors
mint check

# Build and verify
mint build --optimize && echo "Build successful"
```

## Cache Management

Always clear cache when seeing strange errors:

```bash
rm -rf frontend/.mint frontend/mint-packages.json
mint install
```
