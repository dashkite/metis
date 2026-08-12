# Recipes

## Defining Rules Inline

Athena allows developers to define rules succinctly by mapping conditions directly when registering actions. This approach keeps related logic clustered together and reduces configuration overhead.

1. Create the engine instance using `Athena.make`.
2. Define a condition using a name and a predicate function.
3. Register an action, supplying the action's name, the prerequisite conditions, and the execution function.
4. Start the engine to evaluate the state.

```coffeescript
import Athena from "@dashkite/athena"

athena = Athena.make()
  .condition [ "is-logged-in", -> @account? ]
  .condition [ "has-items", -> @cart.length > 0 ]
  # The action is mapped directly to its prerequisite conditions
  .action [ "checkout", [ "is-logged-in", "has-items" ], -> 
    @status = "checking-out"
  ]

state = 
  account: "alice"
  cart: [ "apple", "banana" ]

for await event from athena.start state
  console.log "State mutated:", event
```

## Using Negated Conditions

Developers can prefix a condition name with `!` when specifying rules to logically negate it. This avoids writing redundant, inverse conditions for common checks, keeping the codebase lean.

1. Register a positive condition on the engine.
2. Define an action that should run when the inverse of that condition is true.
3. Use the `!` prefix in the rules mapping to instruct the engine to negate the predicate during evaluation.

```coffeescript
import Athena from "@dashkite/athena"

athena = Athena.make()
  .condition [ "is-premium", -> @accountType == "premium" ]
  .rules
    "show-upgrade-prompt": [ "!is-premium" ]
  .action [ "show-upgrade-prompt", ->
    @prompts.push "Upgrade to premium today!"
  ]

state = 
  accountType: "basic"
  prompts: []

for await event from athena.start state
  console.log "Prompt added!"
```

## Composing Conditions

In Athena, conditions can specify their own prerequisite conditions. The engine's closure mechanism flattens and groups these condition trees before evaluating actions, enabling logical reuse.

1. Create the engine instance.
2. Define foundational base conditions.
3. Define a compound condition that lists the base conditions as prerequisites in its mapping.
4. Register an action that relies on the compound condition.
5. Start the engine with the state and observe how the engine resolves the prerequisite hierarchy.

```coffeescript
import Athena from "@dashkite/athena"

athena = Athena.make()
  # Base conditions
  .condition [ "has-funds", -> @balance >= @cartTotal ]
  .condition [ "in-stock", -> @inventory > 0 ]
  # Compound condition composed of base conditions
  .condition [ "can-purchase", [ "has-funds", "in-stock" ], -> 
    @accountStatus == "active"
  ]
  # Action relying on the compound condition
  .action [ "checkout", [ "can-purchase" ], ->
    @status = "success"
  ]

state = 
  balance: 100
  cartTotal: 50
  inventory: 1
  accountStatus: "active"
  status: "pending"

for await event from athena.start state
  console.log "System event:", event.name
```

## Creating Reactive State Machines

Because Athena resolves rules iteratively until the state reaches equilibrium, developers can chain state mutations to create reactive state machines. An action can mutate the state in a way that triggers a subsequent rule on the next pass, allowing complex workflows to emerge naturally.

1. Define a series of interconnected conditions and actions.
2. Map actions to conditions such that one action's state mutation fulfills another's condition.
3. Start the engine with a starting state, and observe the sequence of events as it resolves multiple steps.

```coffeescript
import Athena from "@dashkite/athena"

athena = Athena.make()
  .condition [ "order-placed", -> @status == "placed" ]
  .condition [ "payment-cleared", -> @paid == true ]
  .action [ "process-payment", [ "order-placed" ], ->
    @paid = true
    @status = "processing"
  ]
  .action [ "ship-order", [ "payment-cleared" ], ->
    @status = "shipped"
  ]

state = 
  status: "placed"
  paid: false

# This will yield multiple events as the order moves from placed to shipped
for await event from athena.start state
  console.log "Order moved to:", event.state.status
```

## Execution Modes

Athena provides two execution methods (`start` and `run`), each supporting synchronous and asynchronous evaluator modes, resulting in four distinct execution modes.

### Asynchronous Iteration (`start`, mode: "async")

By default, the `start` method operates asynchronously. It returns an async iterator that yields events as rules are evaluated and state mutates. This mode is ideal when your actions contain asynchronous operations.

```coffeescript
import Athena from "@dashkite/athena"

athena = Athena.make()
  .condition [ "is-ready", -> @status == "ready" ]
  .action [ "launch", [ "is-ready" ], -> 
    await new Promise (resolve) -> setTimeout resolve, 100
    @launched = true 
  ]

state = status: "ready"

# Evaluates asynchronously and yields events
for await event from athena.start state, mode: "async"
  console.log "State mutated:", event
```

### Synchronous Iteration (`start`, mode: "sync")

Creators can run the iterator synchronously by specifying `mode: "sync"`. This evaluates rules without awaiting promises, yielding events immediately via a standard synchronous generator. This mode offers a speed advantage at the cost of losing the ability to release the event loop during execution.

```coffeescript
import Athena from "@dashkite/athena"

athena = Athena.make()
  .condition [ "is-ready", -> @status == "ready" ]
  .action [ "launch", [ "is-ready" ], -> @launched = true ]

state = status: "ready"

# Evaluates synchronously and yields events immediately
for event from athena.start state, mode: "sync"
  console.log "State mutated:", event
```

### Asynchronous Execution (`run`, mode: "async")

For integration with functional execution patterns, Athena provides a `run` method. This method executes completely statelessly without yielding events, returning a Promise resolving to the final state once the engine reaches equilibrium. By default, `run` operates asynchronously.

```coffeescript
import Athena from "@dashkite/athena"

engine = Athena.make()
  .condition [ "needs-update", -> @version < 2 ]
  .action [ "update", [ "needs-update" ], -> 
    await new Promise (resolve) -> setTimeout resolve, 100
    @version += 1 
  ]

state = version: 0

# Returns a Promise resolving to the final state
finalState = await engine.run state, mode: "async"
console.log "Final version:", finalState.version
```

### Synchronous Execution (`run`, mode: "sync")

Creators can compose distinct engines functionally by executing them sequentially, passing the state returned from one directly into the next synchronously. This synchronous execution of the rule engine may proceed at maximum speed in exchange for giving up the compositional properties of iterators.

```coffeescript
import Athena from "@dashkite/athena"

pricingEngine = Athena.make()
  .condition [ "has-discount", -> @discountCode? ]
  .action [ "apply-discount", [ "has-discount" ], -> @total *= 0.9 ]

inventoryEngine = Athena.make()
  .condition [ "in-stock", -> @inventory > 0 ]
  .action [ "reserve-item", [ "in-stock" ], -> @inventory -= 1 ]

state = 
  inventory: 5
  total: 100
  discountCode: "SAVE10"

# Returns the final state statelessly and synchronously
state1 = pricingEngine.run state, mode: "sync"
finalState = inventoryEngine.run state1, mode: "sync"

console.log "Final total:", finalState.total
```

## Delegator Integration

### Composing Small Engines

Instead of building large rule engines, creators can build many small, focused engines and compose them. JavaScript's iterator delegation enables passing information forward into an engine before it evaluates its own rules. This makes it possible to compose specialized logic blocks.

1. Create multiple engines, each with distinct responsibilities (for example, a pricing engine and an inventory engine).
2. Delegate to an engine's `start` method, passing the iterator generated by a prior engine as a delegator argument.
3. The secondary engine will consume and await the state modifications from the first engine before resolving its own rules.

```coffeescript
import Athena from "@dashkite/athena"

pricingEngine = Athena.make()
  .condition [ "has-discount", -> @discountCode? ]
  .action [ "apply-discount", [ "has-discount" ], -> @total *= 0.9 ]

inventoryEngine = Athena.make()
  .condition [ "in-stock", -> @inventory > 0 ]
  .action [ "reserve-item", [ "in-stock" ], -> @inventory -= 1 ]

state = 
  inventory: 5
  total: 100
  discountCode: "SAVE10"

# Delegate inventory resolution to pricing resolution
for await event from inventoryEngine.start state, delegator: pricingEngine.start state
  console.log "System resolved a change:", event.name
```

### Integrating Custom Delegators

Athena's `start` method accepts a `delegator` option. Because the engine consumes this delegator using iterator delegation (`yield from`), creators can supply any custom generator to execute preparatory logic or yield preliminary events before the main engine resolves its rules. The generator must return an object, which Athena will then merge into the current state.

1. Create an engine instance to process the state.
2. Define a custom generator function that yields setup events and returns a state modification object.
3. Call `start` on the engine, passing the custom generator as the `delegator` in the options.
4. Iterate over the events. The custom generator's events will yield first, followed by the engine's rule resolution events.

```coffeescript
import Athena from "@dashkite/athena"

engine = Athena.make()
  .condition [ "is-ready", -> @status == "ready" ]
  .action [ "launch", [ "is-ready" ], -> @launched = true ]

setupGenerator = ->
  yield name: "setup-started"
  # Perform complex setup logic here
  yield name: "setup-finished"
  # Return the state modifications to merge
  return status: "ready"

state = {}

for await event from engine.start state, delegator: setupGenerator()
  console.log "Event:", event.name

console.log "Launched:", state.launched
```

## Engine Configuration Affordances

Creators can customize the internal mechanics of an Athena engine by providing configuration options to `Athena.make`. This affords creators the ability to override how the engine compares state for equality, how it clones state between iterations, and how it initializes state.

1. Define a custom clone function if your state contains complex objects that `structuredClone` cannot handle.
2. Define a custom equality function to optimize how the engine detects state changes.
3. Define an initialization function to ensure the state possesses required properties before rule evaluation begins.
4. Pass these functions as options to `Athena.make`.

```coffeescript
import Athena from "@dashkite/athena"

options = 
  # Use a custom, lightweight clone function
  clone: ( state ) -> Object.assign {}, state
  # Optimize equality checks by focusing only on relevant properties
  equal: ( a, b ) -> a.version == b.version
  # Ensure the state has a base structure
  initialize: ( state ) ->
    state.version ?= 0
    state

engine = Athena.make options
  .condition [ "needs-update", -> @version < 2 ]
  .action [ "update", [ "needs-update" ], -> @version += 1 ]

state = version: 0

finalState = engine.run state, mode: "sync"
console.log "Final version:", finalState.version
```

## Iterative Rules (.each & Aggregator)

Athena allows developers to scope rules to items within a collection using `.each(selector)` and the `Aggregator` scope. This enables declarative element-by-element evaluation and transformation over collections without manual `for` loops or custom iteration logic.

1. Call `.each(selector)` on the `Athena` instance to obtain an `Aggregator` scope targeting a collection (e.g. `-> @cart`).
2. Use `.condition(...)` on the `Aggregator` to define item-level conditions (`@ = item`, `(state)` parameter).
3. Use `.action(...)` on the `Aggregator` to define the iterative action (`@ = item`, `(state)` parameter).
4. Global parent conditions defined on `Athena` (`@ = state`) can be combined with local item conditions in iterative actions seamlessly.

```coffeescript
import Athena from "@dashkite/athena"

athena = Athena.make()
  # Global state condition (@ = state)
  .condition [ "store-is-open", -> @isOpen ]

  # Iterative rule block scoped to @cart
  .each(-> @cart)
    # Local item conditions (@ = item)
    .condition([ "is-affordable", (state) -> @price <= state.remainingBudget ])
    .action([
      "approve-item"
      # Combines global condition "store-is-open" and local item condition
      [ "store-is-open", "is-affordable" ]
      ( state ) ->
        state.order.push { id: @id, price: @price }
        state.remainingBudget -= @price
    ])

state =
  isOpen: true
  remainingBudget: 50
  cart: [
    { id: "a", price: 30 }
    { id: "b", price: 40 }
    { id: "c", price: 20 }
  ]
  order: []

finalState = athena.run state, mode: "sync"
```
