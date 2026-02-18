# Mint Health Protocol

This guide covers health checks, verification rituals, and build processes for Mint applications.

## Development Health Checks

### Pre-Development Checklist

Before starting work on a Mint project:

```bash
# 1. Verify Mint installation
mint --version
# Expected: 0.28.1 or higher

# 2. Check project structure
ls -la source/
# Expected: Main.mint and component files

# 3. Verify mint.json configuration
cat mint.json
# Expected: flat structure with source-directories

# 4. Install dependencies
mint install
# Expected: Dependencies installed without errors

# 5. Run initial build
mint build --optimize
# Expected: Build succeeds
```

### Session Start Protocol

When starting a development session:

```bash
# 1. Clear any stale processes
pkill -9 -f mint || true

# 2. Clear cache if needed
rm -rf frontend/.mint frontend/mint-packages.json

# 3. Install fresh dependencies
mint install

# 4. Start development server
mint serve
```

### Deadlock Recovery

If the server hangs:

```bash
# 1. Force kill all mint processes
pkill -9 -f mint

# 2. Clear cache
rm -rf frontend/.mint frontend/mint-packages.json

# 3. Check for port conflicts
lsof -i :3000

# 4. Kill conflicting process if needed
kill <PID>

# 5. Restart fresh
mint install && mint serve
```

## Build Verification

### Quality Gate Commands

```bash
# Step 1: Format code
mint format source/

# Step 2: Type check
mint check

# Step 3: Build production bundle
mint build --optimize

# Step 4: Verify output
ls -la dist/
```

### CI/CD Health Check

```yaml
# GitHub Actions workflow
name: Mint Health Check

on: [push, pull_request]

jobs:
  health-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Mint
        uses: mint-lang/setup-mint@v1
        with:
          mint-version: '0.28.1'

      - name: Install Dependencies
        run: mint install

      - name: Format Check
        run: mint format --check source/

      - name: Type Check
        run: mint check

      - name: Build
        run: mint build --optimize

      - name: Verify Build Output
        run: |
          test -f dist/app.js && echo "Build successful"
          test -f dist/index.html && echo "HTML generated"
```

## Runtime Health Checks

### Application Health Endpoint

```mint
component HealthCheck {
  state status : HealthStatus = checking
  state message : String = ""

  fun checkHealth() : Promise(Void) {
    next status = checking
    next message = "Checking..."

    try {
      response = Http.get("/api/health")
      if response.status == 200 {
        next status = healthy
        next message = "All systems operational"
      } else {
        next status = unhealthy
        next message = "API returned status: #{response.status}"
      }
    } catch Error(message) {
      next status = unhealthy
      next message = "Connection failed: #{message}"
    }
  }

  fun render : Html {
    <div class="health-check">
      <h2>{"System Status"}</h2>

      <div class="status-indicator {status}">
        <span class="status-text">
          { case status {
              healthy => "✓ Healthy"
              unhealthy => "✗ Unhealthy"
              checking => "⟳ Checking..."
            } }
        </span>
        <p>{ message }</p>
      </div>

      <button onClick={fun (event : Html.Event) { checkHealth() }}>
        {"Refresh Status"}
      </button>
    </div>
  }
}
```

### Store Health Monitoring

```mint
store AppStore {
  state isConnected : Bool = false
  state lastSync : Maybe(DateTime) = none
  state syncError : Maybe(String) = none

  fun checkConnection() : Promise(Void) {
    try {
      response = Http.get("/api/ping")
      if response.status == 200 {
        next isConnected = true
        next syncError = none
      } else {
        next isConnected = false
        next syncError = some("API responded with #{response.status}")
      }
    } catch Error(message) {
      next isConnected = false
      next syncError = some("Connection failed: #{message}")
    }
  }

  fun syncData() : Promise(Void) {
    try {
      await checkConnection()
      if isConnected {
        data = await fetchData()
        next lastSync = some(DateTime.now())
        next data = some(data)
      }
    } catch Error(message) {
      next syncError = some(message)
    }
  }
}
```

## Performance Monitoring

### Build Performance

```bash
# Measure build time
time mint build --optimize

# Expected: < 30 seconds for typical project

# Measure serve time
time mint serve

# Expected: < 5 seconds for initial load
```

### Runtime Performance

```mint
component PerformanceMonitor {
  state renderCount : Int = 0
  state lastRenderTime : Float = 0.0

  fun measureRender(startTime : Float) : Void {
    endTime = DateTime.now().time
    duration = endTime - startTime
    next renderCount = renderCount + 1
    next lastRenderTime = duration
  }

  fun render : Html {
    measureRender(DateTime.now().time)

    <div class="performance">
      <p>{"Render count: #{renderCount}"}</p>
      <p>{"Last render: #{lastRenderTime}ms"}</p>
    </div>
  }
}
```

## Dependency Health

### Dependency Check

```bash
# Check for outdated dependencies
# (Mint doesn't have built-in command, check manually)

# Verify installed packages
ls -la .mint/

# Check for updates in mint.json
grep -A2 "dependencies" mint.json
```

### Security Audit

```bash
# Check for known vulnerabilities in dependencies
# (Use external tools like npm audit if applicable)

# Verify dependency sources
cat mint.json
# Expected: Official repositories only
```

## Container/Deployment Health

### Docker Health Check

```dockerfile
FROM mintlang/mint:latest

WORKDIR /app
COPY . .

RUN mint install && \
    mint build --optimize

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

CMD ["mint", "serve", "--port", "3000"]
```

### Kubernetes Liveness Probe

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mint-app
spec:
  containers:
  - name: mint-app
    image: mint-app:latest
    ports:
    - containerPort: 3000
    livenessProbe:
      httpGet:
        path: /health
        port: 3000
      initialDelaySeconds: 10
      periodSeconds: 30
    readinessProbe:
      httpGet:
        path: /ready
        port: 3000
      initialDelaySeconds: 5
      periodSeconds: 10
```

## Verification Scripts

### Pre-commit Verification

```bash
#!/bin/bash
# scripts/pre-commit-check.sh

echo "Running Mint health check..."

# Format
echo "Formatting code..."
mint format source/

# Check
echo "Type checking..."
mint check

if [ $? -ne 0 ]; then
  echo "❌ Type check failed"
  exit 1
fi

# Build
echo "Building..."
mint build --optimize

if [ $? -ne 0 ]; then
  echo "❌ Build failed"
  exit 1
fi

echo "✅ All checks passed"
exit 0
```

### Daily Health Report

```bash
#!/bin/bash
# scripts/health-report.sh

echo "=== Mint Project Health Report ==="
echo "Date: $(date)"
echo ""

echo "Version:"
mint --version
echo ""

echo "Dependencies:"
mint install 2>&1 | head -20
echo ""

echo "Build Status:"
mint build --optimize
if [ $? -eq 0 ]; then
  echo "✅ Build successful"
else
  echo "❌ Build failed"
fi
echo ""

echo "File Count:"
find source -name "*.mint" | wc -l
echo ""

echo "=== End Report ==="
```

## Troubleshooting Common Issues

### Issue: Build Fails with Memory Error

```bash
# Increase Node.js memory
export NODE_OPTIONS="--max-old-space-size=4096"
mint build --optimize
```

### Issue: Server Won't Start

```bash
# Kill all mint processes
pkill -9 -f mint

# Clear cache
rm -rf frontend/.mint frontend/mint-packages.json

# Check port availability
lsof -i :3000

# Restart
mint install && mint serve
```

### Issue: Type Checking Errors

```bash
# Clear type cache
rm -rf .mint

# Reinstall
mint install

# Check types
mint check
```

### Issue: Styles Not Applying

```bash
# Clear CSS cache
rm -rf .mint

# Rebuild
mint build --optimize

# Check style syntax
mint format source/
```

## Health Check Dashboard

```mint
component HealthDashboard {
  state checks : Array(HealthCheck) = []

  fun runAllChecks() : Promise(Void) {
    next checks = [
      { name: "Mint Version", status: checkVersion() },
      { name: "Dependencies", status: checkDependencies() },
      { name: "Type Check", status: checkTypes() },
      { name: "Build", status: checkBuild() },
      { name: "API Health", status: checkApiHealth() }
    ]
  }

  fun render : Html {
    <div class="dashboard">
      <h1>{"System Health Dashboard"}</h1>

      <button onClick={fun (event : Html.Event) { runAllChecks() }}>
        {"Run All Checks"}
      </button>

      <div class="check-list">
        for check of checks {
          <HealthCheckRow check={check}/>
        }
      </div>
    </div>
  }
}
```

## Metrics and Logging

### Application Logs

```mint
store LoggingStore {
  state logs : Array(LogEntry) = []
  state level : LogLevel = Info

  fun log(message : String, level : LogLevel) {
    entry = {
      timestamp: DateTime.now(),
      message: message,
      level: level
    }
    next logs = logs + [entry]

    if level >= error {
      /* Send to error tracking service */
      sendToErrorTracker(entry)
    }
  }

  fun info(message : String) {
    log(message, Info)
  }

  fun error(message : String) {
    log(message, Error)
  }
}
```

### Performance Metrics

```mint
component MetricsCollector {
  state metrics : Metrics = {
    apiCalls: 0,
    apiErrors: 0,
    renderCount: 0,
    avgRenderTime: 0.0
  }

  fun recordApiCall(success : Bool) {
    next metrics.apiCalls = metrics.apiCalls + 1
    if not success {
      next metrics.apiErrors = metrics.apiErrors + 1
    }
  }

  fun recordRender(time : Float) {
    count = metrics.renderCount + 1
    avg = ((metrics.avgRenderTime * metrics.renderCount) + time) / count
    next metrics.renderCount = count
    next metrics.avgRenderTime = avg
  }

  fun getHealthScore() : Int {
    if metrics.apiCalls == 0 {
      return 100
    }

    errorRate = metrics.apiErrors / metrics.apiCalls
    100 - (errorRate * 100)
  }
}
```
