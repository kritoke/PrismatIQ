---
name: mint_readme
description: Mint Language Documentation
---

# Mint Language Documentation

This directory contains comprehensive documentation for working with the Mint programming language in the Roo Code and Beads workflow system.

## Overview

Mint is a refreshing programming language for building single-page web applications. It compiles to JavaScript and features a clean syntax, type inference, built-in state management, and a beautiful UI component library.

**Key Characteristics:**
- Statically typed with full type inference
- Compiles to clean, readable JavaScript
- Built-in state management without external libraries
- 60+ ready-to-use UI components via Mint UI
- CSS-in-Mint styling with scoped styles
- Concurrent-friendly with async/await patterns

## Documentation Files

### Core Language Skills

- **[`MINT_CORE_SKILLS.md`](MINT_CORE_SKILLS.md)** - Core language conventions, syntax, type system, and fundamental concepts
- **[`MINT_UI_INTEGRATION.md`](MINT_UI_INTEGRATION.md)** - Mint UI patterns, theming, and component usage
- **[`MINT_COMMON_PATTERNS.md`](MINT_COMMON_PATTERNS.md)** - Verified working patterns from production code
- **[`MINT_ERRORS.md`](MINT_ERRORS.md)** - Common errors, troubleshooting, and solutions

### Language-Specific Rules

Language-specific rules are located in the [`rules/mint/`](../../rules/mint/) directory:
- **[`MINT_CONCURRENCY.md`](../../rules/mint/MINT_CONCURRENCY.md)** - Async/await patterns, promises, and concurrent operations
- **[`MINT_SECURITY.md`](../../rules/mint/MINT_SECURITY.md)** - Security best practices, input validation, and XSS prevention
- **[`MINT_CODE_REVIEW.md`](../../rules/mint/MINT_CODE_REVIEW.md)** - Code review guidelines and common anti-patterns
- **[`MINT_LINTER_BEST_PRACTICES.md`](../../rules/mint/MINT_LINTER_BEST_PRACTICES.md)** - Code quality standards and linting
- **[`MINT_HEALTH_PROTOCOL.md`](../../rules/mint/MINT_HEALTH_PROTOCOL.md)** - Health checks, verification, and build processes

## Quick Start

### Installation

```bash
# Install Mint (requires aarch64-linux or x86_64-linux)
nix-shell -p mint

# Or download from official source
curl https://mint-lang.com/install | bash
```

### Project Creation

```bash
# Initialize new project
mint init my-app
cd my-app

# Install dependencies
mint install

# Start development server
mint serve

# Build for production
mint build --optimize
```

### Quality Gate

All Mint code must pass:

```bash
# Format code
mint format source/

# Check for errors
mint check

# Build production bundle
mint build --optimize
```

### Anti-Freeze Server Pattern

When starting or restarting a Mint server, use this pattern to prevent hangs:

```bash
# Kill any existing mint processes
pkill -9 -f mint || true

# Clear cache
cd frontend
rm -rf .mint mint-packages.json

# Install fresh
mint install

# Start development server
mint serve
```

### Deadlock Recovery

If `mint serve` hangs during compilation:

1. **Force Cleanup**: `pkill -9 -f mint`
2. **Clear Cache**: `rm -rf frontend/.mint frontend/mint-packages.json`
3. **Debug Run**: Run without background to see error: `mint serve`

## Critical Mint 0.28.1 Patterns

### mint.json Schema

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

### Key Differences from Older Versions

| Old Key | New Key | Notes |
|---------|---------|-------|
| `application.start` | **REMOVED** | Entry point is implicit |
| `source` | `source-directories` | Must be an array |
| `dependencies.version` | `dependencies.repository` + `dependencies.constraint` | New format |

### Component Structure

```mint
component Main {
  fun render : Html {
    <div>Hello, Mint!</div>
  }
}
```

### State Management

```mint
store Counter {
  state count : Int = 0

  fun increment : Void {
    next count = count + 1
  }
}
```

## Naming Conventions

- **Components**: `PascalCase` (e.g., `UserProfile`, `FeedCard`)
- **Stores**: `PascalCase` (e.g., `FeedStore`, `AuthStore`)
- **Functions**: `camelCase` (e.g., `loadItems`, `processData`)
- **Variables**: `camelCase` (e.g., `itemCount`, `isLoading`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `MAX_ITEMS`, `API_URL`)
- **Properties**: `camelCase` (e.g., `itemTitle`, `onClick`)
- **Styles**: `camelCase` (e.g., `base`, `cardContainer`)

## Type System

### Primitive Types

- `Int` - 64-bit integers
- `Float` - 64-bit floating point
- `String` - Unicode strings
- `Bool` - Boolean (`true`, `false`)
- `Void` - Empty/Unit type

### Complex Types

- `Array(T)` - Generic array type
- `Promise(T)` - Asynchronous operations
- `Html` - Mint HTML expressions
- `Result(T, E)` - Error handling

### Type Inference

Mint has full type inference - type annotations are optional for local variables:

```mint
let count = 42  # Inferred as Int
let name = "Hello"  # Inferred as String
let items = []  # Requires annotation: Array(Item)
```

## Ecosystem

### Core Packages

- `mint` - Language compiler and runtime
- `mint-ui` - Official UI component library
- `mint-http` - HTTP requests
- `mint-router` - Client-side routing

### Development Tools

- `mint` CLI - Compiler, formatter, build tool
- VS Code extension - Syntax highlighting, snippets

### Web Frameworks

- Mint's built-in SPA framework (no external framework needed)

### Database

- Backend typically handles data persistence
- Use `mint-http` for API communication

### Testing

- Built-in testing framework
- `mint test` command

## Best Practices

1. **Type Safety**: Use explicit types for function signatures and public APIs
2. **Immutability**: Never mutate state directly; use `next` keyword
3. **Component Organization**: Separate concerns with multiple components
4. **Style Isolation**: Use style blocks for component-specific CSS
5. **Error Handling**: Use `Result` types for operations that can fail
6. **Documentation**: Document complex functions with comments
7. **State Management**: Use stores for shared state across components
8. **Performance**: Use `key` prop in lists for proper reconciliation

## Common Pitfalls

1. **Dynamic Text Syntax**: Use `{ variable }` NOT `<{ variable }>`
2. **State Mutation**: Never use `this.x = value` - use `next x = value`
3. **Old Schema**: Never use `application.start` in mint.json
4. **Missing Type Annotations**: Arrays and complex types need explicit types
5. **Callback Syntax**: Use `fun (event : Html.Event) { ... }` format
6. **Cache Issues**: Delete `.mint` folder when seeing strange errors
7. **Function Shorthand**: `render { }` fails - must use `fun render : Html { }`

## Integration with Roo Code

These skills are designed to work seamlessly with Roo Code's AI workflow system:

1. **Session Start**: Run `bd ready` to find next actionable work
2. **Planning**: Reference specific rules (e.g., "Per MINT_CORE_SKILLS, I will use stores for state")
3. **Implementation**: Follow the quality gate: `mint format && mint check`
4. **Verification**: Use browser testing for web changes
5. **Completion**: Commit and push changes with descriptive messages

## Additional Resources

- [Mint Official Website](https://mint-lang.com)
- [Mint Installation](https://mint-lang.com/install)
- [Mint UI Documentation](https://ui.mint-lang.com)
- [Mint GitHub Repository](https://github.com/mint-lang/mint)
- [Mint UI GitHub](https://github.com/mint-lang/mint-ui)
- [Mint RealWorld Example](https://github.com/mint-lang/mint-realworld)
- [Mint Discord Community](https://discord.gg/NXFUJs2)

## Version

This documentation is designed for Mint 0.28.1+ and follows the latest language conventions and best practices as of 2026.
