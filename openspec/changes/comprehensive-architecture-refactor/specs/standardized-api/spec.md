## ADDED Requirements

### Requirement: Clean, consistent public API with minimal overloads
The system SHALL provide a clean, consistent public API with minimal method overloads, using `Options` parameter objects and `Result` return types consistently across all methods to improve developer experience and reduce confusion.

#### Scenario: Primary API uses Options parameter exclusively
- **WHEN** calling `get_palette` method
- **THEN** it accepts only `Options` parameter object instead of multiple keyword arguments

#### Scenario: All public methods use Result return type
- **WHEN** calling any public palette extraction method
- **THEN** it returns `Result(Array(RGB), String)` for explicit error handling

#### Scenario: Deprecated methods include clear migration guidance
- **WHEN** calling deprecated methods with keyword arguments
- **THEN** they include `@[Deprecated]` annotations with clear migration instructions

#### Scenario: Minimal API surface reduces cognitive load
- **WHEN** examining the public API documentation
- **THEN** there are fewer than 10 core public methods instead of dozens of overloads

#### Scenario: Consistent naming and parameter patterns
- **WHEN** using different methods in the public API
- **THEN** they follow consistent naming conventions and parameter patterns

#### Scenario: No ambiguous sentinel values in API
- **WHEN** examining return values from public APIs
- **THEN** no methods return `[RGB.new(0, 0, 0)]` as error sentinel