# Mint Security Rules

## Input Validation

Validate all user input at the boundary:

```mint
/* CORRECT - Validated input */
component LoginForm {
  state email : String = ""
  state password : String = ""
  state error : Maybe(String) = none

  fun validate() : Bool {
    if String.isEmpty(email) {
      next error = some("Email is required")
      return false
    }

    if not (String.contains(email, "@")) {
      next error = some("Invalid email format")
      return false
    }

    next error = none
    true
  }

  fun handleSubmit(event : Html.Event) : Promise(Void) {
    Html.Event.preventDefault(event)

    if not (validate()) {
      return void
    }

    /* Proceed with login */
  }
}

/* INCORRECT - No validation */
component BadForm {
  state email : String = ""

  fun handleSubmit(event : Html.Event) {
    /* No validation! */
    submitForm(email)
  }
}
```

## XSS Prevention

Never render untrusted HTML without sanitization:

```mint
/* CORRECT - Escaped by default */
<div>{ userProvidedContent }</div>

/* DANGEROUS - Potential XSS */
<a href={url}>Link</a>

/* SAFE - Validated URL */
fun safeUrl(input : String) : String {
  if String.startsWith(input, "http://") or
     String.startsWith(input, "https://") {
    input
  } else {
    "about:blank"
  }
}

<a href={safeUrl(userProvidedUrl)}>Link</a>
```

## Authentication State

Protect sensitive operations with authentication checks:

```mint
store AuthStore {
  state user : Maybe(User) = none
  state token : Maybe(String) = none

  fun requireAuth() : Bool {
    case user {
      some(_) => true
      none => false
    }
  }

  fun getAuthHeaders() : Object {
    case token {
      some(t) => { "Authorization": "Bearer #{t}" }
      none => {}
    }
  }
}

component ProtectedRoute {
  use AuthStore

  fun render : Html {
    if not (@authStore.requireAuth()) {
      <Navigate to="/login"/>
    } else {
      <ProtectedContent/>
    }
  }
}
```

## Sensitive Data Handling

Never log sensitive data:

```mint
/* CORRECT - Safe logging */
store AuthStore {
  fun login(email : String, password : String) : Promise(Void) {
    try {
      response = Http.post("/api/login", body: Json.encode({email: email}))
      /* Log success without sensitive data */
      Debug.log("Login attempt for: #{email}")
    } catch Error {
      Debug.log("Login failed for: #{email}")
    }
  }
}

/* INCORRECT - Logging sensitive data */
store BadStore {
  fun login(email : String, password : String) {
    /* NEVER do this! */
    Debug.log("Login: #{email}, password: #{password}")
  }
}
```

## CSRF Protection

Include CSRF tokens in state-changing requests:

```mint
store CsrfStore {
  state token : Maybe(String) = none

  fun setToken(t : String) {
    next token = some(t)
  }

  fun getToken() : String {
    case token {
      some(t) => t
      none => ""
    }
  }
}

store ApiStore {
  use CsrfStore

  fun postData(url : String, data : Object) : Promise(Response) {
    token = @csrfStore.getToken()

    Http.post(url, body: Json.encode(data))
      |> Http.header("X-CSRF-Token", token)
      |> Http.header("Content-Type", "application/json")
  }
}
```

## Content Security Policy

Configure CSP headers in your server:

```javascript
/* Example CSP headers */
const csp = {
  "Content-Security-Policy": [
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: https:",
    "connect-src 'self' https://api.example.com",
    "frame-ancestors 'none'"
  ].join('; ')
};
```
