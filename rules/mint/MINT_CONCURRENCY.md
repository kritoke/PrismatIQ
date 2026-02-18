# Mint Concurrency Rules

## Async/Await Pattern

Always use `async/await` for asynchronous operations in Mint:

```mint
/* CORRECT - Using await */
fun loadData() : Promise(Void) {
  try {
    items = await fetchItems()
    next items = items
  } catch Error(message) {
    next error = some(message)
  }
}

/* INCORRECT - Not handling promise */
fun loadData() : Void {
  fetchItems() /* Promise ignored! */
}
```

## Error Handling

Always wrap async operations in try-catch:

```mint
/* CORRECT - Comprehensive error handling */
fun fetchUser(id : Int) : Promise(Maybe(User)) {
  try {
    response = Http.get("/api/users/#{id}")
    if response.status == 200 {
      some(Json.decode(response.body))
    } else {
      none
    }
  } catch Http.Error(status) {
    Debug.log("HTTP Error: #{status}")
    none
  } catch Json.Error(message) {
    Debug.log("JSON Error: #{message}")
    none
  }
}
```

## Loading States

Always show loading state during async operations:

```mint
component DataLoader {
  state data : Maybe(Array(Item)) = none
  state loading : Bool = false
  state error : Maybe(String) = none

  fun load() : Promise(Void) {
    next loading = true
    next error = none

    try {
      items = await fetchItems()
      next data = some(items)
    } catch Error(message) {
      next error = some(message)
      next data = none
    }

    next loading = false
  }

  fun render : Html {
    <div>
      <button onClick={fun (event : Html.Event) { load() }}>
        {"Load"}
      </button>

      if loading {
        <LoadingSpinner/>
      } else {
        case error {
          some(e) => <ErrorMessage message={e}/>
          none =>
            case data {
              some(d) => <ItemList items={d}/>
              none => <EmptyState/>
            }
        }
      }
    </div>
  }
}
```

## Concurrent Operations

Run independent async operations in parallel:

```mint
/* CORRECT - Parallel execution */
fun loadDashboard() : Promise(Void) {
  try {
    userTask = async fetchUser()
    statsTask = async fetchStats()
    notificationsTask = async fetchNotifications()

    user = await userTask
    stats = await statsTask
    notifications = await notificationsTask

    next dashboard = { user, stats, notifications }
  } catch Error(message) {
    next error = some(message)
  }
}

/* INCORRECT - Sequential execution (slower) */
fun loadDashboard() : Promise(Void) {
  user = await fetchUser()
  stats = await fetchStats()
  notifications = await fetchNotifications()
}
```

## Timeout Handling

Always implement timeouts for blocking operations:

```mint
fun fetchWithTimeout(url : String, timeoutMs : Int) : Promise(Response) {
  response = async Http.get(url)

  /* Wait for response or timeout */
  result = await Promise.race([
    response,
    async sleep(timeoutMs) |> Promise.map(fn (_) { raise TimeoutError })
  ])

  result
}
```

## Request Cancellation

Cancel unnecessary requests:

```mint
store SearchStore {
  state currentQuery : String = ""
  state results : Array(Result) = []
  state loading : Bool = false
  state cancelToken : Maybe(Void -> Void) = none

  fun search(query : String) : Promise(Void) {
    /* Cancel previous request */
    case cancelToken {
      some(cancel) => cancel()
      none => void
    }

    next currentQuery = query
    next loading = true

    /* Store cancellation handler */
    cancelHandler = Promise.cancel

    try {
      /* Make request with cancellation */
      results = await Http.get("/api/search?q=#{query}")
      next results = results
      next cancelToken = none
    } catch Error(message) {
      next results = []
    }

    next loading = false
  }
}
```
