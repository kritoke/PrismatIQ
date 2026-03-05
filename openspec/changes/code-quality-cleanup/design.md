## Context

The codebase has 45 remaining Ameba linting issues:
- 9 CyclomaticComplexity issues (methods exceeding 12-point threshold)
- ~24 Style/RedundantNilInControlExpression issues
- 7 Style/RedundantBegin issues
- 4 Lint/UselessAssign issues

The v0.5.0 release is ready with 222 passing tests. These are code quality improvements that can be addressed in a future release.

## Goals / Non-Goals

**Goals:**
- Reduce cyclomatic complexity in 9 methods to meet the 12-point threshold
- Fix remaining stylistic issues (redundant nil checks, begin blocks, unused variables)
- Improve code readability and maintainability
- No breaking changes - all internal refactoring

**Non-Goals:**
- No new functionality
- No API changes
- No performance optimizations (these are code structure improvements only)
- Not addressing all Ameba issues - just the complexity ones

## Decisions

### Approach 1: Extract Methods (Preferred)
Split complex methods into smaller, focused helper methods.

**Example:**
```crystal
# Before (complex)
def extract_from_ico(...)
  # 50+ lines of nested logic
end

# After (refactored)
def extract_from_ico(...)
  validate_header
  find_best_entry
  extract_pixel_data
end
```

**Pros:** Improves readability, testability
**Cons:** More methods, slight increase in code size

### Approach 2: Use Case Statements with Guards
Replace nested if/else with early returns.

**Pros:** Reduces nesting, clearer control flow
**Cons:** May require restructuring existing logic

### Approach 3: Extract to Helper Classes/Modules
Move complex logic to separate modules.

**Pros:** Very clean main code
**Cons:** Over-engineering for some cases

**Decision:** Use Approach 1 (Extract Methods) as primary strategy, with Approach 2 for control flow improvements.

## Risks / Trade-offs

- **[Risk] Regression** → Mitigation: Run full test suite after each method refactoring
- **[Risk] Breaking existing behavior** → Mitigation: No API changes, only internal restructuring
- **[Risk] Over-engineering** → Mitigation: Only refactor methods that exceed complexity threshold
- **[Trade-off] More files/methods** → Acceptable: Improved maintainability outweighs slight increase in code structure

## Open Questions

1. Should we target zero Ameba issues or just the complexity ones?
2. Should complexity refactoring be done in a single PR or spread across multiple?
3. Should we add CI checks to prevent complexity from increasing again?