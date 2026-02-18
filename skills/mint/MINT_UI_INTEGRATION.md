# Mint UI Integration

This guide covers integrating Mint UI components, theming, and styling patterns for building beautiful user interfaces.

## Getting Started with Mint UI

### Installation

Add Mint UI to your `mint.json`:

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

Then install:
```bash
mint install
```

### Theme Setup

Wrap your application with the theme root:

```mint
component Main {
  fun render : Html {
    <Ui.Theme.Root theme={Ui.Themes:Light}>
      <App/>
    </Ui.Theme.Root>
  }
}
```

## Typography

### Headings

```mint
<Ui.Typography.Heading size={1}>
  {"Main Heading"}
</Ui.Typography.Heading>

<Ui.Typography.Heading size={2}>
  {"Subheading"}
</Ui.Typography.Heading>

<Ui.Typography.Heading size={3}>
  {"Smaller Heading"}
</Ui.Typography.Heading>
```

### Body Text

```mint
<Ui.Typography.Body>
  {"This is body text with automatic sizing and spacing."}
</Ui.Typography.Body>

<Ui.Typography.Text size={Small}>
  {"Small text for captions"}
</Ui.Typography.Text>

<Ui.Typography.Text>
  {"Regular text"}
</Ui.Typography.Text>

<Ui.Typography.Text size={Large}>
  {"Large text"}
</Ui.Typography.Text>
```

### Links

```mint
<Ui.Typography.Link href="/about">
  {"About Us"}
</Ui.Typography.Link>
```

## Buttons

### Basic Button

```mint
<Ui.Button
  label="Click Me"
  onClick={fun (event : Html.Event) { Debug.log("Clicked!") }}
/>
```

### Button Variants

```mint
<Ui.Button
  label="Primary"
  variant={Ui.Buttons:Primary}
/>

<Ui.Button
  label="Secondary"
  variant={Ui.Buttons:Secondary}
/>

<Ui.Button
  label="Danger"
  variant={Ui.Buttons:Danger}
/>

<Ui.Button
  label="Text"
  variant={Ui.Buttons:Text}
/>
```

### Button Sizes

```mint
<Ui.Button
  label="Small"
  size={Ui.Sizes:Small}
/>

<Ui.Button
  label="Medium"
  size={Ui.Sizes:Medium}
/>

<Ui.Button
  label="Large"
  size={Ui.Sizes:Large}
/>
```

### Icon Button

```mint
<Ui.Button
  iconBefore={Ui.Icons:Plus}
  label="Add Item"
  onClick={handleAdd}
/>

<Ui.Button
  iconAfter={Ui.Icons:ArrowRight}
  label="Next"
  onClick={handleNext}
/>
```

### Loading State

```mint
<Ui.Button
  label="Submit"
  loading={true}
  onClick={handleSubmit}
/>
```

## Cards

### Basic Card

```mint
<Ui.Card>
  <Ui.Card.Header>
    <Ui.Card.Title>
      {"Card Title"}
    </Ui.Card.Title>
  </Ui.Card.Header>
  <Ui.Card.Body>
    <p>{"Card content goes here"}</p>
  </Ui.Card.Body>
  <Ui.Card.Footer>
    <Ui.Button label="Action" onClick={handleAction}/>
  </Ui.Card.Footer>
</Ui.Card>
```

### Clickable Card

```mint
<Ui.Card
  onClick={fun (event : Html.Event) { handleCardClick() }}
>
  <Ui.Card.Body>
    <p>{"Clickable card content"}</p>
  </Ui.Card.Body>
</Ui.Card>
```

## Forms

### Text Input

```mint
<Ui.Input
  value={email}
  onChange={fun (event : Html.Event) {
    next email = Html.Event.targetValue(event)
  }}
  placeholder="Enter email"
/>
```

### Password Input

```mint
<Ui.Input
  value={password}
  type={Ui.InputTypes:Password}
  onChange={fun (event : Html.Event) {
    next password = Html.Event.targetValue(event)
  }}
  placeholder="Enter password"
/>
```

### Text Area

```mint
<Ui.TextArea
  value={message}
  onChange={fun (event : Html.Event) {
    next message = Html.Event.targetValue(event)
  }}
  placeholder="Enter message"
  rows={4}
/>
```

### Select

```mint
<Ui.Select
  value={selectedOption}
  options={[
    { value: "opt1", label: "Option 1" },
    { value: "opt2", label: "Option 2" },
    { value: "opt3", label: "Option 3" }
  ]}
  onChange={fun (option) { next selectedOption = option }}
/>
```

### Checkbox

```mint
<Ui.Checkbox
  label="I agree to terms"
  checked={agreed}
  onChange={fun (checked) { next agreed = checked }}
/>
```

### Form Field Wrapper

```mint
<Ui.Form.Field
  label="Email"
  error={emailError}
>
  <Ui.Input
    value={email}
    onChange={handleEmailChange}
    placeholder="Enter email"
  />
</Ui.Form.Field>
```

## Layout Components

### Grid

```mint
<Ui.Grid container={true}>
  <Ui.Grid item={true} xs={12} sm={6} md={4}>
    <Card1/>
  </Ui.Grid>
  <Ui.Grid item={true} xs={12} sm={6} md={4}>
    <Card2/>
  </Ui.Grid>
  <Ui.Grid item={true} xs={12} sm={6} md={4}>
    <Card3/>
  </Ui.Grid>
</Ui.Grid>
```

### Flex

```mint
<Ui.Flex
  justifyContent={Ui.FlexJustify:Between}
  alignItems={Ui.FlexAlign:Center}
>
  <Logo/>
  <Nav/>
  <Actions/>
</Ui.Flex>
```

### Container

```mint
<Ui.Container maxWidth={Ui.ContainerWidth:Large}>
  <MainContent/>
</Ui.Container>
```

## Feedback Components

### Loading Spinner

```mint
<Ui.LoadingSpinner/>
```

### Progress Bar

```mint
<Ui.Progress
  value={progress}
  max={100}
/>
```

### Alert

```mint
<Ui.Alert
  title="Success"
  variant={Ui.Alerts:Success}
>
  {"Your changes have been saved."}
</Ui.Alert>

<Ui.Alert
  title="Error"
  variant={Ui.Alerts:Danger}
>
  {"Something went wrong."}
</Ui.Alert>

<Ui.Alert
  title="Warning"
  variant={Ui.Alerts:Warning}
>
  {"Please review before continuing."}
</Ui.Alert>
```

### Toast Notifications

```mint
<Ui.Toast
  message="Item saved!"
  variant={Ui.Toasts:Success}
/>
```

## Navigation

### App Bar

```mint
<Ui.AppBar
  title="My App"
  position={Ui.AppBarPosition:Fixed}
>
  <Ui.AppBar.NavigationIcon
    icon={Ui.Icons:Menu}
    onClick={toggleDrawer}
/>
  <Ui.AppBar.Title>
    {"My App"}
  </Ui.AppBar.Title>
  <Ui.AppBar.Actions>
    <Ui.IconButton
      icon={Ui.Icons:Search}
      onClick={openSearch}
    />
  </Ui.AppBar.Actions>
</Ui.AppBar>
```

### Drawer

```mint
<Ui.Drawer
  open={drawerOpen}
  onClose={closeDrawer}
>
  <Ui.List>
    <Ui.List.Item
      icon={Ui.Icons:Home}
      text="Home"
      onClick={navigateToHome}
/>
    <Ui.List.Item
      icon={Ui.Icons:Settings}
      text="Settings"
      onClick={navigateToSettings}
/>
  </Ui.List>
</Ui.Drawer>
```

### Tabs

```mint
<Ui.Tabs
  value={activeTab}
  onChange={fun (tab) { next activeTab = tab }}
>
  <Ui.Tab label="Tab 1" value="tab1"/>
  <Ui.Tab label="Tab 2" value="tab2"/>
  <Ui.Tab label="Tab 3" value="tab3"/>
</Ui.Tabs>
```

## Data Display

### Avatar

```mint
<Ui.Avatar src={user.avatar} alt={user.name}/>

<Ui.Avatar.Group>
  <Ui.Avatar src={user1.avatar}/>
  <Ui.Avatar src={user2.avatar}/>
  <Ui.Avatar src={user3.avatar}/>
</Ui.Avatar.Group>

<Ui.Avatar
  name="John Doe"
  fallback="JD"
/>
```

### Badge

```mint
<Ui.Badge
  content={notificationCount}
  variant={Ui.Badges:Primary}
>
  <Icon/>
</Ui.Badge>
```

### List

```mint
<Ui.List>
  for item of items {
    <Ui.List.Item
      key={item.id}
      primaryText={item.title}
      secondaryText={item.description}
      onClick={fun (event : Html.Event) { selectItem(item) }}
    />
  }
</Ui.List>
```

### Table

```mint
<Ui.Table>
  <Ui.Table.Head>
    <Ui.Table.Row>
      <Ui.Table.Cell>{"Name"}</Ui.Table.Cell>
      <Ui.Table.Cell>{"Email"}</Ui.Table.Cell>
      <Ui.Table.Cell>{"Actions"}</Ui.Table.Cell>
    </Ui.Table.Row>
  </Ui.Table.Head>
  <Ui.Table.Body>
    for user of users {
      <Ui.Table.Row>
        <Ui.Table.Cell>{ user.name }</Ui.Table.Cell>
        <Ui.Table.Cell>{ user.email }</Ui.Table.Cell>
        <Ui.Table.Cell>
          <Ui.Button
            size={Ui.Sizes:Small}
            onClick={fun (event : Html.Event) { editUser(user) }}
          >
            {"Edit"}
          </Ui.Button>
        </Ui.Table.Cell>
      </Ui.Table.Row>
    }
  </Ui.Table.Body>
</Ui.Table>
```

## Icons

### Icon Usage

```mint
<Ui.Icon icon={Ui.Icons:Home}/>
<Ui.Icon icon={Ui.Icons:Search} size={Ui.IconSizes:Small}/>
<Ui.Icon icon={Ui.Icons:Settings} size={Ui.IconSizes:Large}/>
```

### Available Icons

Commonly available icons:
- `Ui.Icons:Home`, `Ui.Icons:Search`, `Ui.Icons:Settings`
- `Ui.Icons:Menu`, `Ui.Icons:Close`, `Ui.Icons:ArrowBack`
- `Plus`, `Ui.Icons:Minus`, `Ui.IUi.Icons:cons:Check`
- `Ui.Icons:Edit`, `Ui.Icons:Delete`, `Ui.Icons:Share`
- `Ui.Icons:Email`, `Ui.Icons:Phone`, `Ui.Icons:Location`
- `Ui.Icons:Star`, `Ui.Icons:Heart`, `Ui.Icons:ShoppingCart`

## Theming

### Light Theme

```mint
<Ui.Theme.Root theme={Ui.Themes:Light}>
  <App/>
</Ui.Theme.Root>
```

### Dark Theme

```mint
<Ui.Theme.Root theme={Ui.Themes:Dark}>
  <App/>
</Ui.Theme.Root>
```

### Custom Theme

```mint
let customTheme =
  Ui.Theme.create(
    Ui.Themes:Light,
    {
      primary: "#6366f1",
      secondary: "#8b5cf6",
      background: "#f8fafc",
      surface: "#ffffff",
      error: "#ef4444",
      success: "#22c55e",
      warning: "#f59e0b"
    }
  )

<Ui.Theme.Root theme={customTheme}>
  <App/>
</Ui.Theme.Root>
```

## Responsive Design

### Using Breakpoints

```mint
style container {
  padding: 16px;

  @media (min-width: 640px) {
    padding: 24px;
  }

  @media (min-width: 1024px) {
    padding: 32px;
    max-width: 1200px;
    margin: 0 auto;
  }
}
```

### Conditional Rendering by Size

```mint
component ResponsiveNav {
  style desktop {
    display: block;

    @media (max-width: 767px) {
      display: none;
    }
  }

  style mobile {
    display: none;

    @media (max-width: 767px) {
      display: block;
    }
  }

  fun render : Html {
    <>
      <nav::desktop>
        <DesktopNav/>
      </nav>
      <nav::mobile>
        <MobileNav/>
      </nav>
    </>
  }
}
```

## Common Patterns

### Combining Mint UI with Custom Styles

```mint
component CustomButton {
  property label : String
  property onClick : Fun(Html.Event, Void)

  style base {
    font-family: "Inter", sans-serif;
    padding: 8px 16px;
    border-radius: 6px;
  }

  style primary {
    background: var(--mint-primary);
    color: white;
  }

  style hoverable {
    &:hover {
      opacity: 0.9;
    }

    &:active {
      transform: scale(0.98);
    }
  }

  fun render : Html {
    <Ui.Button::base::primary::hoverable
      label={label}
      onClick={onClick}
    />
  }
}
```

### Form with Validation

```mint
component ValidatedForm {
  state email : String = ""
  state emailError : Maybe(String) = none
  state isSubmitting : Bool = false

  fun validateEmail(input : String) : Maybe(String) {
    if String.isEmpty(input) {
      some("Email is required")
    } else if not (String.contains(input, "@")) {
      some("Invalid email format")
    } else {
      none
    }
  }

  fun handleEmailChange(event : Html.Event) {
    value = Html.Event.targetValue(event)
    next email = value
    next emailError = validateEmail(value)
  }

  fun handleSubmit(event : Html.Event) : Promise(Void) {
    next isSubmitting = true
    try {
      await submitForm(email)
      next isSubmitting = false
    } catch Error {
      next isSubmitting = false
    }
  }

  fun render : Html {
    <Ui.Form.Field
      label="Email"
      error={emailError}
    >
      <Ui.Input
        value={email}
        onChange={handleEmailChange}
        type={Ui.InputTypes:Email}
        placeholder="Enter your email"
      />
    </Ui.Form.Field>

    <Ui.Button
      label="Submit"
      loading={isSubmitting}
      onClick={handleSubmit}
      disabled={case emailError {
        some(_) => true
        none => false
      }}
    />
  }
}
```

### Modal Dialog

```mint
component ConfirmDialog {
  property title : String
  property message : String
  property onConfirm : Void -> Void
  property onCancel : Void -> Void

  fun render : Html {
    <Ui.Modal
      open={true}
      onClose={onCancel}
    >
      <Ui.Modal.Title>
        { title }
      </Ui.Modal.Title>
      <Ui.Modal.Body>
        <p>{ message }</p>
      </Ui.Modal.Body>
      <Ui.Modal.Actions>
        <Ui.Button
          label="Cancel"
          variant={Ui.Buttons:Text}
          onClick={onCancel}
        />
        <Ui.Button
          label="Confirm"
          onClick={onConfirm}
        />
      </Ui.Modal.Actions>
    </Ui.Modal>
  }
}
```

## Resources

- [Mint UI Documentation](https://ui.mint-lang.com)
- [Mint UI GitHub](https://github.com/mint-lang/mint-ui)
- [Component Examples](https://github.com/mint-lang/mint-website)
