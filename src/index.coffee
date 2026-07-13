import * as Val from "@dashkite/joy/value"
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
    engine
    
  run: ( engine, state ) ->
    state = engine.initialize state
    do ({ rules, rule, saved, changed, result } = {}) ->
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

Evaluator =
  run: ( engine, state ) ->
    evaluate = ( currentState ) ->
      saved = currentState
      currentState = engine.clone currentState
      
      applyRules = ( [ rule, remaining... ] = [], currentState ) ->
        if !rule?
          if engine.equal saved, currentState
            currentState
          else
            evaluate currentState
        else
          if rule.action?
            conditions = Conditions.closure engine, rule.conditions
            
            checkConditions = ( [ condition, rest... ] = [] ) ->
              if !condition?
                result = rule.action.apply currentState
                if result?.then?
                  result.then -> applyRules remaining, currentState
                else
                  applyRules remaining, currentState
              else
                result = Conditions.lookup(engine, condition).apply currentState
                if result?.then?
                  result.then (conditionPassed) ->
                    if conditionPassed then checkConditions rest else applyRules remaining, currentState
                else
                  if result then checkConditions rest else applyRules remaining, currentState

            checkConditions conditions
          else
            applyRules remaining, currentState

      applyRules ( Object.values engine.rules ), currentState

    evaluate engine.initialize state

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

  apply: ( state, args ) ->
    # this is for composition
    # TODO explain
    if args?[0]?
      Object.assign state,
        ( await yield from args[0])
    yield from Rules.run @engine, state

  run: ( state ) ->
    result = Evaluator.run @engine, state
    if result?.then?
      result.then (finalState) => 
        @state = finalState
        @
    else
      @state = result
      @

export default Athena
export { Rules, Conditions, Actions, Evaluator, Athena }