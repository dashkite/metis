import * as Val from "@dashkite/joy/value"
import { isDefined } from "@dashkite/joy"
import Generic from "@dashkite/generic"

# OOP-friendly negate
negate = ( predicate ) -> 
  ( args... ) ->
    result = predicate.apply @, args
    if result?.then?
      result.then (resolvedValue) -> !resolvedValue
    else
      !result

# destructive cat
cat = ( array, value ) -> array.push value...

# destructive assign
assign = ( target, value ) -> Object.assign target, value

# predicate to check for tuples of a given length
tuple = ( size ) -> ( value ) -> value?.length == size

hasEvaluator = ( value ) -> value?.constructor == Object && value.evaluator?
isSync = ( value ) -> value?.constructor == Object && value.mode in [ "sync", "synchronous" ]
isAsync = ( value ) -> value?.constructor == Object && (!value.mode? || value.mode in [ "async", "asynchronous" ])

Rules =

  defaults:
    equal: Val.equal
    initialize: ( state ) -> state
    clone: structuredClone

  make: ( options ) ->
    { 
      Rules.defaults...
      options...
      rules: {}
      conditions: {}
      actions: {}
    }

  register: ( engine, rules ) ->
    do ({ name, conditions, action, predicate } = {}) ->
      for name, conditions of rules
        engine.rules[ name ] = 
          if ( action = engine.actions[ name ])?
            { name, conditions, action }
          else if ( condition = engine.conditions[ name ])?
            { name, conditions, condition }
          else
            throw new Error "unknown action: #{ name }"
      return # avoid returning comprehension
    engine

Conditions =

  register: ( engine, conditions ) ->
    assign engine.conditions, conditions
    engine

  normalize: ( engine, name ) ->
    do ({ truename, negated, condition } = {}) ->
      if ( name.startsWith "!" )
        truename = name[1..]
        negated = true
      else
        truename = name
      if ( condition = engine.conditions[ truename ])?
        condition = negate condition if negated
        { name, truename, negated, condition }
      else
        throw new Error "unknown condition: #{ truename }"

  lookup: ( engine, condition ) ->
    ( Conditions.normalize engine, condition ).condition
  
  closure: ( engine, conditions, seen = new Set ) ->
    result = []
    for name in conditions
      condition = Conditions.normalize engine, name
      unless seen.has condition.truename
        seen.add condition.truename
        if ( _condition = engine.rules[ condition.truename ])?
          cat result,
            Conditions.closure engine, 
              _condition.conditions,
              seen
        if !( Conditions.in condition, result )
          result.push condition.name
    result

  in: ({ name, truename }, list ) ->
    ( name in list ) ||
      (( name != truename ) && ( truename in list ))

Actions =
  
  register: ( engine, actions ) ->
    assign engine.actions, actions
    engine

Evaluators =

  asyncIterator: ( engine, state, delegator ) ->
    if delegator?
      Object.assign state, ( await yield from delegator )
    state = engine.initialize state
    yield from do ({ rules, rule, saved, changed, result } = {}) ->
      loop
        rules = Object.values engine.rules
          .filter ( rule ) ->
            rule.action? && do ->
              conditions = Conditions.closure engine, rule.conditions
              conditions.every ( condition ) -> 
                Conditions
                  .lookup engine, condition
                  .apply state
        saved = state
        state = engine.clone state
        for rule in rules
          yield { name: "rule", rule: rule.name, state }
          await rule.action.apply state
        changed = !( engine.equal saved, state )
        if changed
          yield { name: "change", state }
        else
          break
      yield { name: "done", state }
      state

  syncIterator: ( engine, state, delegator ) ->
    if delegator?
      Object.assign state, ( yield from delegator )
    state = engine.initialize state
    yield from do ({ rules, rule, saved, changed, result } = {}) ->
      loop
        rules = Object.values engine.rules
          .filter ( rule ) ->
            rule.action? && do ->
              conditions = Conditions.closure engine, rule.conditions
              conditions.every ( condition ) -> 
                Conditions
                  .lookup engine, condition
                  .apply state
        saved = state
        state = engine.clone state
        for rule in rules
          yield { name: "rule", rule: rule.name, state }
          rule.action.apply state
        changed = !( engine.equal saved, state )
        if changed
          yield { name: "change", state }
        else
          break
      yield { name: "done", state }
      state

  asyncCollector: ( engine, state ) ->
    state = await engine.initialize state
    loop
      saved = state
      state = await engine.clone state
      rules = Object.values engine.rules
      for rule in rules
        continue unless rule.action?
        conditions = Conditions.closure engine, rule.conditions
        passed = true
        for condition in conditions
          if !( await Conditions.lookup(engine, condition).apply state )
            passed = false
            break
        if passed
          await rule.action.apply state
      break if await engine.equal saved, state
    state

  syncCollector: ( engine, state ) ->
    state = engine.initialize state
    loop
      saved = state
      state = engine.clone state
      rules = Object.values engine.rules
      for rule in rules
        continue unless rule.action?
        conditions = Conditions.closure engine, rule.conditions
        passed = true
        for condition in conditions
          if !( Conditions.lookup(engine, condition).apply state )
            passed = false
            break
        if passed
          rule.action.apply state
      break if engine.equal saved, state
    state

class Athena

  @make: ( options ) -> 
    Object.assign ( new @ ), 
      engine: Rules.make options

  conditions: ( dictionary ) ->
    Conditions.register @engine, dictionary
    @

  condition: do ->

    ( Generic.make "Athena::condition" )
    
      .define [ Object ], ( specifier ) ->
        @conditions [ specifier.name ]: specifier.run
        if specifier.when?
          @rules [ specifier.name ]: specifier.when
        @

      .define [ tuple 2 ], ([ name, run ]) ->
        @condition { name, run }

      .define [ tuple 3 ], ([ name, conditions, run ]) ->
        @condition { name, run, when: conditions }

  actions: ( dictionary ) ->
    Actions.register @engine, dictionary
    @

  action: do ->

    ( Generic.make "Athena::action" )

      .define [ Object ], ( specifier ) ->
        @actions [ specifier.name ]: specifier.run
        if specifier.when?
          @rules [ specifier.name ]: specifier.when
        @

      .define [ tuple 2 ], ([ name, run ]) ->
        @action { name, run }

      .define [ tuple 3 ], ([ name, conditions, run ]) ->
        @action { name, run, when: conditions }

  rules: ( dictionary ) ->
    Rules.register @engine, dictionary
    @

  start: do ->
    ( Generic.make "Athena::start" )
      .define [ isDefined ], ( state ) ->
        Evaluators.asyncIterator @engine, state
        
      .define [ isDefined, hasEvaluator ], ( state, options ) ->
        options.evaluator @engine, state, options.delegator

      .define [ isDefined, isSync ], ( state, options ) ->
        Evaluators.syncIterator @engine, state, options.delegator

      .define [ isDefined, isAsync ], ( state, options ) ->
        Evaluators.asyncIterator @engine, state, options.delegator

      .define [ isDefined, Function ], ( state, evaluator ) ->
        evaluator @engine, state

      .define [ isDefined, Function, isDefined ], ( state, evaluator, delegator ) ->
        evaluator @engine, state, delegator

  run: do ->
    execute = ( engine, state, evaluator ) ->
      evaluator engine.engine, state

    ( Generic.make "Athena::run" )
      .define [ isDefined ], ( state ) ->
        execute @, state, Evaluators.asyncCollector
        
      .define [ isDefined, hasEvaluator ], ( state, options ) ->
        execute @, state, options.evaluator
        
      .define [ isDefined, isSync ], ( state, options ) ->
        execute @, state, Evaluators.syncCollector

      .define [ isDefined, isAsync ], ( state, options ) ->
        execute @, state, Evaluators.asyncCollector

      .define [ isDefined, Function ], ( state, evaluator ) ->
        execute @, state, evaluator
export default Athena
export { Rules, Conditions, Actions, Evaluators, Athena }