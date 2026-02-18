# Mint Linter Best Practices

## Mandatory Formatting

Always run formatter before committing:

```bash
mint format source/
```

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Components | PascalCase | `UserCard`, `FeedGrid` |
| Stores | PascalCase | `UserStore`, `FeedStore` |
| Functions | camelCase | `loadItems`, `fetchData` |
| Variables | camelCase | `itemCount`, `isLoading` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_ITEMS`, `API_URL` |
| Styles | camelCase | `base`, `headerSection` |
| Properties | camelCase | `title`, `itemCount` |

## Type Annotations Required

```mint
/* Arrays must have type annotations */
let items : Array(Item) = []

/* Complex types must be annotated */
type User {
  name : String,
  email : String
}

let users : Array(User) = []

/* Function parameters and returns */
fun process(input : String) : Promise(Result) {
  /* ... */
}
```

## Component Structure

```mint
component Example {
  /* Properties first */
  property title : String
  property items : Array(Item)

  /* State next */
  state loading : Bool = false

  /* Functions */
  fun load() : Promise(Void) {
    /* ... */
  }

  /* Styles */
  style base {
    padding: 16px;
  }

  /* Render last */
  fun render : Html {
    <div::base>{ title }</div>
  }
}
```

## Anti-Patterns

1. **Magic numbers**: Use constants
2. **Deep nesting**: Max 3 levels
3. **Long functions**: Max 50 lines
4. **Missing keys**: Always use keys in lists
5. **Inline styles**: Use style blocks
