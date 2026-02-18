# Mint Concurrency

This guide covers async/await patterns, promises, and concurrent operations in Mint applications.

## Promise Type

Mint uses the `Promise` type for asynchronous operations.

### Basic Promise Declaration

```mint
/* Returns a promise that resolves to a String */
fun fetchData() : Promise(String) {
  "async result"
}

/* Returns a promise that resolves to a custom type */
fun fetchUser(id : Int) : Promise(User) {
  response = Http.get("/api/users/#{id}")
  Json.decode(response.body)
}
```

### Promise States

```mint
/* Pending state */
state data : Maybe(String) = none

/* Resolved state */
state user : Maybe(User) = some(user)

/* Rejected state - handled via try-catch */
state error : Maybe(String) = none
```

## Async/Await Pattern

### Basic Async Function

```mint
component UserProfile {
  state user : Maybe(User) = none
  state loading : Bool = false

  fun loadUser(id : Int) : Promise(Void) {
    next loading = true
    next user = none

    try {
      /* await suspends execution until promise resolves */
      user = await fetchUser(id)
      next user = some(user)
    } catch Error(message) {
      next user = none
      Debug.log("Error: #{message}")
    }

    next loading = false
  }

  fun render : Html {
    case user {
      some(u) => <UserCard user={u}/>
      none =>
        if loading {
          <LoadingSpinner/>
        } else {
          <ErrorMessage message="User not found"/>
        }
    }
  }
}
```

### Multiple Async Operations

```mint
/* Sequential execution */
fun loadUserData() : Promise(Void) {
  try {
    user = await fetchUser(currentUserId)
    profile = await fetchProfile(user.id)
    posts = await fetchPosts(user.id)
    next data = { user, profile, posts }
  } catch Error(message) {
    next error = some(message)
  }
}

/* Parallel execution */
fun loadAllData() : Promise(Void) {
  try {
    /* Start all requests simultaneously */
    user = async fetchUser(currentUserId)
    posts = async fetchPosts(currentUserId)
    notifications = async fetchNotifications()

    /* Wait for all to complete */
    userResult = await user
    postsResult = await posts
    notificationsResult = await notifications

    next data = { userResult, postsResult, notificationsResult }
  } catch Error(message) {
    next error = some(message)
  }
}
```

## HTTP Requests

### GET Requests

```mint
fun getItems() : Promise(Array(Item)) {
  response = Http.get("/api/items")
  body = Json.decode(response.body)
  body.items
}

fun getItem(id : String) : Promise(Maybe(Item)) {
  response = Http.get("/api/items/#{id}")
  if response.status == 200 {
    some(Json.decode(response.body))
  } else {
    none
  }
}
```

### POST Requests

```mint
fun createItem(item : Item) : Promise(Item) {
  body = Json.encode(item)
  response = Http.post("/api/items", body: body)
  response
    |> Http.header("Content-Type", "application/json")
    |> Json.decode(response.body)
}
```

### PUT/PATCH Requests

```mint
fun updateItem(id : String, item : Item) : Promise(Item) {
  body = Json.encode(item)
  response = Http.put("/api/items/#{id}", body: body)
  Json.decode(response.body)
}

fun partialUpdate(id : String, data : Object) : Promise(Item) {
  body = Json.encode(data)
  response = Http.patch("/api/items/#{id}", body: body)
  Json.decode(response.body)
}
```

### DELETE Requests

```mint
fun deleteItem(id : String) : Promise(Bool) {
  response = Http.delete("/api/items/#{id}")
  response.status == 200
}
```

### Request with Headers

```mint
fun fetchAuthenticated(url : String, token : String) : Promise(Response) {
  Http.get(url)
    |> Http.header("Authorization", "Bearer #{token}")
    |> Http.header("Accept", "application/json")
}

fun fetchWithRetry(url : String, maxRetries : Int) : Promise(Response) {
  try {
    response = Http.get(url)
    response
  } catch Http.Error {
    if maxRetries > 0 {
      await sleep(1000)
      await fetchWithRetry(url, maxRetries - 1)
    } else {
      raise Error("Max retries exceeded")
    }
  }
}
```

## Error Handling with Try-Catch

### Basic Error Handling

```mint
fun fetchData() : Promise(Void) {
  try {
    response = Http.get("/api/data")
    data = Json.decode(response.body)
    next data = data
  } catch Http.Error(status) {
    next error = some("HTTP Error: #{status}")
  } catch Json.Error(message) {
    next error = some("JSON Error: #{message}")
  } catch Error(message) {
    next error = some("Error: #{message}")
  }
}
```

### Result Type Pattern

```mint
type Result<T> {
  ok : T,
  error : Maybe(String)
}

fun safeFetch() : Promise(Result(Array(Item))) {
  try {
    response = Http.get("/api/items")
    ok(Result:ok(Json.decode(response.body)))
  } catch Error(message) {
    ok(Result:error(some(message)))
  }
}

/* Usage */
fun loadItems() : Promise(Void) {
  try {
    result = await safeFetch()
    case result.error {
      some(e) => next error = some(e)
      none => next items = result.ok
    }
  } catch Error(message) {
    next error = some(message)
  }
}
```

## Loading States

### Simple Loading State

```mint
component DataLoader {
  state data : Maybe(Array(Item)) = none
  state loading : Bool = false

  fun load() : Promise(Void) {
    next loading = true
    try {
      items = await fetchItems()
      next data = some(items)
    } catch Error {
      next data = none
    }
    next loading = false
  }

  fun render : Html {
    <div>
      <button onClick={fun (event : Html.Event) { load() }}>
        {"Load Data"}
      </button>

      if loading {
        <LoadingSpinner/>
      } else {
        case data {
          some(items) => <ItemList items={items}/>
          none => <p>{"No data"}</p>
        }
      }
    </div>
  }
}
```

### Progressive Loading

```mint
component InfiniteScroll {
  state items : Array(Item) = []
  state page : Int = 1
  state loading : Bool = false
  state hasMore : Bool = true

  fun loadMore() : Promise(Void) {
    if loading or not hasMore {
      return void
    }

    next loading = true

    try {
      newItems = await fetchItems(page)
      if Array.isEmpty(newItems) {
        next hasMore = false
      } else {
        next items = items + newItems
        next page = page + 1
      }
    } catch Error {
      Debug.log("Failed to load more items")
    }

    next loading = false
  }

  fun render : Html {
    <div>
      <ItemList items={items}/>

      if loading {
        <LoadingSpinner/>
      } else if hasMore {
        <button onClick={fun (event : Html.Event) { loadMore() }}>
          {"Load More"}
        </button>
      }
    </div>
  }
}
```

## Debouncing and Throttling

### Debounce Function

```mint
component SearchInput {
  state query : String = ""
  state results : Array(Result) = []
  state searching : Bool = false

  fun debounceSearch(input : String, delay : Int) : Promise(Void) {
    next query = input

    /* Wait for user to stop typing */
    await sleep(delay)

    /* Check if query hasn't changed */
    if input == query {
      next searching = true
      try {
        results = await searchApi(input)
        next results = results
      } catch Error {
        next results = []
      }
      next searching = false
    }
  }

  fun handleInput(event : Html.Event) {
    value = Html.Event.targetValue(event)
    debounceSearch(value, 300)
  }

  fun render : Html {
    <div>
      <input
        type="text"
        onChange={handleInput}
        placeholder="Search..."
      />
      if searching {
        <LoadingSpinner/>
      } else {
        <ResultsList results={results}/>
      }
    </div>
  }
}
```

## Concurrent Store Operations

### Store with Async Actions

```mint
store ApiStore {
  state data : Maybe(Array(Item)) = none
  state loading : Bool = false
  state error : Maybe(String) = none

  fun loadItems() : Promise(Void) {
    next loading = true
    next error = none

    try {
      items = await Http.get("/api/items")
        |> Json.decode()
        |> .items

      next data = some(items)
    } catch Error(message) {
      next error = some(message)
      next data = none
    }

    next loading = false
  }

  fun refreshItems() : Promise(Void) {
    next loading = true

    try {
      items = await Http.get("/api/items")
        |> Json.decode()
        |> .items

      next data = some(items)
      next error = none
    } catch Error(message) {
      next error = some(message)
    }

    next loading = false
  }
}
```

### Multiple Store Coordination

```mint
store UserStore {
  state user : Maybe(User) = none
  state loading : Bool = false

  fun loadUser() : Promise(Void) {
    next loading = true
    try {
      user = await fetchUser()
      next user = some(user)
    } catch Error {
      next user = none
    }
    next loading = false
  }
}

store FeedStore {
  state feed : Maybe(Feed) = none
  state loading : Bool = false

  fun loadFeed(userId : Int) : Promise(Void) {
    next loading = true
    try {
      feed = await fetchFeed(userId)
      next feed = some(feed)
    } catch Error {
      next feed = none
    }
    next loading = false
  }
}

component Dashboard {
  use UserStore
  use FeedStore

  fun mount : Void {
    try {
      await @userStore.loadUser()
      case @userStore.user {
        some(u) => await @feedStore.loadFeed(u.id)
        none => void
      }
    } catch Error(message) {
      Debug.log("Dashboard load failed: #{message}")
    }
  }

  fun render : Html {
    <div>
      if @userStore.loading or @feedStore.loading {
        <LoadingSpinner/>
      } else {
        <UserCard user={@userStore.user}/>
        <FeedList feed={@feedStore.feed}/>
      }
    </div>
  }
}
```

## Best Practices

1. **Always Handle Errors**: Use try-catch for all async operations
2. **Set Loading States**: Update loading state before and after async calls
3. **Cancel Unneeded Requests**: Consider implementing request cancellation
4. **Use Result Types**: Return structured results for better error handling
5. **Debounce User Input**: Prevent excessive API calls from user input
6. **Parallel When Possible**: Execute independent async calls concurrently
7. **Timeout Long Requests**: Set timeouts to prevent hanging requests
8. **Test Async Code**: Verify error handling paths in tests

## Common Pitfalls

1. **Unhandled Promises**: Always await or handle promises
2. **Memory Leaks**: Clean up subscriptions and event listeners
3. **Race Conditions**: Handle cases where responses arrive out of order
4. **Missing Loading States**: UI feels unresponsive without feedback
5. **Silent Failures**: Always log or display async errors
6. **Too Many Requests**: Implement debouncing/throttling for user input
7. **Blocking the UI**: Keep async operations async, don't synchronously wait
