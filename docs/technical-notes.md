# Technical Notes

### Design Philosophy

While traditional [rule-based systems](https://en.wikipedia.org/wiki/Rule-based_system) and expert systems often feature complex internal structures and optimizations, Athena takes a different approach. Rather than relying on monolithic logic engines like the [Rete algorithm](https://en.wikipedia.org/wiki/Rete_algorithm), the goal is to facilitate the creation of many small, focused rule engines. Creators can then compose these smaller components with one another.

### Reactive Programming and Iterators

Athena pairs naturally with DashKite's approach to [reactive programming](https://en.wikipedia.org/wiki/Reactive_programming). By yielding events directly as state mutations occur, developers gain a transparent window into the engine's internal workings. This allows calling code to report on and interact with a calculation dynamically, even while the engine remains in progress.

### Iterator Delegation

Athena leverages JavaScript's [iterator delegation](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/yield*)—represented by `yield from` in CoffeeScript—to pass information forward into the engine. When kicking off an engine's execution, developers can pass an optional `delegator` parameter. The engine immediately awaits and merges the results of that delegator directly into the current state, setting the stage before it attempts to resolve its own rules.

### Delegator Protocol

Because the `delegator` is consumed via `yield from`, it natively supports any object implementing the standard JavaScript [Iterable protocol](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Iteration_protocols#the_iterable_protocol) or [AsyncIterable protocol](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Iteration_protocols#the_asynciterable_protocol). This flexible, standards-compliant design means creators aren't constrained to passing Athena iterators alone. You can supply standard Arrays, Generators, Streams, or any custom iterable to populate the engine state prior to evaluation.

### Execution Modes and Event Loop Trade-offs

Creators can toggle between asynchronous and synchronous execution depending on the engine's requirements. Asynchronous modes lean on the JavaScript [Event Loop](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Event_loop), allowing the runtime to handle other tasks like I/O or rendering while the engine processes rules. 

Choosing synchronous iteration offers a speed advantage by avoiding promise resolution overhead. However, this comes at the cost of losing the ability to release the event loop during execution, potentially blocking the thread on heavy rule sets. When using the `run` method in synchronous mode, the engine executes at maximum speed statelessly, but doing so forces you to give up the compositional properties provided by iterators entirely.

### Resolution Engine

Athena evaluates rules until the state reaches a stable equilibrium—a condition where no further actions produce state changes. It achieves this [fixed point](https://en.wikipedia.org/wiki/Fixed-point_iteration) by cloning the state snapshot and comparing it against the fresh state after every rule execution pass.

### Negated Conditions

Conditions can be logically negated by prefixing the condition name with `!` when specifying them in a rule definition. Behind the scenes, the engine dynamically wraps the target predicate with a negation function. This reduces the need for creators to write inverse companion predicates for common checks.

### Fluent Coding Style

Athena provides a chainable API for registering conditions, actions, and rules. Core methods like `condition`, `action`, and `rules` always return the primary engine instance. This pattern enables creators to configure the engine within a single contiguous block.

### Iterative Rules and the Aggregator Macro Pattern

Athena's core engine evaluates rules against a global `state` snapshot. However, many real-world rule sets need to perform element-wise transformations or validations over collections of items based on a combination of global state conditions and item-level predicates.

To support iterative rules without complicating Athena's core engine or evaluator classes, Athena introduces the `.each(selector)` macro pattern via the `Aggregator` class.

#### The Macro Expansion Pattern

Rather than baking collection-handling logic into `Athena` or its evaluator classes (`SyncEvaluator` / `AsyncEvaluator`), `Aggregator` acts as a **macro expander**. When an `.each(selector).action(...)` rule is defined, `Aggregator` compiles it down into standard Athena primitives:

1. **Sub-rule Condition (`#{name}:has-targets`)**: Registers a global condition on `Athena` that evaluates whether at least one item in the selected collection satisfies the local item conditions (`local`).
2. **Engine Rule (`name`)**: Registers a standard rule on the main `Athena` engine whose `when` list combines the parent global condition names (`parent`) with the generated `has-targets` condition name (`[ parent..., condition ]`).
3. **Execution Callback**: When the rule fires, it selects items and runs a sequential iteration process over items that satisfy the local item conditions.

This macro pattern is a powerful architectural technique in Athena. Beyond `.each`, the same pattern can be used to construct other specialized control flow abstractions—such as threshold gates, batch operations, or map-reduce flows—that would otherwise require tedious manual bookkeeping.

#### Design Alternatives and Trade-offs

* **Alternative A: Extending Engine Evaluators Directly**
  * *Approach*: Modify `SyncEvaluator` and `AsyncEvaluator` to natively recognize array targets and manage element-wise loops.
  * *Why Rejected*: Pollutes core evaluators with target-element binding, iteration state, and collection-slicing logic. It breaks the fundamental contract that `Evaluator` operates purely on a snapshot of a `state` object, compromising engine simplicity.

* **Alternative B: Generator-Based Condition & Rule Abstractions**
  * *Approach*: Have conditions and rules return generators (or async generators) to yield values, stepping through evaluation to abstract away the mechanics of rule resolution.
  * *Why Rejected*:
    * **Performance Overhead**: Allocating generator state machine objects for every condition predicate and action pass during evaluation cycles.
    * **Loss of Zero-Tick Synchronous Execution**: Generator delegation requires runner machinery (such as `yield from` or generator iteration loops). By contrast, Athena's `deferrable` combinator handles thenables with 0-tick microtask overhead for synchronous functions, preserving maximum execution speed for `SyncEvaluator`.

#### Internal Domain Abstractions and Combinators

To keep the `Aggregator` implementation clean and maintainable:

* **`deferrable` Combinator**: Wraps functions to check for thenables (`result?.then`), invoking callbacks synchronously for immediate values or via `.then()` for Promises while preserving `this` (`@`) context and function arity.
* **`target` (`{ item, state }`) & `context` (`{ state, closure, run }`)**: Encapsulates item/state pairs and loop context into domain objects, keeping internal helper functions (`test`, `execute`, `evaluate`, `check`, `process`) capped at a maximum of 2 parameters with argument destructuring.
