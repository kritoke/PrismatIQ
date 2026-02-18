# Mint 0.28.1 Core Skills

This guide covers the fundamental Mint language concepts, syntax, and conventions for building web applications.

## Language Fundamentals

### Component Structure

Components are the building blocks of Mint applications. Every component must define a `render` function that returns HTML.

```mint
component Main {
  fun render : Html {
    <div>
      <h1>{ "Hello, Mint!" }</h1>
    </div>
  }
}
```

### Properties

Components can accept properties to make them reusable and configurable.

```mint
component UserCard {
  property name : String
  property email : String
  property avatar : String

  fun render : Html {
    <div class="user-card">
      <img src={avatar} alt={name}/>
      <h3>{ name }</h3>
      <p>{ email }</p>
    </div>
  }
}
```

**Usage:**
```mint
<UserCard
  name="John Doe"
  email="john@example.com"
  avatar="/images/john.jpg"
/>
```

### State Management

Mint has a built-in state management system using stores. State is immutable - use the `next` keyword to update state.

```mint
store Counter {
  state count : Int = 0
  state items : Array(String) = []

  fun increment : Void {
    next count = count + 1
  }

  fun addItem(item : String) : Void {
    next items = items + [item]
  }

  fun reset : Void {
    next count = 0
    next items = []
  }
}
```

**Using a store in a component:**
```mint
component CounterDisplay {
  use Counter

  fun render : Html {
    <div>
      <p>{"Count: #{ @counter.count }"}</p>
      <button onClick={fun (event : Html.Event) { @counter.increment() }}>
        {"Increment"}
      </button>
    </div>
  }
}
```

### Functions

Define reusable functions within components or modules.

```mint
component MathUtils {
  fun add(a : Int, b : Int) : Int {
    a + b
  }

  fun greet(name : String) : String {
    "Hello, #{name}!"
  }

  fun process(items : Array(Int)) : Int {
    items
      |> Array.filter(fn (item) { item > 0 })
      |> Array.map(fn (item) { item * 2 })
      |> Array.reduce(0, fn (acc, item) { acc + item })
  }
}
```

## HTML and Dynamic Content

### Static HTML

```mint
fun render : Html {
  <div class="container">
    <header>
      <h1>{"My App"}</h1>
    </header>
    <main>
      <p>{"Welcome to my application"}</p>
    </main>
    <footer>
      <span>{"2026"}</span>
    </footer>
  </div>
}
```

### Dynamic Text

**CORRECT - Use { } for dynamic content:**
```mint
<div>{ user.name }</div>
<div>{"Hello, #{name}"}</div>
<div>{"Item count: #{count}"}</div>
```

**INCORRECT - Will cause errors:**
```mint
<div><{ user.name }></div>
<div>#{name}</div>
```

### Dynamic Attributes

```mint
<img src={user.avatar} alt={user.name}/>
<a href={article.link} target="_blank">{article.title}</a>
<button class={isActive ? "active" : "inactive"}>{"Click"}</button>
<div style="color: #{theme.primary}; font-size: #{size}px">
  Content
</div>
```

### Conditional Rendering

```mint
fun render : Html {
  <div>
    <h1>{"User Profile"}</h1>
    <p>
      { if user.isOnline {
          "Online"
        } else {
          "Offline"
        } }
    </p>
  </div>
}
```

### Lists and Loops

```mint
component FeedList {
  property articles : Array(Article)

  fun render : Html {
    <div class="feed">
      for article of articles {
        <ArticleCard article={article}/>
      }
    </div>
  }
}
```

**With index:**
```mint
for article of articles {
  <div index={index}>
    { article.title }
  </div>
}
```

## CSS Styling

### Style Blocks

Define component-specific styles using style blocks:

```mint
component Card {
  property title : String

  style base {
    background: #ffffff;
    border: 1px solid #e5e7eb;
    border-radius: 8px;
    padding: 16px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  }

  style title {
    font-size: 18px;
    font-weight: 600;
    color: #111827;
    margin-bottom: 8px;
  }

  style hoverable {
    &:hover {
      box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    }
  }

  fun render : Html {
    <div::base::hoverable>
      <h3::title>{ title }</h3>
      { children }
    </div>
  }
}
```

### Responsive Styles

```mint
style container {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 20px;
  padding: 20px;

  @media (max-width: 1100px) {
    grid-template-columns: repeat(2, 1fr);
  }

  @media (max-width: 700px) {
    grid-template-columns: 1fr;
  }
}
```

### CSS Variables

```mint
component Theme {
  style base {
    --primary-color: #3b82f6;
    --secondary-color: #10b981;
    --background: #f9fafb;
    color: #111827;
  }

  style button {
    background: var(--primary-color);
    color: white;
    padding: 8px 16px;
    border-radius: 6px;
  }
}
```

## Type System

### Primitive Types

```mint
state name : String = "John"
state age : Int = 30
state price : Float = 19.99
state isActive : Bool = true
state data : Void = void
```

### Complex Types

```mint
type UserId = Int

type User {
  name : String,
  email : String,
  age : Int
}

type Response {
  data : Array(Item),
  total : Int,
  page : Int
}

state items : Array(Item) = []
state user : Maybe(User) = none
state result : Result(String, String) = ok("")
```

### Generic Types

```mint
store ApiResponse<T> {
  state data : T
  state loading : Bool = false
  state error : Maybe(String) = none

  fun load : Promise(Void) {
    next loading = true
    try {
      response = Http.get("/api/data")
      next data = Json.decode(response.body)
      next error = none
    } catch Http.Error {
      next error = some("Failed to fetch data")
    }
    next loading = false
  }
}
```

### Type Aliases

```mint
type UserId = Int
type ArticleId = String
type DateTime = String

type User {
  id : UserId,
  name : String,
  email : String
}
```

## Module Organization

### Multiple Components in One File

```mint
component Button {
  property label : String
  property onClick : Fun(Html.Event, Void)

  style base {
    padding: 8px 16px;
    background: #3b82f6;
    color: white;
    border-radius: 6px;
    border: none;
    cursor: pointer;
  }

  fun render : Html {
    <button::base onClick={onClick}>
      { label }
    </button>
  }
}

component IconButton {
  property icon : String
  property label : String
  property onClick : Fun(Html.Event, Void)

  style base {
    padding: 8px;
    background: transparent;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    cursor: pointer;
  }

  fun render : Html {
    <button::base onClick={onClick} title={label}>
      <i class={icon}></i>
    </button>
  }
}
```

### Separate Files

```
source/
├── Main.mint
├── Components/
│   ├── Button.mint
│   ├── Card.mint
│   └── Modal.mint
├── Stores/
│   ├── UserStore.mint
│   └── CartStore.mint
└── Utils/
    └── Formatters.mint
```

## Async Operations

### Promise Type

```mint
fun fetchUser(id : Int) : Promise(User) {
  response = Http.get("/api/users/#{id}")
  Json.decode(response.body)
}

fun saveUser(user : User) : Promise(Result(User, String)) {
  try {
    response = Http.post("/api/users", body: Json.encode(user))
    result = Json.decode(response.body)
    ok(result)
  } catch Http.Error(message) {
    err("Failed: #{message}")
  }
}
```

### Await Pattern

```mint
component UserProfile {
  state user : Maybe(User) = none
  state loading : Bool = false

  fun loadUser(id : Int) : Promise(Void) {
    next loading = true
    try {
      user = await fetchUser(id)
      next user = some(user)
    } catch Error {
      next user = none
    }
    next loading = false
  }

  fun render : Html {
    case user {
      some(u) => <UserCard user={u}/>
      none => <LoadingSpinner/>
    }
  }
}
```

## Error Handling

### Maybe Type

```mint
state user : Maybe(User) = none

<div>
  { case user {
      some(u) => <UserCard user={u}/>
      none => <div>{"No user found"}</div>
    } }
</div>
```

### Result Type

```mint
fun parseNumber(input : String) : Result(Int, String) {
  try {
    number = Int.fromString(input)
    ok(number)
  } catch String.ToIntError {
    err("Invalid number: #{input}")
  }
}

state result : Result(Int, String) = ok(0)

fun handleSubmit(event : Html.Event) : Promise(Void) {
  input = Html.Event.target(event)
  next result = parseNumber(input.value)
}
```

## Guards for AI Agents

Copy this guardrail into prompts:

```
Mint 0.28.1 Configuration Guardrail:
- mint.json must be FLAT - no "application.start" key
- Use "source-directories" (plural array), NOT "source"
- Dependencies use "repository" + "constraint" format
- Component render function: fun render : Html { }
- Dynamic text: { variable } NOT <{ variable }>
- State changes: next state = value NOT mutation
- Entry point: component named "Main" in source-directories
- CSS styles: style name { } with ::base syntax
- For loops: for item of array { }
- Reference: github.com/mint-lang/mint-website as template
```
