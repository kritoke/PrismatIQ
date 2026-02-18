# Mint Linter Best Practices

This guide covers code quality standards, linting rules, and best practices for maintaining clean Mint code.

## Code Formatting

### Automatic Formatting

```bash
# Format all source files
mint format source/

# Format specific file
mint format source/Main.mint

# Format with custom width
mint format source/ --line-width 120
```

### Manual Formatting Rules

**Line Width**
- Maximum line width: 100 characters (adjustable)
- Exception: Long strings, URLs

**Indentation**
- Use 2 spaces for indentation
- No tabs

**Spacing**
- Space after commas: `function(a, b, c)`
- Space around operators: `a + b`
- Space before braces: `fun render : Html {`

**Example:**
```mint
component MyComponent {
  property items : Array(Item)
  property title : String

  style base {
    padding: 16px;
    margin-bottom: 20px;
  }

  fun render : Html {
    <div::base>
      <h1>{ title }</h1>
      for item of items {
        <ItemCard item={item}/>
      }
    </div>
  }
}
```

## Naming Conventions

### Components

```mint
/* PascalCase */
component UserProfile { }
component FeedCard { }
component ApiService { }
```

### Stores

```mint
/* PascalCase */
store UserStore { }
store FeedStore { }
store SettingsStore { }
```

### Functions

```mint
/* camelCase */
fun fetchUserData() : Promise(Void) { }
fun validateForm() : Bool { }
fun processPayment() : Promise(Result) { }
```

### Variables

```mint
/* camelCase */
let userName = "John"
let itemCount = 5
let isLoading = false
```

### Constants

```mint
/* SCREAMING_SNAKE_CASE */
const MAX_ITEMS = 100
const API_BASE_URL = "https://api.example.com"
```

### Properties

```mint
/* camelCase */
component Card {
  property title : String
  property itemCount : Int
  property isActive : Bool
}
```

### Styles

```mint
/* camelCase */
style cardBase { }
style headerSection { }
style primaryButton { }
```

## Component Structure

### Proper Ordering

```mint
component ExampleComponent {
  /* 1. Properties */
  property title : String
  property items : Array(Item)
  property onAction : Fun(Item, Void)

  /* 2. State */
  state isExpanded : Bool = false
  state loading : Bool = false

  /* 3. Computed values / derived state */
  fun itemCount() : Int {
    Array.size(items)
  }

  /* 4. Lifecycle */
  fun mount : Void {
    loadData()
  }

  /* 5. Event handlers */
  fun handleToggle() {
    next isExpanded = not isExpanded
  }

  /* 6. Async functions */
  fun loadData() : Promise(Void) {
    /* ... */
  }

  /* 7. Styles */
  style container {
    padding: 16px;
  }

  style header {
    font-size: 18px;
  }

  /* 8. Render function last */
  fun render : Html {
    <div::container>
      <div::header>{ title }</div>
      <div>{ "Count: #{itemCount()}" }</div>
    </div>
  }
}
```

## Style Organization

### CSS Properties Order

```mint
style component {
  /* 1. Layout */
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: flex-start;
  position: relative;
  top: 0;
  left: 0;

  /* 2. Box model */
  width: 100%;
  height: auto;
  padding: 16px;
  margin: 0;
  border: 1px solid #ccc;

  /* 3. Visual */
  background: #fff;
  color: #333;
  font-family: "Inter", sans-serif;
  font-size: 14px;
  line-height: 1.5;

  /* 4. Effects */
  border-radius: 8px;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  opacity: 1;

  /* 5. Transitions */
  transition: all 0.2s ease;

  /* 6. Interactive */
  cursor: pointer;

  /* 7. Pseudo-classes */
  &:hover {
    background: #f5f5f5;
  }

  &:active {
    transform: scale(0.98);
  }

  &:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }

  /* 8. Media queries at end */
  @media (max-width: 768px) {
    padding: 12px;
    font-size: 13px;
  }
}
```

## Type Annotations

### When to Use Explicit Types

```mint
/* Required for arrays and complex types */
let users : Array(User) = []
let items : Map(String, Item) = Map.empty()

/* Required for function parameters */
fun processUser(user : User, config : Config) : Result {
  /* ... */
}

/* Required for function return types */
fun fetchData() : Promise(Array(Item)) {
  /* ... */
}

/* Optional but recommended for public APIs */
state count : Int = 0
state data : Maybe(Response) = none
```

### Type Definition Style

```mint
/* Record types */
type User {
  id : String,
  name : String,
  email : String,
  createdAt : DateTime
}

/* Union types */
type Status {
  pending,
  active,
  suspended,
  deleted
}

/* Generic types */
type ApiResponse<T> {
  data : T,
  success : Bool,
  message : Maybe(String)
}
```

## Code Quality Metrics

### Complexity Guidelines

- **Function length**: Max 50 lines
- **Component length**: Max 200 lines
- **Cyclomatic complexity**: Max 10 per function
- **Parameter count**: Max 5 per function
- **Imports per file**: Max 10

### Refactoring Thresholds

```mint
/* SPLIT when component exceeds 200 lines */
component LargeComponent {
  /* Extract sub-components */
}

/* SPLIT when function exceeds 50 lines */
fun complexFunction() : Void {
  /* Extract into smaller functions */
  fun helper1() : Void { }
  fun helper2() : Void { }
  fun helper3() : Void { }
}
```

## Quality Gate Commands

### Pre-commit Hook

```bash
#!/bin/bash
# .githooks/pre-commit

mint format source/
mint check
```

### CI/CD Pipeline

```yaml
# .github/workflows/mint.yml
name: Mint Quality Gate

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: mint-lang/setup-mint@v1
        with:
          mint-version: '0.28.1'
      - name: Format Check
        run: mint format --check source/
      - name: Type Check
        run: mint check
      - name: Build
        run: mint build --optimize
```

## Anti-Patterns to Avoid

### 1. Deep Nesting

```mint
/* WRONG - Deep nesting */
if condition1 {
  if condition2 {
    if condition3 {
      <div>Deeply nested</div>
    }
  }
}

/* CORRECT - Flat structure with early returns */
if not condition1 {
  return void
}

if not condition2 {
  return void
}

<div>Flat structure</div>
```

### 2. Long Parameter Lists

```mint
/* WRONG - Too many parameters */
fun createUser(
  name : String,
  email : String,
  age : Int,
  address : String,
  phone : String,
  country : String
) : User {
  /* ... */
}

/* CORRECT - Group related parameters */
type UserInput {
  name : String,
  email : String,
  age : Int,
  address : String,
  phone : String,
  country : String
}

fun createUser(input : UserInput) : User {
  /* ... */
}
```

### 3. Magic Numbers

```mint
/* WRONG - Magic numbers */
if items.size > 100 {
  /* ... */
}

/* CORRECT - Named constants */
const MAX_ITEMS = 100

if items.size > MAX_ITEMS {
  /* ... */
}
```

### 4. Duplicate Code

```mint
/* WRONG - Duplicated validation */
fun validateUser1(user : User) : Bool {
  if String.length(user.name) < 3 {
    return false
  }
  if not (String.contains(user.email, "@")) {
    return false
  }
  true
}

/* CORRECT - Extracted validation */
fun validateName(name : String) : Bool {
  String.length(name) >= 3
}

fun validateEmail(email : String) : Bool {
  String.contains(email, "@")
}

fun validateUser(user : User) : Bool {
  validateName(user.name) and validateEmail(user.email)
}
```

## Code Quality Checklist

- [ ] Code is formatted with `mint format`
- [ ] All files pass `mint check`
- [ ] Naming conventions are followed
- [ ] Type annotations are present for complex types
- [ ] No magic numbers (use constants)
- [ ] No deep nesting (max 3 levels)
- [ ] Functions are small and focused
- [ ] Components are properly structured
- [ ] Error handling is comprehensive
- [ ] No commented-out code
- [ ] No TODO comments left in code
- [ ] Documentation is up to date

## Performance Guidelines

### Render Optimization

```mint
/* Use keys in lists */
for item of items {
  <ItemComponent key={item.id} item={item}/>
}

/* Split large components */
component Dashboard {
  fun render : Html {
    <div>
      <Header/>
      <StatsGrid/>
      <RecentActivity/>
      <Footer/>
    </div>
  }
}
```

### Async Best Practices

```mint
/* Handle errors in async functions */
fun loadData() : Promise(Void) {
  try {
    data = await fetchData()
    next data = some(data)
  } catch Error(message) {
    next error = some(message)
  }
}

/* Show loading states */
fun render : Html {
  case data {
    some(d) => <Content data={d}/>
    none =>
      if loading {
        <LoadingSpinner/>
      } else {
        <ErrorDisplay error={error}/>
      }
  }
}
```

## Tooling Integration

### Editor Setup

**VS Code Settings (`.vscode/settings.json`):**
```json
{
  "mint.format.enable": true,
  "mint.check.enable": true,
  "files.associations": {
    "*.mint": "mint"
  }
}
```

### Git Configuration

**`.gitattributes`:**
```
*.mint linguist-language=mint
*.mint filter=fmt
```

**`.git/config` (filter):**
```
[filter "fmt"]
  clean = mint format
  smudge = cat
```
