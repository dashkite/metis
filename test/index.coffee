import assert from "@dashkite/assert"
import { test, success } from "@dashkite/amen"
import print from "@dashkite/amen-console"
import Athena, { SyncEvaluator, AsyncEvaluator } from "../src/index.js"

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
        result = await resolveAsync rules.start input, AsyncEvaluator
        assert.equal "walk", result.activity

      test "negated conditions", ->
        input = { status: "bad" }
        engine = Athena.make()
          .condition([ "good", -> @status == "good" ])
          .action([ "fix", [ "!good" ], -> @status = "good" ])
        result = await resolveAsync engine.start input, AsyncEvaluator
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
        result = await resolveAsync engine.start input, AsyncEvaluator
        assert.equal "shipped", result.state
        assert.equal true, result.paid

      test "composing conditions", ->
        input = { a: true, b: true, c: false }
        engine = Athena.make()
          .condition([ "a", -> @a ])
          .condition([ "b", [ "a" ], -> @b ])
          .action([ "c", [ "b" ], -> @c = true ])
        result = await resolveAsync engine.start input, AsyncEvaluator
        assert.equal true, result.c

      test "engine composition", ->
        input = { a: true, b: false, c: false }
        engine1 = Athena.make()
          .condition([ "a", -> @a ])
          .action([ "b", [ "a" ], -> @b = true ])
        
        engine2 = Athena.make()
          .condition([ "b", -> @b ])
          .action([ "c", [ "b" ], -> @c = true ])
        
        result = await resolveAsync engine2.start input, AsyncEvaluator, engine1.start input, AsyncEvaluator
        assert.equal true, result.c
    ]

    test "Athena Engine Run (Sync - explicit)", [
      test "simple rules", ->
        input = { forecast: "partly sunny" }
        rules = Athena.make()
          .condition([ "weather is good", -> /sunny/.test @forecast ])
          .action([ "go for a walk", [ "weather is good" ], -> @activity = "walk" ])
        result = rules.run input, SyncEvaluator
        assert.equal "walk", result.activity

      test "negated conditions", ->
        input = { status: "bad" }
        engine = Athena.make()
          .condition([ "good", -> @status == "good" ])
          .action([ "fix", [ "!good" ], -> @status = "good" ])
        result = engine.run input, SyncEvaluator
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
        result = engine.run input, SyncEvaluator
        assert.equal "shipped", result.state
        assert.equal true, result.paid

      test "composing conditions", ->
        input = { a: true, b: true, c: false }
        engine = Athena.make()
          .condition([ "a", -> @a ])
          .condition([ "b", [ "a" ], -> @b ])
          .action([ "c", [ "b" ], -> @c = true ])
        result = engine.run input, SyncEvaluator
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
        state1 = engine1.run input, SyncEvaluator
        state2 = engine2.run state1, SyncEvaluator
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
        result = await rules.run input, AsyncEvaluator
        assert.equal "walk", result.activity

      test "negated conditions", ->
        input = { status: "bad" }
        engine = Athena.make()
          .condition([ "good", -> Promise.resolve @status == "good" ])
          .action([ "fix", [ "!good" ], -> Promise.resolve().then => @status = "good" ])
        result = await engine.run input, AsyncEvaluator
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
        result = await engine.run input, AsyncEvaluator
        assert.equal "shipped", result.state
        assert.equal true, result.paid

      test "composing conditions", ->
        input = { a: true, b: true, c: false }
        engine = Athena.make()
          .condition([ "a", -> Promise.resolve @a ])
          .condition([ "b", [ "a" ], -> Promise.resolve @b ])
          .action([ "c", [ "b" ], -> Promise.resolve().then => @c = true ])
        result = await engine.run input, AsyncEvaluator
        assert.equal true, result.c

      test "engine sequential composition", ->
        input = { a: true, b: false, c: false }
        engine1 = Athena.make()
          .condition([ "a", -> Promise.resolve @a ])
          .action([ "b", [ "a" ], -> Promise.resolve().then => @b = true ])
        
        engine2 = Athena.make()
          .condition([ "b", -> Promise.resolve @b ])
          .action([ "c", [ "b" ], -> Promise.resolve().then => @c = true ])
        
        state1 = await engine1.run input, AsyncEvaluator
        state2 = await engine2.run state1, AsyncEvaluator
        assert.equal true, state2.c
    ]

    test "Athena Iterative Rules (.each & Aggregator)", [
      test "basic array transformation & transfer", ->
        input =
          inbox: [
            { id: 1, text: "alpha", processed: false }
            { id: 2, text: "beta", processed: false }
          ]
          outbox: []
        
        engine = Athena.make()
          .each(-> @inbox)
            .condition([ "unprocessed", -> !@processed ])
            .action([
              "process"
              [ "unprocessed" ]
              ( state ) ->
                @processed = true
                state.outbox.push
                  id: @id
                  transformed: @text.toUpperCase()
            ])

        result = engine.run input, mode: "sync"
        assert.equal 2, result.outbox.length
        assert.equal "ALPHA", result.outbox[0].transformed
        assert.equal "BETA", result.outbox[1].transformed
        assert.equal true, result.inbox[0].processed
        assert.equal true, result.inbox[1].processed

      test "combining global state conditions and local item conditions", ->
        input =
          isOpen: true
          remainingBudget: 50
          cart: [
            { id: "a", price: 30, status: "pending" }
            { id: "b", price: 40, status: "pending" }
            { id: "c", price: 20, status: "pending" }
          ]

        engine = Athena.make()
          # Global state condition: checks @isOpen on state (@ = state)
          .condition([ "store-open", -> @isOpen ])

          .each(-> @cart)
            # Local item condition: checks @price <= state.remainingBudget (@ = item)
            .condition([ "affordable", ( state ) -> @price <= state.remainingBudget ])
            .condition([ "pending", -> @status == "pending" ])
            .action([
              "purchase"
              [ "store-open", "affordable", "pending" ]
              ( state ) ->
                @status = "purchased"
                state.remainingBudget -= @price
            ])

        result = engine.run input, mode: "sync"
        # Item 'a' ($30) approved first -> budget remaining becomes $20
        # Item 'b' ($40) is not affordable ($40 > $20)
        # Item 'c' ($20) approved -> budget remaining becomes $0
        assert.equal "purchased", result.cart[0].status
        assert.equal "pending", result.cart[1].status
        assert.equal "purchased", result.cart[2].status
        assert.equal 0, result.remainingBudget

      test "negated local item conditions", ->
        input =
          items: [
            { id: 1, done: true }
            { id: 2, done: false }
          ]

        engine = Athena.make()
          .each(-> @items)
            .condition([ "done", -> @done ])
            .action([
              "mark-done"
              [ "!done" ]
              -> @done = true
            ])

        result = engine.run input, mode: "sync"
        assert.equal true, result.items[0].done
        assert.equal true, result.items[1].done

      test "async conditions in engine and aggregator", ->
        input =
          isOpen: true
          remainingBudget: 50
          cart: [
            { id: "a", price: 30, status: "pending" }
            { id: "b", price: 40, status: "pending" }
          ]

        engine = Athena.make()
          .condition([ "store-open", -> Promise.resolve(@isOpen) ])

          .each(-> @cart)
            .condition([ "affordable", ( state ) -> Promise.resolve(@price <= state.remainingBudget) ])
            .condition([ "pending", -> Promise.resolve(@status == "pending") ])
            .action([
              "purchase"
              [ "store-open", "affordable", "pending" ]
              ( state ) ->
                @status = "purchased"
                state.remainingBudget -= @price
            ])

        result = await engine.run input
        assert.equal "purchased", result.cart[0].status
        assert.equal "pending", result.cart[1].status
        assert.equal 20, result.remainingBudget
    ]
  ]

  process.exit if success then 0 else 1

