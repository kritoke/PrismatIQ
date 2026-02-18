# Mint Common Patterns

Verified working patterns from production QuickHeadlines code. These patterns are guaranteed to work with Mint 0.28.1.

## Component Structure

### Minimal Component

```mint
component Main {
  fun render : Html {
    <div>QuickHeadlines</div>
  }
}
```

### Component with Properties

```mint
component FeedCard {
  property item : TimelineItem

  fun render : Html {
    <div class="feed-card">
      <h3>{ item.title }</h3>
      <span>{ item.pubDate }</span>
    </div>
  }
}
```

### Component with State

```mint
component Timeline {
  state items : Array(TimelineItem) = []
  state loading : Bool = false

  fun loadItems : Promise(Void) {
    next loading = true
    next items = []
    try {
      items = await fetchItems()
      next items = items
    } catch Error {
      Debug.log("Failed to load items")
    }
    next loading = false
  }

  fun render : Html {
    <div class="timeline">
      if loading {
        <LoadingSpinner/>
      } else {
        for item of items {
          <FeedCard item={item}/>
        }
      }
    </div>
  }
}
```

## Dynamic Text Patterns

### String Variable

```mint
<div>{ name }</div>
<div>{ user.email }</div>
<div>{ item.title }</div>
```

### Static String

```mint
<div>{"QuickHeadlines"}</div>
<div>{"Loading..."}</div>
<div>{"No items found"}</div>
```

### Property Access

```mint
<div>{ source.name }</div>
<div>{ item.feedTitle }</div>
<div>{ user.profile.displayName }</div>
```

### Dynamic + Static Combined

```mint
<div>{"Posted by #{item.author}"}</div>
<div>{"#{count} items"}</div>
```

## Dynamic Styles

### Inline Style with Variable

```mint
<div style="background-color: {item.headerColor}">
  Content
</div>

<img src={item.favicon} alt={item.feedTitle}/>
```

### Multiple Dynamic Values

```mint
<div
  style="color: {textColor}; background: {bgColor}; padding: {padding}px"
>
  Content
</div>
```

### Conditional Class

```mint
<div class={isActive ? "active" : "inactive"}>
  Content
</div>
```

## For Loops

### Rendering Array Items

```mint
for article of source.articles {
  <FeedCard item={article}/>
}
```

### With Index

```mint
for item of items {
  <div index={index}>
    { item.title }
  </div>
}
```

### Nested Loops

```mint
for feed of feeds {
  <FeedBox source={feed}/>
}
```

## Style Blocks

### Basic Style

```mint
style base {
  background: #272729;
  border: 1px solid #343536;
  border-radius: 8px;
  display: flex;
  flex-direction: column;
  height: 500px;
  overflow: hidden;
}
```

### Multiple Styles

```mint
style container {
  padding: 16px;
  margin-bottom: 20px;
}

style title {
  font-size: 16px;
  font-weight: 600;
  color: #111827;
}

style meta {
  font-size: 12px;
  color: #9ca3af;
}
```

### Media Queries

```mint
style gridContainer {
  display: grid;
  gap: 20px;
  padding: 20px;
  height: calc(100vh - 80px);
  overflow-y: auto;
  position: relative;
  grid-template-columns: repeat(3, 1fr);

  @media (max-width: 1100px) {
    grid-template-columns: repeat(2, 1fr);
  }

  @media (max-width: 700px) {
    grid-template-columns: 1fr;
  }
}
```

### Hover States

```mint
style card {
  background: #ffffff;
  border-radius: 8px;
  transition: all 0.2s ease;

  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  }
}
```

## CSS Classes with :: Syntax

### Single Style Reference

```mint
<div::box>
  Content
</div>
```

### Multiple Style References

```mint
<div::base::hoverable::clickable>
  Content
</div>
```

### With Data Attributes

```mint
<div::box data-name="feed-box">
  Content
</div>
```

## Production Components

### FeedCard Component

```mint
component FeedCard {
  property item : TimelineItem

  style base {
    display: flex;
    gap: 12px;
    padding: 16px;
    background: #ffffff;
    border-radius: 8px;
  }

  style favicon-container {
    flex-shrink: 0;
    width: 40px;
    height: 40px;
    border-radius: 6px;
  }

  style content {
    flex: 1;
    min-width: 0;
  }

  style title {
    font-size: 16px;
    font-weight: 600;
    color: #111827;
  }

  style meta {
    font-size: 12px;
    color: #9ca3af;
  }

  fun render : Html {
    <a href={item.link} target="_blank" rel="noopener noreferrer">
      <div::base>
        <div::favicon-container style="background-color: {item.headerColor}">
          <img::favicon src={item.favicon} alt={item.feedTitle}/>
        </div>
        <div::content>
          <h3::title>
            { item.title }
          </h3>
          <div::meta>
            { item.pubDate }
          </div>
        </div>
      </div>
    </a>
  }
}
```

### FeedBox Component

```mint
component FeedBox {
  property source : FeedSource

  style box {
    background: #272729;
    border: 1px solid #343536;
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    height: 500px;
    overflow: hidden;
  }

  style header {
    padding: 12px;
    font-weight: bold;
    border-bottom: 1px solid #343536;
    background: #1a1a1b;
  }

  style itemsList {
    flex: 1;
    overflow-y: auto;
  }

  fun render : Html {
    <div::box data-name="feed-box">
      <div::header>
        { source.name }
      </div>
      <div::itemsList>
        for article of source.articles {
          <FeedCard item={article}/>
        }
      </div>
    </div>
  }
}
```

### FeedGrid with Responsive Layout

```mint
component FeedGrid {
  property feeds : Array(FeedSource)

  style gridContainer {
    display: grid;
    gap: 20px;
    padding: 20px;
    height: calc(100vh - 80px);
    overflow-y: auto;
    position: relative;
    grid-template-columns: repeat(3, 1fr);

    @media (max-width: 1100px) {
      grid-template-columns: repeat(2, 1fr);
    }

    @media (max-width: 700px) {
      grid-template-columns: 1fr;
    }
  }

  style bottomShadow {
    position: fixed;
    bottom: 0;
    left: 0;
    right: 0;
    height: 60px;
    pointer-events: none;
    z-index: 100;
    background: linear-gradient(transparent, rgba(0,0,0,0.8));
  }

  fun render : Html {
    <div::gridContainer data-name="feed-grid-root">
      for feed of feeds {
        <FeedBox source={feed}/>
      }
      <div::bottomShadow/>
    </div>
  }
}
```

## State Management

### Store Definition

```mint
store FeedStore {
  state feeds : Array(FeedSource) = []
  state loading : Bool = false
  state error : Maybe(String) = none

  fun loadFeeds : Promise(Void) {
    next loading = true
    next error = none
    try {
      feeds = await Api.fetchFeeds()
      next feeds = feeds
    } catch Error(message) {
      next error = some(message)
    }
    next loading = false
  }

  fun refreshFeed(feedId : String) : Promise(Void) {
    try {
      updatedFeed = await Api.refreshFeed(feedId)
      next feeds = feeds
        |> Array.map(fn (feed) {
          if feed.id == feedId { updatedFeed } else { feed }
        })
    } catch Error(message) {
      Debug.log("Failed to refresh: #{message}")
    }
  }
}
```

### Using Store in Component

```mint
component App {
  use FeedStore

  fun mount : Void {
    @feedStore.loadFeeds()
  }

  fun render : Html {
    <div class="app">
      <Header/>
      if @feedStore.loading {
        <LoadingSpinner/>
      } else {
        case @feedStore.error {
          some(error) => <ErrorMessage message={error}/>
          none => <FeedGrid feeds={@feedStore.feeds}/>
        }
      }
    </div>
  }
}
```

## API Calls

### HTTP GET

```mint
fun fetchItems() : Promise(Array(Item)) {
  response = Http.get("/api/items")
  body = Json.decode(response.body)
  body.items
}
```

### HTTP POST

```mint
fun createItem(item : Item) : Promise(Item) {
  body = Json.encode(item)
  response = Http.post("/api/items", body: body)
  Json.decode(response.body)
}
```

### With Headers

```mint
fun fetchAuthenticated() : Promise(Data) {
  response =
    Http.get("/api/protected")
    |> Http.header("Authorization", "Bearer #{token}")

  Json.decode(response.body)
}
```

## Conditional Rendering

### Simple If

```mint
if isLoading {
  <LoadingSpinner/>
}
```

### If-Else

```mint
if isLoading {
  <LoadingSpinner/>
} else {
  <Content/>
}
```

### Case Pattern

```mint
case user {
  some(u) => <UserCard user={u}/>
  none => <LoginPrompt/>
}
```

### Case with Multiple Branches

```mint
case status {
  "active" => <ActiveBadge/>
  "pending" => <PendingBadge/>
  "blocked" => <BlockedBadge/>
  _ => <UnknownBadge/>
}
```

## Type Definitions

### Record Type

```mint
type User {
  id : String,
  name : String,
  email : String,
  avatar : String
}
```

### Using Custom Type

```mint
state user : Maybe(User) = none

<Card>
  { case user {
      some(u) => <UserInfo user={u}/>
      none => <AnonymousCard/>
    } }
</Card>
```

## Error Handling

### Try-Catch

```mint
fun loadData() : Promise(Void) {
  try {
    data = await fetchData()
    next data = data
  } catch Error(message) {
    next error = some(message)
    Debug.log("Error loading data: #{message}")
  }
}
```

### Maybe Pattern

```mint
state result : Maybe(String) = none

<div>
  { case result {
      some(message) => <Success message={message}/>
      none => <span>{"Waiting..."}</span>
    } }
</div>
```

## Event Handling

### Basic Click Handler

```mint
<button onClick={fun (event : Html.Event) { handleClick() }}>
  {"Click Me"}
</button>
```

### With Event Data

```mint
<input
  onChange={fun (event : Html.Event) {
    value = Html.Event.targetValue(event)
    next inputValue = value
  }}
/>
```

### Form Submit

```mint
<form onSubmit={fun (event : Html.Event) {
  Html.Event.preventDefault(event)
  handleSubmit()
}}>
  <input type="text" name="email"/>
  <button type="submit">{"Submit"}</button>
</form>
```

## Navigation

### Link Component

```mint
<a href="/about" target="_self">
  {"About"}
</a>

<a href={article.link} target="_blank" rel="noopener noreferrer">
  { article.title }
</a>
```

## Syntax Summary Table

| What | Syntax | Example |
|------|--------|---------|
| Render function | `fun render : Html { }` | `fun render : Html { <div>Text</div> }` |
| String variable | `{ variable }` | `{ item.title }` |
| Static string | `{"text"}` | `{"QuickHeadlines"}` |
| Property access | `{ object.property }` | `{ source.name }` |
| Inline style | `style="prop: {val}"` | `style="color: {color}"` |
| Style reference | `::styleName` | `<div::base>` |
| For loop | `for item of array { }` | `for article of articles { }` |
| CSS block | `style name { }` | `style base { color: red; }` |
| Media query | `@media (max-width) { }` | `@media (max-width: 700px) { ... }` |
| State change | `next state = value` | `next loading = True` |
| If-else | `if cond { } else { }` | `if loading { <Spinner/> } else { <Content/> }` |
| Case match | `case value { }` | `case user { some(u) => ... none => ... }` |
