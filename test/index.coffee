import assert from "@dashkite/assert"
import { test, success } from "@dashkite/amen"
import print from "@dashkite/amen-console"
import Athena from "../src/index.js"

resolveAsync = ( iterator ) ->
  lastEvent = null
  for await event from iterator
    lastEvent = event
  lastEvent?.state

do ->
  print await test "Athena Rules Engine", [

    test "Athena Engine Async (apply)", [
      test "simple rules", ->
        input = { forecast: "partly sunny" }
        rules = Athena.make()
          .condition([ "weather is good", -> /sunny/.test @forecast ])
          .action([ "go for a walk", [ "weather is good" ], -> @activity = "walk" ])
        result = await resolveAsync rules.apply input
        assert.equal "walk", result.activity

      test "negated conditions", ->
        input = { status: "bad" }
        engine = Athena.make()
          .condition([ "good", -> @status == "good" ])
          .action([ "fix", [ "!good" ], -> @status = "good" ])
        result = await resolveAsync engine.apply input
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
        result = await resolveAsync engine.apply input
        assert.equal "shipped", result.state
        assert.equal true, result.paid

      test "composing conditions", ->
        input = { a: true, b: true, c: false }
        engine = Athena.make()
          .condition([ "a", -> @a ])
          .condition([ "b", [ "a" ], -> @b ])
          .action([ "c", [ "b" ], -> @c = true ])
        result = await resolveAsync engine.apply input
        assert.equal true, result.c

      test "engine composition", ->
        input = { a: true, b: false, c: false }
        engine1 = Athena.make()
          .condition([ "a", -> @a ])
          .action([ "b", [ "a" ], -> @b = true ])
        
        engine2 = Athena.make()
          .condition([ "b", -> @b ])
          .action([ "c", [ "b" ], -> @c = true ])
        
        result = await resolveAsync engine2.apply input, [ engine1.apply input ]
        assert.equal true, result.c
    ]

    test "Athena Engine Run (Sync)", [
      test "simple rules", ->
        input = { forecast: "partly sunny" }
        rules = Athena.make()
          .condition([ "weather is good", -> /sunny/.test @forecast ])
          .action([ "go for a walk", [ "weather is good" ], -> @activity = "walk" ])
        rules.run input
        assert.equal "walk", rules.state.activity

      test "negated conditions", ->
        input = { status: "bad" }
        engine = Athena.make()
          .condition([ "good", -> @status == "good" ])
          .action([ "fix", [ "!good" ], -> @status = "good" ])
        engine.run input
        assert.equal "good", engine.state.status

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
        engine.run input
        assert.equal "shipped", engine.state.state
        assert.equal true, engine.state.paid

      test "composing conditions", ->
        input = { a: true, b: true, c: false }
        engine = Athena.make()
          .condition([ "a", -> @a ])
          .condition([ "b", [ "a" ], -> @b ])
          .action([ "c", [ "b" ], -> @c = true ])
        engine.run input
        assert.equal true, engine.state.c

      test "engine sequential composition", ->
        input = { a: true, b: false, c: false }
        engine1 = Athena.make()
          .condition([ "a", -> @a ])
          .action([ "b", [ "a" ], -> @b = true ])
        
        engine2 = Athena.make()
          .condition([ "b", -> @b ])
          .action([ "c", [ "b" ], -> @c = true ])
        
        # Sequentially run mutating engines
        engine1.run input
        engine2.run engine1.state
        assert.equal true, engine2.state.c
    ]

    test "Athena Engine Run (Async)", [
      test "simple rules", ->
        input = { forecast: "partly sunny" }
        rules = Athena.make()
          .condition([ "weather is good", -> Promise.resolve /sunny/.test @forecast ])
          .action([ "go for a walk", [ "weather is good" ], -> Promise.resolve().then => @activity = "walk" ])
        await rules.run input
        assert.equal "walk", rules.state.activity

      test "negated conditions", ->
        input = { status: "bad" }
        engine = Athena.make()
          .condition([ "good", -> Promise.resolve @status == "good" ])
          .action([ "fix", [ "!good" ], -> Promise.resolve().then => @status = "good" ])
        await engine.run input
        assert.equal "good", engine.state.status

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
        await engine.run input
        assert.equal "shipped", engine.state.state
        assert.equal true, engine.state.paid

      test "composing conditions", ->
        input = { a: true, b: true, c: false }
        engine = Athena.make()
          .condition([ "a", -> Promise.resolve @a ])
          .condition([ "b", [ "a" ], -> Promise.resolve @b ])
          .action([ "c", [ "b" ], -> Promise.resolve().then => @c = true ])
        await engine.run input
        assert.equal true, engine.state.c

      test "engine sequential composition", ->
        input = { a: true, b: false, c: false }
        engine1 = Athena.make()
          .condition([ "a", -> Promise.resolve @a ])
          .action([ "b", [ "a" ], -> Promise.resolve().then => @b = true ])
        
        engine2 = Athena.make()
          .condition([ "b", -> Promise.resolve @b ])
          .action([ "c", [ "b" ], -> Promise.resolve().then => @c = true ])
        
        await engine1.run input
        await engine2.run engine1.state
        assert.equal true, engine2.state.c
    ]
  ]

  process.exit if success then 0 else 1
