# Mint Code Review

This guide provides code review guidelines, common anti-patterns, and best practices for reviewing Mint code.

## Review Checklist

### Syntax and Structure

- [ ] Component has `fun render : Html` function
- [ ] State changes use `next` keyword, not mutation
- [ ] Dynamic text uses `{ variable }` syntax, not `<{ }>`
- [ ] Type annotations are provided for arrays and complex types
- [ ] mint.json has flat structure (no `application.start`)

### State Management

- [ ] State is defined in stores for shared state
- [ ] Local component state is used for UI-only concerns
- [ ] State updates are immutable (using `next`)
- [ ] Loading states are properly managed
- [ ] Error states are handled appropriately

### Performance

- [ ] Lists use keys for proper reconciliation
- [ ] Expensive operations are async/await
- [ ] Unnecessary re-renders are minimized
- [ ] Data is fetched on mount, not on every render

### Security

- [ ] User input is validated before use
- [ ] Dynamic URLs are sanitized
- [ ] Sensitive data is not logged
- [ ] Authentication is checked before protected operations

## Common Anti-Patterns

### Anti-Pattern: State Mutation

```mint
/* WRONG - Mutating state directly */
component BadExample {
  fun updateCount() {
    this.count = this.count + 1
  }
}

/* CORRECT - Using next */
component GoodExample {
  state count : Int = 0

  fun updateCount() {
    next count = count + 1
  }
}
```

### Anti-Pattern: Missing Type Annotation

```mint
/* WRONG - Cannot infer type */
let items = []

/* CORRECT - Explicit type */
let items : Array(Item) = []
```

### Anti-Pattern: Old Dynamic Text Syntax

```mint
/* WRONG */
<div><{ name }></div>
<div>#{name}</div>

/* CORRECT */
<div>{ name }</div>
```

### Anti-Pattern: Missing Render Function

```mint
/* WRONG - Missing fun keyword */
render {
  <div>Content</div>
}

/* CORRECT */
fun render : Html {
  <div>Content</div>
}
```

### Anti-Pattern: HTTP in Render

```mint
/* WRONG - HTTP in render causes infinite loop */
component BadExample {
  fun render : Html {
    Http.get("/api/data") /* Don't do this! */
    <div>Content</div>
  }
}

/* CORRECT - Fetch in function, call from mount */
component GoodExample {
  state data : Maybe(Array(Item)) = none

  fun loadData() : Promise(Void) {
    try {
      items = await Http.get("/api/data")
      next data = some(items)
    } catch Error {
      Debug.log("Failed")
    }
  }

  fun mount : Void {
    loadData()
  }

  fun render : Html {
    <div>Content</div>
  }
}
```

### Anti-Pattern: Missing Keys in Lists

```mint
/* WRONG - No key for list items */
for item of items {
  <ItemComponent item={item}/>
}

/* CORRECT - Key for proper reconciliation */
for item of items {
  <ItemComponent key={item.id} item={item}/>
}
```

## Code Review Comments

### Critical Issues (Must Fix)

```
[FIX] State mutation detected: `this.count = count + 1`
Use `next count = count + 1` instead.

[FIX] XSS vulnerability: `<a href={userUrl}>`
Validate that userUrl starts with http:// or https://

[FIX] Missing authentication check
This API call requires auth. Use AuthStore to get token.
```

### Important Issues (Should Fix)

```
[IMPROVE] Missing type annotation for `items`
Add: `let items : Array(Item) = []`

[IMPROVE] Consider using store for shared state
State is used across multiple components.

[IMPROVE] Add loading state
UI doesn't show loading indicator during async operations.
```

### Style Issues (Nice to Have)

```
[STYLE] Consider renaming for clarity
`data` → `userData` or `responseData`

[STYLE] Extract complex logic into named function
`loadItemsAndProcess()` could be split into multiple functions.

[STYLE] Add documentation comment
Complex function would benefit from docstring.
```

## Review Process

### Step 1: Syntax Validation

```bash
# Format code
mint format source/

# Check for errors
mint check

# Build
mint build --optimize
```

### Step 2: Security Review

1. Check all user input is validated
2. Verify no sensitive data exposure
3. Confirm authentication checks
4. Review API call permissions

### Step 3: Performance Review

1. Check for unnecessary re-renders
2. Verify async operations are used correctly
3. Ensure lists have proper keys
4. Check for memory leaks

### Step 4: Code Quality Review

1. Follow naming conventions
2. Check component organization
3. Verify error handling
4. Ensure test coverage

## Component Review Guidelines

### Size and Complexity

- Components should do one thing well
- Split large components into smaller ones
- Extract reusable logic into utilities
- Keep render functions concise

### Props and State

- Props should be well-documented
- Default values for optional props
- State should be minimal
- Lift state up when needed

### Styling

- Use style blocks for component-specific CSS
- Follow naming conventions
- Use media queries for responsiveness
- Avoid inline styles when possible

## Store Review Guidelines

### State Design

- State should be normalized for arrays
- Avoid derived state when possible
- Use appropriate data structures
- Consider immutability

### Actions

- Single responsibility per action
- Proper error handling
- Loading state management
- Side effects in async actions

### Performance

- Batch state updates when possible
- Consider selectors for derived data
- Memoize expensive computations
- Clean up subscriptions

## Testing Review

### Test Coverage

- Unit tests for utility functions
- Integration tests for stores
- Component tests for UI behavior
- E2E tests for critical paths

### Test Quality

- Tests are isolated and independent
- Tests are readable and maintainable
- Tests use meaningful assertions
- Tests cover edge cases

## Documentation Review

### Code Documentation

- Complex functions have docstrings
- Public APIs are documented
- Non-obvious logic is explained
- Examples are provided

### README Updates

- New features are documented
- Breaking changes are noted
- Examples are up to date
- Installation instructions are correct
