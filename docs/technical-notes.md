# Technical Notes

### Design Philosophy

While traditional rule-based systems and expert systems often feature complex internal structures and optimizations, Athena takes a different approach. The goal is to facilitate the creation of many small, focused rule engines that easily compose with one another.

### Reactive Programming and Iterators

Athena pairs naturally with DashKite's approach to reactive programming. By yielding events as state mutations occur, developers can report on and interact with a calculation while it remains in progress.

### Iterator Delegation

Athena leverages JavaScript's iterator delegation (`yield from` in CoffeeScript) to pass information forward into the engine. When applying an engine to a state, developers can pass an iterator argument; the engine will await and merge the results of that iterator into the state before resolving its own rules.

### Resolution Engine

Athena evaluates rules until the state reaches a stable condition where no further actions produce state changes. It achieves this by cloning the state and comparing it after rule execution.

### Negated Conditions

Conditions can be logically negated by prefixing the condition name with `!` when specifying them in a rule definition. The engine handles wrapping the predicate with a negation function.

### Fluent Coding Style

Athena provides a chainable API for registering conditions, actions, and rules. Methods like `condition`, `action`, and `rules` return the engine instance, allowing creators to configure the engine in a single contiguous block.
