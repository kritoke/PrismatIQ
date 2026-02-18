# Mint Security

This guide covers security best practices, input validation, and XSS prevention for Mint applications.

## Cross-Site Scripting (XSS)

### Understanding XSS in Mint

Mint provides some built-in protection, but developers must still be vigilant.

### Safe Dynamic Text Rendering

```mint
/* SAFE - Mint escapes content in { } */
<div>{ userInput }</div>
<div>{ user.name }</div>
```

### Dangerous Patterns to Avoid

```mint
/* DANGEROUS - Never do this */
<a href={userProvidedUrl}>Link</a>

/* If userProvidedUrl is "javascript:alert('xss')", it will execute */

/* SAFE - Validate and sanitize */
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

### Event Handler Safety

```mint
/* SAFE - Functions are not executable */
<button onClick={handleClick}>
  {"Click Me"}
</button>

/* DANGEROUS - Never pass user input to onClick */
<button onClick={userProvidedFunctionName}>
  {"Click"}
</button>
```

## Input Validation

### Validate All User Input

```mint
/* Email Validation */
fun isValidEmail(email : String) : Bool {
  String.contains(email, "@") and
  String.contains(email, ".") and
  String.length(email) > 5
}

/* Phone Number Validation */
fun isValidPhone(phone : String) : Bool {
  Regex.match(phone, "^[0-9\\-+() ]+$") and
  String.length(phone) >= 10
}

/* Numeric Range Validation */
fun isValidAge(age : Int) : Bool {
  age >= 0 and age <= 150
}

/* String Length Validation */
fun isValidUsername(username : String) : Bool {
  String.length(username) >= 3 and
  String.length(username) <= 20 and
  Regex.match(username, "^[a-zA-Z0-9_]+$")
}
```

### Sanitize Input

```mint
fun sanitizeString(input : String) : String {
  input
    |> String.trim()
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
}

fun sanitizeHtml(input : String) : String {
  /* Allow only safe tags */
  input
    |> String.replace("<script", "<_script")
    |> String.replace("javascript:", "_javascript:")
    |> String.replace("onerror=", "data-onerror=")
    |> String.replace("onload=", "data-onload=")
}
```

### Form Validation

```mint
component RegistrationForm {
  state email : String = ""
  state emailError : Maybe(String) = none
  state password : String = ""
  state passwordError : Maybe(String) = none
  state submitting : Bool = false

  fun validate() : Bool {
    isValid = true

    if not (isValidEmail(email)) {
      next emailError = some("Invalid email format")
      isValid = false
    } else {
      next emailError = none
    }

    if String.length(password) < 8 {
      next passwordError = some("Password must be at least 8 characters")
      isValid = false
    } else {
      next passwordError = none
    }

    isValid
  }

  fun handleSubmit(event : Html.Event) : Promise(Void) {
    Html.Event.preventDefault(event)

    if not (validate()) {
      return void
    }

    next submitting = true

    try {
      await registerUser(email, password)
      next submitting = false
    } catch Error(message) {
      next submitting = false
      /* Handle registration error */
    }
  }

  fun render : Html {
    <form onSubmit={handleSubmit}>
      <Ui.Form.Field
        label="Email"
        error={emailError}
      >
        <Ui.Input
          value={email}
          type={Ui.InputTypes:Email}
          onChange={fun (event : Html.Event) {
            next email = Html.Event.targetValue(event)
          }}
        />
      </Ui.Form.Field>

      <Ui.Form.Field
        label="Password"
        error={passwordError}
      >
        <Ui.Input
          value={password}
          type={Ui.InputTypes:Password}
          onChange={fun (event : Html.Event) {
            next password = Html.Event.targetValue(event)
          }}
        />
      </Ui.Form.Field>

      <Ui.Button
        label="Register"
        loading={submitting}
        disabled={submitting}
      />
    </form>
  }
}
```

## API Security

### Authentication Headers

```mint
store AuthStore {
  state token : Maybe(String) = none

  fun getAuthHeaders() : Object {
    case token {
      some(t) => { "Authorization": "Bearer #{t}" }
      none => {}
    }
  }

  fun fetchAuthenticated(url : String) : Promise(Response) {
    headers = getAuthHeaders()
    Http.get(url)
      |> Http.headers(headers)
  }
}

component SecureData {
  use AuthStore

  fun loadData() : Promise(Void) {
    try {
      response = await @authStore.fetchAuthenticated("/api/secure")
      data = Json.decode(response.body)
      next data = some(data)
    } catch Http.Error(status) {
      if status == 401 {
        /* Redirect to login */
        navigate("/login")
      }
      next error = some("Access denied")
    }
  }
}
```

### CSRF Protection

```mint
/* Store CSRF token from initial page load */
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

/* Include CSRF token in state initialization from server-rendered HTML */
component App {
  use CsrfStore

  fun mount : Void {
    /* Extract token from meta tag or data attribute */
    token =
      Html.Document.getElementById("csrf-token")
        |> Maybe.map(fn (el) { el.dataset.token })
        |> Maybe.withDefault("")

    if not (String.isEmpty(token)) {
      @csrfStore.setToken(token)
    }
  }
}

/* Add CSRF token to mutating requests */
fun safePost(url : String, body : Object) : Promise(Response) {
  csrfToken = @csrfStore.getToken()

  Http.post(url, body: Json.encode(body))
    |> Http.header("X-CSRF-Token", csrfToken)
    |> Http.header("Content-Type", "application/json")
}
```

## Secure Data Handling

### Sensitive Data in State

```mint
/* Avoid storing sensitive data in component state if possible */
component CheckoutForm {
  /* Store token only temporarily */
  state paymentToken : Maybe(String) = none

  fun processPayment(cardData : CardData) : Promise(Void) {
    try {
      /* Send directly to payment processor, don't store */
      token = await paymentProcessor.createToken(cardData)
      next paymentToken = some(token)
      await submitOrder(token)
    } catch Error {
      next error = some("Payment failed")
    }
  }

  fun mount : Void {
    /* Clear sensitive data when component unmounts */
    next paymentToken = none
  }
}
```

### Logout and Session Cleanup

```mint
store SessionStore {
  state user : Maybe(User) = none
  state token : Maybe(String) = none

  fun logout() : Void {
    next user = none
    next token = none
    /* Clear any cached data */
    clearApplicationCache()
  }
}

component LogoutButton {
  use SessionStore

  fun handleLogout(event : Html.Event) : Void {
    @sessionStore.logout()
    navigate("/login")
  }

  fun render : Html {
    <button onClick={handleLogout}>
      {"Logout"}
    </button>
  }
}
```

## Content Security Policy

### Meta Tag for CSP

```mint
component SecurityHeaders {
  fun render : Html {
    <head>
      <meta
        http-equiv="Content-Security-Policy"
        content="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"
      />
    </head>
  }
}
```

### Strict CSP for Production

```json
{
  "Content-Security-Policy": [
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: https:",
    "font-src 'self'",
    "connect-src 'self' https://api.example.com",
    "frame-ancestors 'none'"
  ]
}
```

## Dependencies Security

### Use Trusted Dependencies

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

### Pin Dependency Versions

```json
{
  "dependencies": {
    "mint-ui": {
      "repository": "https://github.com/mint-lang/mint-ui",
      "constraint": "8.0.0"  /* Pin to exact version in production */
    }
  }
}
```

## Security Checklist

- [ ] All user input is validated on both client and server
- [ ] Sensitive data is never logged or exposed in error messages
- [ ] Authentication tokens are stored securely
- [ ] HTTPS is enforced in production
- [ ] Content Security Policy is configured
- [ ] Dependencies are from trusted sources and pinned versions
- [ ] XSS prevention patterns are followed
- [ ] CSRF protection is implemented for state-changing operations
- [ ] Error messages don't expose sensitive information
- [ ] Session timeout is configured appropriately
- [ ] Role-based access control is implemented on backend
- [ ] API rate limiting is enforced on backend

## Common Vulnerabilities to Avoid

1. **XSS Attacks**: Never render untrusted HTML without sanitization
2. **CSRF Attacks**: Implement CSRF tokens for state-changing operations
3. **Injection Attacks**: Validate and sanitize all input
4. **Authentication Bypass**: Implement proper auth checks on all routes
5. **Sensitive Data Exposure**: Don't log or expose sensitive information
6. **Broken Access Control**: Implement role-based permissions
7. **Security Misconfigurations**: Use secure defaults, disable debug mode in production
8. **Using Deprecated Dependencies**: Keep dependencies updated

## Security Resources

- [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)
- [Mozilla Security Guidelines](https://wiki.mozilla.org/Security)
- [Content Security Policy Reference](https://content-security-policy.com/)
