import assert from "@dashkite/assert"
import { test, success } from "@dashkite/amen"
import print from "@dashkite/amen-console"
import Athena, { Evaluators } from "../src/index.js"

resolveAsync = ( iterator ) ->
  lastEvent = null
  for await event from iterator
    lastEvent = event
  lastEvent?.state

do ->
  print await test "Athena Rules Engine", [

    test "Athena Engine Async (start - default)", [
      test "simple rules", ->
        input = { forecast: "partly sunny" }
        rules = Athena.make()
          .condition([ "weather is good", -> /sunny/.test @forecast ])
          .action([ "go for a walk", [ "weather is good" ], -> @activity = "walk" ])
        result = await resolveAsync rules.start input
        assert.equal "walk", result.activity

      test "negated conditions", ->
        input = { status: "bad" }
        engine = Athena.make()
          .condition([ "good", -> @status == "good" ])
          .action([ "fix", [ "!good" ], -> @status = "good" ])
        result = await resolveAsync engine.start input
        assert.equal "good", result.status

      test "multi-step resolution", ->
        input = { state: "placed", paid: false }
        engine = Athena.make()
          .condition([ "placed", -> @state == "placed" ])
          .condition([ "paid", -> @paid == true ])
          .action([ "pay", [ "placed" ], -> 
            @paid = true
            @state = "processing"
          ])
          .action([ "ship", [ "paid" ], ->
            @state = "shipped"
          ])
        result = await resolveAsync engine.start input
        assert.equal "shipped", result.state
        assert.equal true, result.paid

      test "composing conditions", ->
        input = { a: true, b: true, c: false }
        engine = Athena.make()
          .condition([ "a", -> @a ])
          .condition([ "b", [ "a" ], -> @b ])
          .action([ "c", [ "b" ], -> @c = true ])
        result = await resolveAsync engine.start input
        assert.equal true, result.c

      test "engine composition", ->
        input = { a: true, b: false, c: false }
        engine1 = Athena.make()
          .condition([ "a", -> @a ])
          .action([ "b", [ "a" ], -> @b = true ])
        
        engine2 = Athena.make()
          .condition([ "b", -> @b ])
          .action([ "c", [ "b" ], -> @c = true ])
        
        result = await resolveAsync engine2.start input, { delegator: engine1.start input }
        assert.equal true, result.c
    ]

    test "Athena Engine Async (start - explicit)", [
      test "simple rules", ->
        input = { forecast: "partly sunny" }
        rules = Athena.make()
          .condition([ "weather is good", -> /sunny/.test @forecast ])
          .action([ "go for a walk", [ "weather is good" ], -> @activity = "walk" ])
        result = await resolveAsync rules.start input, Evaluators.asyncIterator
        assert.equal "walk", result.activity

      test "negated conditions", ->
        input = { status: "bad" }
        engine = Athena.make()
          .condition([ "good", -> @status == "good" ])
          .action([ "fix", [ "!good" ], -> @status = "good" ])
        result = await resolveAsync engine.start input, Evaluators.asyncIterator
        assert.equal "good", result.status

      test "multi-step resolution", ->
        input = { state: "placed", paid: false }
        engine = Athena.make()
          .condition([ "placed", -> @state == "placed" ])
          .condition([ "paid", -> @paid == true ])
          .action([ "pay", [ "placed" ], -> 
            @paid = true
            @state = "processing"
          ])
          .action([ "ship", [ "paid" ], ->
            @state = "shipped"
          ])
        result = await resolveAsync engine.start input, Evaluators.asyncIterator
        assert.equal "shipped", result.state
        assert.equal true, result.paid

      test "composing conditions", ->
        input = { a: true, b: true, c: false }
        engine = Athena.make()
          .condition([ "a", -> @a ])
          .condition([ "b", [ "a" ], -> @b ])
          .action([ "c", [ "b" ], -> @c = true ])
        result = await resolveAsync engine.start input, Evaluators.asyncIterator
        assert.equal true, result.c

      test "engine composition", ->
        input = { a: true, b: false, c: false }
        engine1 = Athena.make()
          .condition([ "a", -> @a ])
          .action([ "b", [ "a" ], -> @b = true ])
        
        engine2 = Athena.make()
          .condition([ "b", -> @b ])
          .action([ "c", [ "b" ], -> @c = true ])
        
        result = await resolveAsync engine2.start input, Evaluators.asyncIterator, engine1.start input, Evaluators.asyncIterator
        assert.equal true, result.c
    ]

    test "Athena Engine Run (Sync - explicit)", [
      test "simple rules", ->
        input = { forecast: "partly sunny" }
        rules = Athena.make()
          .condition([ "weather is good", -> /sunny/.test @forecast ])
          .action([ "go for a walk", [ "weather is good" ], -> @activity = "walk" ])
        result = rules.run input, Evaluators.syncCollector
        assert.equal "walk", result.activity

      test "negated conditions", ->
        input = { status: "bad" }
        engine = Athena.make()
          .condition([ "good", -> @status == "good" ])
          .action([ "fix", [ "!good" ], -> @status = "good" ])
        result = engine.run input, Evaluators.syncCollector
        assert.equal "good", result.status

      test "multi-step resolution", ->
        input = { state: "placed", paid: false }
        engine = Athena.make()
          .condition([ "placed", -> @state == "placed" ])
          .condition([ "paid", -> @paid == true ])
          .action([ "pay", [ "placed" ], -> 
            @paid = true
            @state = "processing"
          ])
          .action([ "ship", [ "paid" ], ->
            @state = "shipped"
          ])
        result = engine.run input, Evaluators.syncCollector
        assert.equal "shipped", result.state
        assert.equal true, result.paid

      test "composing conditions", ->
        input = { a: true, b: true, c: false }
        engine = Athena.make()
          .condition([ "a", -> @a ])
          .condition([ "b", [ "a" ], -> @b ])
          .action([ "c", [ "b" ], -> @c = true ])
        result = engine.run input, Evaluators.syncCollector
        assert.equal true, result.c

      test "engine sequential composition", ->
        input = { a: true, b: false, c: false }
        engine1 = Athena.make()
          .condition([ "a", -> @a ])
          .action([ "b", [ "a" ], -> @b = true ])
        
        engine2 = Athena.make()
          .condition([ "b", -> @b ])
          .action([ "c", [ "b" ], -> @c = true ])
        
        # Sequentially run mutating engines
        state1 = engine1.run input, Evaluators.syncCollector
        state2 = engine2.run state1, Evaluators.syncCollector
        assert.equal true, state2.c
    ]

    test "Athena Engine Run (Async - default)", [
      test "simple rules", ->
        input = { forecast: "partly sunny" }
        rules = Athena.make()
          .condition([ "weather is good", -> Promise.resolve /sunny/.test @forecast ])
          .action([ "go for a walk", [ "weather is good" ], -> Promise.resolve().then => @activity = "walk" ])
        result = await rules.run input
        assert.equal "walk", result.activity

      test "negated conditions", ->
        input = { status: "bad" }
        engine = Athena.make()
          .condition([ "good", -> Promise.resolve @status == "good" ])
          .action([ "fix", [ "!good" ], -> Promise.resolve().then => @status = "good" ])
        result = await engine.run input
        assert.equal "good", result.status

      test "multi-step resolution", ->
        input = { state: "placed", paid: false }
        engine = Athena.make()
          .condition([ "placed", -> Promise.resolve @state == "placed" ])
          .condition([ "paid", -> Promise.resolve @paid == true ])
          .action([ "pay", [ "placed" ], -> 
            Promise.resolve().then =>
              @paid = true
              @state = "processing"
          ])
          .action([ "ship", [ "paid" ], ->
            Promise.resolve().then =>
              @state = "shipped"
          ])
        result = await engine.run input
        assert.equal "shipped", result.state
        assert.equal true, result.paid

      test "composing conditions", ->
        input = { a: true, b: true, c: false }
        engine = Athena.make()
          .condition([ "a", -> Promise.resolve @a ])
          .condition([ "b", [ "a" ], -> Promise.resolve @b ])
          .action([ "c", [ "b" ], -> Promise.resolve().then => @c = true ])
        result = await engine.run input
        assert.equal true, result.c

      test "engine sequential composition", ->
        input = { a: true, b: false, c: false }
        engine1 = Athena.make()
          .condition([ "a", -> Promise.resolve @a ])
          .action([ "b", [ "a" ], -> Promise.resolve().then => @b = true ])
        
        engine2 = Athena.make()
          .condition([ "b", -> Promise.resolve @b ])
          .action([ "c", [ "b" ], -> Promise.resolve().then => @c = true ])
        
        state1 = await engine1.run input
        state2 = await engine2.run state1
        assert.equal true, state2.c
    ]

    test "Athena Engine Run (Async - explicit)", [
      test "simple rules", ->
        input = { forecast: "partly sunny" }
        rules = Athena.make()
          .condition([ "weather is good", -> Promise.resolve /sunny/.test @forecast ])
          .action([ "go for a walk", [ "weather is good" ], -> Promise.resolve().then => @activity = "walk" ])
        result = await rules.run input, Evaluators.asyncCollector
        assert.equal "walk", result.activity

      test "negated conditions", ->
        input = { status: "bad" }
        engine = Athena.make()
          .condition([ "good", -> Promise.resolve @status == "good" ])
          .action([ "fix", [ "!good" ], -> Promise.resolve().then => @status = "good" ])
        result = await engine.run input, Evaluators.asyncCollector
        assert.equal "good", result.status

      test "multi-step resolution", ->
        input = { state: "placed", paid: false }
        engine = Athena.make()
          .condition([ "placed", -> Promise.resolve @state == "placed" ])
          .condition([ "paid", -> Promise.resolve @paid == true ])
          .action([ "pay", [ "placed" ], -> 
            Promise.resolve().then =>
              @paid = true
              @state = "processing"
          ])
          .action([ "ship", [ "paid" ], ->
            Promise.resolve().then =>
              @state = "shipped"
          ])
        result = await engine.run input, Evaluators.asyncCollector
        assert.equal "shipped", result.state
        assert.equal true, result.paid

      test "composing conditions", ->
        input = { a: true, b: true, c: false }
        engine = Athena.make()
          .condition([ "a", -> Promise.resolve @a ])
          .condition([ "b", [ "a" ], -> Promise.resolve @b ])
          .action([ "c", [ "b" ], -> Promise.resolve().then => @c = true ])
        result = await engine.run input, Evaluators.asyncCollector
        assert.equal true, result.c

      test "engine sequential composition", ->
        input = { a: true, b: false, c: false }
        engine1 = Athena.make()
          .condition([ "a", -> Promise.resolve @a ])
          .action([ "b", [ "a" ], -> Promise.resolve().then => @b = true ])
        
        engine2 = Athena.make()
          .condition([ "b", -> Promise.resolve @b ])
          .action([ "c", [ "b" ], -> Promise.resolve().then => @c = true ])
        
        state1 = await engine1.run input, Evaluators.asyncCollector
        state2 = await engine2.run state1, Evaluators.asyncCollector
        assert.equal true, state2.c
    ]
  ]

  process.exit if success then 0 else 1
