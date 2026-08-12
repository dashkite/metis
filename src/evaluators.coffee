import Generic from "@dashkite/generic"

isIterativeRule = ( rule ) -> rule?.each?

class Evaluator

  @make: ( engine, state ) ->
    Object.assign ( new @ ), { engine, state }


class SyncEvaluator extends Evaluator

  if: do ->
    ( Generic.make "SyncEvaluator::if" )

      .define [ Object ], ( rule ) ->
        closure = ( rule.conditions ? @engine.conditions ).closure rule.when
        closure.every ( entry ) =>
          entry.predicate.call @state, @state

      .define [ isIterativeRule ], ( rule ) ->
        closure = ( rule.conditions ? @engine.conditions ).closure rule.when
        targets = rule.each.call @state, @state
        ( targets ? [] ).some ( target ) =>
          closure.every ( entry ) =>
            self = if ( entry.scope == "target" ) then target else @state
            entry.predicate.call self, @state

  then: do ->
    ( Generic.make "SyncEvaluator::then" )

      .define [ Object ], ( rule ) ->
        rule.run.call @state, @state

      .define [ isIterativeRule ], ( rule ) ->
        closure = ( rule.conditions ? @engine.conditions ).closure rule.when
        targets = rule.each.call @state, @state
        for target in ( targets ? [] )
          targetPassed = closure.every ( entry ) =>
            self = if ( entry.scope == "target" ) then target else @state
            entry.predicate.call self, @state
          if targetPassed
            rule.run.call target, @state
        return

  run: ->
    @state = @engine.initialize @state
    loop
      saved = @state
      @state = @engine.clone @state
      for rule in Object.values @engine.rules
        if ( ! rule.run? )
          continue
        if @if rule
          @then rule
      break if @engine.equal saved, @state
    @state

  start: ( delegator ) ->
    if delegator?
      Object.assign @state, ( yield from delegator )
    @state = @engine.initialize @state
    evaluator = @
    yield from do ({ rules, rule, saved, changed } = {}) ->
      loop
        rules =
          Object.values evaluator.engine.rules
            .filter ( rule ) ->
              rule.run? && evaluator.if rule
        saved = evaluator.state
        evaluator.state = evaluator.engine.clone evaluator.state
        for rule in rules
          yield { name: "rule", rule: rule.name, state: evaluator.state }
          evaluator.then rule
        changed = ( ! ( evaluator.engine.equal saved, evaluator.state ) )
        if changed
          yield { name: "change", state: evaluator.state }
        else
          break
      yield { name: "done", state: evaluator.state }
      evaluator.state


class AsyncEvaluator extends Evaluator

  if: do ->
    ( Generic.make "AsyncEvaluator::if" )

      .define [ Object ], ( rule ) ->
        closure = ( rule.conditions ? @engine.conditions ).closure rule.when
        passed = true
        for entry in closure
          if ( ! ( await entry.predicate.call @state, @state ) )
            passed = false
            break
        passed

      .define [ isIterativeRule ], ( rule ) ->
        closure = ( rule.conditions ? @engine.conditions ).closure rule.when
        targets = await rule.each.call @state, @state
        passed = false
        for target in ( targets ? [] )
          targetPassed = true
          for entry in closure
            self = if ( entry.scope == "target" ) then target else @state
            if ( ! ( await entry.predicate.call self, @state ) )
              targetPassed = false
              break
          if targetPassed
            passed = true
            break
        passed

  then: do ->
    ( Generic.make "AsyncEvaluator::then" )

      .define [ Object ], ( rule ) ->
        await rule.run.call @state, @state

      .define [ isIterativeRule ], ( rule ) ->
        closure = ( rule.conditions ? @engine.conditions ).closure rule.when
        targets = await rule.each.call @state, @state
        for target in ( targets ? [] )
          targetPassed = true
          for entry in closure
            self = if ( entry.scope == "target" ) then target else @state
            if ( ! ( await entry.predicate.call self, @state ) )
              targetPassed = false
              break
          if targetPassed
            await rule.run.call target, @state
        return

  run: ->
    @state = await @engine.initialize @state
    loop
      saved = @state
      @state = await @engine.clone @state
      rules = Object.values @engine.rules
      for rule in rules
        if ( ! rule.run? )
          continue
        passed = await @if rule
        if passed
          await @then rule
      break if await @engine.equal saved, @state
    @state

  start: ( delegator ) ->
    if delegator?
      Object.assign @state, ( await yield from delegator )
    @state = await @engine.initialize @state
    evaluator = @
    yield from do ({ rules, rule, saved, changed } = {}) ->
      loop
        matchingRules = []
        for rule in Object.values evaluator.engine.rules
          if rule.run?
            passed = await evaluator.if rule
            if passed
              matchingRules.push rule
        saved = evaluator.state
        evaluator.state = await evaluator.engine.clone evaluator.state
        for rule in matchingRules
          yield { name: "rule", rule: rule.name, state: evaluator.state }
          await evaluator.then rule
        changed = ( ! ( await evaluator.engine.equal saved, evaluator.state ) )
        if changed
          yield { name: "change", state: evaluator.state }
        else
          break
      yield { name: "done", state: evaluator.state }
      evaluator.state


export { SyncEvaluator, AsyncEvaluator }
export default SyncEvaluator
