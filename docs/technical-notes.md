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
