class Evaluator

  @make: ( engine, state ) ->
    Object.assign ( new @ ), { engine, state }


class SyncEvaluator extends Evaluator

  if: ( rule ) ->
    closure = ( rule.conditions ? @engine.conditions ).closure rule.when
    closure.every ( entry ) =>
      entry.predicate.call @state, @state

  then: ( rule ) ->
    rule.run.call @state, @state

  run: ->
    @state = @engine.initialize @state
    delete @state.__
    loop
      saved = @state
      @state = @engine.clone @state
      for rule in Object.values @engine.rules
        if (! rule.run?)
          continue
        if @if rule
          @then rule
      break if @engine.equal saved, @state
    delete @state.__
    @state

  start: ( delegator ) ->
    if delegator?
      Object.assign @state, ( yield from delegator )
    @state = @engine.initialize @state
    delete @state.__
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
        changed = (!( evaluator.engine.equal saved, evaluator.state ))
        if changed
          yield { name: "change", state: evaluator.state }
        else
          break
      yield { name: "done", state: evaluator.state }
      delete evaluator.state.__
      evaluator.state


class AsyncEvaluator extends Evaluator

  if: ( rule ) ->
    closure = ( rule.conditions ? @engine.conditions ).closure rule.when
    passed = true
    for entry in closure
      if (!( await entry.predicate.call @state, @state ))
        passed = false
        break
    passed

  then: ( rule ) ->
    await rule.run.call @state, @state

  run: ->
    @state = await @engine.initialize @state
    delete @state.__
    loop
      saved = @state
      @state = await @engine.clone @state
      rules = Object.values @engine.rules
      for rule in rules
        if (! rule.run?)
          continue
        passed = await @if rule
        if passed
          await @then rule
      break if await @engine.equal saved, @state
    delete @state.__
    @state

  start: ( delegator ) ->
    if delegator?
      Object.assign @state, ( await yield from delegator )
    @state = await @engine.initialize @state
    delete @state.__
    evaluator = @
    yield from do ({ rules, rule, saved, changed } = {}) ->
      loop
        rules = []
        for rule in Object.values evaluator.engine.rules
          if rule.run?
            passed = await evaluator.if rule
            if passed
              rules.push rule
        saved = evaluator.state
        evaluator.state = await evaluator.engine.clone evaluator.state
        for rule in rules
          yield { name: "rule", rule: rule.name, state: evaluator.state }
          await evaluator.then rule
        changed = (!( await evaluator.engine.equal saved, evaluator.state ))
        if changed
          yield { name: "change", state: evaluator.state }
        else
          break
      yield { name: "done", state: evaluator.state }
      delete evaluator.state.__
      evaluator.state


export { SyncEvaluator, AsyncEvaluator }
export default SyncEvaluator
