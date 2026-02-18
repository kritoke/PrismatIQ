# Mint Common Errors

This guide documents common errors, their causes, and solutions for Mint 0.28.1 development.

## Critical Syntax Errors

### HTML_ELEMENT_EXPECTED_CLOSING_TAG with <{ }>

**Error:**
```
HTML_ELEMENT_EXPECTED_CLOSING_TAG
```

**Cause:** Using wrong syntax for dynamic text.

**Fix:** Use `{ }` instead of `<{ }>`:

```mint
/* CORRECT */
<div>{ name }</div>
<div>{"Static text"}</div>

/* WRONG - causes error */
<div><{ name }></div>
```

### APPLICATION_INVALID_KEY: start

**Error:**
```
APPLICATION_INVALID_KEY: start
```

**Cause:** Using deprecated `application.start` key in mint.json.

**Fix:**
```bash
cd frontend
rm -rf .mint mint-packages.json

# Recreate mint.json (flat structure only)
{
  "name": "quickheadlines",
  "source-directories": ["source"],
  "dependencies": { ... }
}

mint install
```

**mint.json Structure:**
```json
{
  "name": "my-app",
  "source-directories": ["source"],
  "dependencies": {
    "mint-ui": {
      "repository": "https://github.com/mint-lang/mint-ui",
      "constraint": "8.0.0 <= v < 9.0.0"
    }
  }
}
```

### CONSTANT_EXPECTED_EXPRESSION: {

**Error:**
```
CONSTANT_EXPECTED_EXPRESSION: {
```

**Cause:** Using old JSON or Mint syntax.

**Fix:** Ensure `mint.json` has no nested `application` block with `start` key.

### FUNCTION_EXPECTED_CLOSING_BRACKET

**Error:**
```
FUNCTION_EXPECTED_CLOSING_BRACKET
```

**Cause:** Incorrect callback or closure syntax.

**Fix:** Use proper component structure:
```mint
component Main {
  fun render : Html {
    <div>Hello</div>
  }
}
```

### UNEXPECTED_TOKEN: expect "render"

**Error:**
```
UNEXPECTED_TOKEN: expect "render"
```

**Cause:** Missing `render` function in component.

**Fix:** Always define `fun render : Html`:
```mint
component Main {
  fun render : Html {
    <div>Content</div>
  }
}
```

## Type Errors

### Cannot infer type of expression

**Error:**
```
Cannot infer type of expression
```

**Cause:** Missing type annotation for complex types.

**Fix:** Add explicit type annotations:
```mint
/* WRONG */
let items = []

/* CORRECT */
let items : Array(Item) = []
```

### Type mismatch

**Error:**
```
Type mismatch
```

**Cause:** Type mismatch between expected and actual types.

**Fix:** Check type compatibility:
```mint
/* WRONG - String where Int expected */
let count : Int = "5"

/* CORRECT */
let count : Int = 5
let count = Int.fromString("5") // If converting from string
```

### Property does not exist on type

**Error:**
```
Property does not exist on type
```

**Cause:** Accessing non-existent property on a type.

**Fix:** Verify type definition and property names:
```mint
/* WRONG */
<div>{ user.phone_number }</div>

/* CORRECT - check type definition */
type User {
  name : String,
  email : String,
  phoneNumber : String  /* snake_case vs camelCase */
}
```

## State Management Errors

### Cannot mutate state directly

**Error:**
```
Cannot mutate state
```

**Cause:** Attempting to mutate state instead of using `next`.

**Fix:** Use `next` keyword:
```mint
/* WRONG */
this.count = count + 1

/* CORRECT */
next count = count + 1
```

### State not in store

**Error:**
```
State not found in store
```

**Cause:** Referencing state that doesn't exist in the store.

**Fix:** Define state in the store:
```mint
store MyStore {
  state myValue : String = ""  /* Define state here */
}

/* Component using store */
component MyComponent {
  use MyStore

  fun render : Html {
    <div>{@myStore.myValue}</div>
  }
}
```

## Import and Module Errors

### Module not found

**Error:**
```
Module not found
```

**Cause:** Missing or incorrect import.

**Fix:** Ensure module exists in source directories:
```mint
/* File: source/Components/Button.mint */
component Button {
  fun render : Html {
    <button>Click</button>
  }
}

/* Usage in another file */
component Main {
  /* Mint auto-imports from source directories */
  fun render : Html {
    <Button/>
  }
}
```

### Circular dependency

**Error:**
```
Circular dependency detected
```

**Cause:** Modules importing each other in a loop.

**Fix:** Restructure to avoid circular imports:
```mint
/* WRONG */
/* User.mint imports Post.mint, Post.mint imports User.mint */

/* CORRECT */
/* Move shared code to a third module */
```

## Build and Cache Errors

### Stale cache causing strange errors

**Error:** Various unrelated errors appearing

**Cause:** Corrupted or stale Mint cache.

**Fix:**
```bash
cd frontend
rm -rf .mint mint-packages.json
mint install
```

### Build hangs

**Error:** `mint build` or `mint serve` hangs indefinitely

**Cause:** Infinite loop or very slow compilation.

**Fix:**
```bash
# Kill hanging process
pkill -9 -f mint

# Clear cache
rm -rf frontend/.mint frontend/mint-packages.json

# Retry
cd frontend
mint install
mint serve
```

### Out of memory during build

**Error:** Build fails with memory exhaustion

**Cause:** Large project or memory constraints.

**Fix:**
```bash
# Try with optimize flag
mint build --optimize

# Increase Node.js memory limit
export NODE_OPTIONS="--max-old-space-size=4096"
```

## Runtime Errors

### 404 on API calls

**Error:** HTTP requests fail with 404

**Cause:** Incorrect API endpoint URL.

**Fix:**
```mint
/* WRONG - missing leading slash */
response = Http.get("api/items")

/* CORRECT */
response = Http.get("/api/items")
```

### CORS errors

**Error:** Cross-origin resource sharing errors

**Cause:** Browser blocking API requests to different origin.

**Fix:** Configure CORS on backend server.

### Promise not handled

**Error:** Unhandled promise rejection

**Cause:** Missing try-catch around async operations.

**Fix:**
```mint
/* WRONG */
fun loadData() {
  Http.get("/api/data")
}

/* CORRECT */
fun loadData() : Promise(Void) {
  try {
    response = Http.get("/api/data")
    data = Json.decode(response.body)
    next data = data
  } catch Error(message) {
    next error = some(message)
  }
}
```

## mint.json Configuration Errors

### Invalid dependency format

**Error:** Dependency installation fails

**Cause:** Incorrect dependency specification.

**Fix:**
```json
/* WRONG */
"dependencies": {
  "mint-ui": "1.0.0"
}

/* CORRECT */
"dependencies": {
  "mint-ui": {
    "repository": "https://github.com/mint-lang/mint-ui",
    "constraint": "8.0.0 <= v < 9.0.0"
  }
}
```

### source-directories missing

**Error:** Cannot find source files

**Cause:** Missing or incorrect source directory configuration.

**Fix:**
```json
{
  "name": "my-app",
  "source-directories": ["source"]
}
```

### Duplicate source directory

**Error:** Duplicate directory error

**Cause:** Specifying same directory twice.

**Fix:** Use unique directories:
```json
{
  "name": "my-app",
  "source-directories": ["source", "components"]
}
```

## Debugging Techniques

### Enable verbose logging

```bash
mint serve --verbose
```

### Check compiled JavaScript

```bash
mint build
cat dist/app.js
```

### Use Debug.log

```mint
fun handleClick() {
  Debug.log("Button clicked!")
  Debug.log(variable)
  /* Check browser console for output */
}
```

### Browser developer tools

1. Open browser DevTools (F12)
2. Check Console for runtime errors
3. Check Network tab for failed HTTP requests
4. Check Sources for compiled Mint code

## Troubleshooting Checklist

1. [ ] `mint.json` uses flat structure (no `application.start`)
2. [ ] `source-directories` is plural and an array
3. [ ] Dependencies use `repository` + `constraint` format
4. [ ] Component is named `Main` in `source-directories`
5. [ ] Component uses `fun render : Html { }`
6. [ ] Dynamic text uses `{ variable }` NOT `<{ variable }>`
7. [ ] State changes use `next` keyword
8. [ ] Deleted `.mint` and `mint-packages.json` after schema changes
9. [ ] Ran `mint install` after cache deletion
10. [ ] Type annotations added for arrays and complex types
11. [ ] Event handlers use correct syntax: `fun (event) { }`
12. [ ] All HTTP requests have proper URL format

## Common Anti-Patterns to Avoid

### ❌ Old Dynamic Text Syntax
```mint
/* WRONG */
<{ name }>
<{"Text"}>
```

### ❌ State Mutation
```mint
/* WRONG */
this.loading = True
this.items = newItems
```

### ❌ Missing Render Function
```mint
/* WRONG - missing fun keyword */
render {
  <div>Content</div>
}
```

### ❌ Old mint.json Schema
```mint
/* WRONG */
{
  "application": {
    "start": "Main"
  }
}
```

### ❌ Incorrect Dependency Format
```mint
/* WRONG */
"mint-ui": "1.0.0"
```
