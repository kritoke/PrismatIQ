# Mint Code Review Rules

## Mandatory Checks

### 1. State Mutation

```mint
/* VIOLATION - State mutation */
component BadComponent {
  state count : Int = 0

  fun increment() {
    this.count = count + 1  /* WRONG */
  }
}

/* CORRECT - Using next */
component GoodComponent {
  state count : Int = 0

  fun increment() {
    next count = count + 1  /* CORRECT */
  }
}
```

### 2. Dynamic Text Syntax

```mint
/* VIOLATION - Old syntax */
<div><{ name }></div>

/* CORRECT - New syntax */
<div>{ name }</div>
```

### 3. Type Annotations

```mint
/* VIOLATION - Missing type */
let items = []

/* CORRECT - Explicit type */
let items : Array(Item) = []
```

### 4. Render Function

```mint
/* VIOLATION - Missing fun keyword */
render {
  <div>Content</div>
}

/* CORRECT */
fun render : Html {
  <div>Content</div>
}
```

## Review Process

1. **Syntax Check**: Verify all Mint 0.28.1 patterns
2. **Type Check**: Run `mint check`
3. **Security Check**: Validate input handling
4. **Performance Check**: Check for anti-patterns
5. **Style Check**: Ensure consistent formatting

## Common Rejection Reasons

1. State mutation detected
2. Missing type annotations for complex types
3. Insecure input handling
4. Missing error handling in async functions
5. Incorrect dynamic text syntax
