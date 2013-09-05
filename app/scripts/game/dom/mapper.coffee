mediator = require "game/mediator"

animProp = Modernizr.prefixed "animation"

animationEnd = {
  "WebkitAnimation": "webkitAnimationEnd"
  "MozAnimation": "animationend"
  "OAnimation": "oanimationend"
  "msAnimation": "MSAnimationEnd"
  "animation": "animationend"}[animProp]

animationStart = {
  "WebkitAnimation": "webkitAnimationStart"
  "MozAnimation": "animationstart"
  "OAnimation": "oanimationstart"
  "msAnimation": "MSAnimationStart"
  "animation": "animationstart"}[animProp]

transitionStart = {
  "WebkitTransition": "webkitTransitionStart"
  "MozTransition": "transitionstart"
  "OTransition": "otransitionstart"
  "msTransition": "MSTransitionStart"
  "transition": "transitionstart"}[animProp]

transitionEnd = {
  "WebkitTransition": "webkitTransitionEnd"
  "MozTransition": "transitionend"
  "OTransition": "otransitionend"
  "msTransition": "MSTransitionEnd"
  "transition": "transitionend"}[animProp]

module.exports = class Mapper
  constructor: (@el) ->

  normaliseStyle: (css) ->
    css = _.clone css

    # border-radius
    br1 = br2 = ""
    for corner in ["TopLeft", "TopRight", "BottomRight", "BottomLeft"]
      br = css["border#{corner}Radius"].split " "
      if br.length is 1
        br1 += br[0]
        br2 += br[0]
      else
        br1 += br[0]
        br2 += br[1]

      br1 += " "
      br2 += " "

    css.borderRadius = "#{br1.trim()} / #{br2.trim()}"

    css

  build: ->
    window.scrollTo 0, 0

    # Pause the mediator for measuring
    mediator.paused = true

    map = []
    nodes = @el.children

    for node in nodes
      obj = @measureNode node

      obj.onUpdate = -> null

      @setupUpdater node, obj

      obj.el = node

      data = {}
      for attribute in node.attributes
        name = attribute.name
        if (m = name.match /^data-[a-z1-9\-]+/) isnt null
          data[m[0].replace /^data-/, ""] = attribute.value

      obj.data = data

      if data.ignore is undefined then map.push obj

    delay = 5

    frameMonitor = =>
      delay--
      if delay <= 0
        mediator.paused = false
        mediator.off "frame:paused", frameMonitor

    mediator.on "frame:paused", frameMonitor

    @map = map

  setupUpdater: (node, orig) ->
    last = orig

    updater = =>
      mod = @measureNode node
      elOffset = @el.getBoundingClientRect()

      mod.x -= elOffset.left
      mod.y -= elOffset.top

      if (mod.type is last.type) and (mod.type in ["circle", "rect"])
        # A simple thing. Has to be either translate or scale.
        if (mod.x isnt last.x or mod.y isnt last.y) and (mod.width isnt last.width or mod.height isnt last.height)
          mod.updateType = "transformTranslate"

        else if (mod.x isnt last.x or mod.y isnt last.y)
          mod.updateType = "translate"

        else if (mod.width isnt last.width or mod.height isnt last.height)
          mod.updateType = "transform"

        orig.onUpdate mod

      last = mod

    node.addEventListener animationStart, (e) ->
      mediator.on "frame:render", updater
      node.addEventListener animationEnd, (e) ->
        mediator.off "frame:render", updater
      , false
    , false

    node.addEventListener transitionStart, (e) ->
      mediator.on "frame:render", updater
      mediator.on transitionEnd,  (e) ->
        mediator.off "frame:render", updater
      , false
    , false

    # Check if the thing is currently animating:
    mediator.once "frame:paused", =>
      mediator.once "frame:paused", =>
        a = @measureNode node
        mediator.once "frame:paused", =>
          b = @measureNode node
          unless _.isEqual a, b
            mediator.on "frame:render", updater
            mediator.on transitionEnd,  (e) ->
              mediator.off "frame:render", updater
            , false
            mediator.on animationEnd,  (e) ->
              mediator.off "frame:render", updater
            , false

    anim = node.style.animation or node.style[animProp]

    console.log anim

  measureNode: (node) =>
    bounds = node.getBoundingClientRect()
    style = @normaliseStyle window.getComputedStyle node

    c =
      x: (bounds.left + bounds.right) / 2
      y: (bounds.top + bounds.bottom) / 2

    if style.borderRadius isnt "0px 0px 0px 0px / 0px 0px 0px 0px"
      br = style.borderRadius.replace("/ ", "").split " "
      uniform = yes

      last = br[0]
      for r in br
        if r isnt last
          uniform = no

      if uniform
        r = parseFloat(br[0])

        w = bounds.width - r*2
        h = bounds.height - r*2

        if (bounds.width is bounds.height) and (r >= bounds.width / 2) and (r >= bounds.height / 2)
          # Perfect Circle
          obj =
            type: "circle"
            x: c.x
            y: c.y
            radius: bounds.width / 2

        else if (bounds.width > bounds.height) and (bounds.height is r*2)
          # Landscape Pill
          obj =
            type: "compound"
            x: c.x
            y: c.y
            shapes: [
              type: "rect"
              x: 0
              y: 0
              width: w
              height: bounds.height
            ,
              type: "circle"
              x: -w/2
              y: 0
              radius: r
            ,
              type: "circle"
              x: w/2
              y: 0
              radius: r
            ]

        else if (bounds.height > bounds.width) and (bounds.width is r*2)
          # Portrait Pill
          obj =
            type: "compound"
            x: c.x
            y: c.y
            shapes: [
              type: "rect"
              x: 0
              y: 0
              width: bounds.width
              height: h
            ,
              type: "circle"
              x: 0
              y: -h/2
              radius: r
            ,
              type: "circle"
              x: 0
              y: h/2
              radius: r
            ]

        else
          # Uniform rounded rect
          obj =
            type: "compound"
            x: c.x
            y: c.y
            shapes: [
              type: "rect"
              x: 0
              y: 0
              width: bounds.width
              height: h
            ,
              type: "rect"
              x: 0
              y: 0
              width: w
              height: bounds.height
            ,
              type: "circle"
              x: w/2
              y: h/2
              radius: r
            ,
              type: "circle"
              x: -w/2
              y: h/2
              radius: r
            ,
              type: "circle"
              x: -w/2
              y: -h/2
              radius: r
            ,
              type: "circle"
              x: w/2
              y: -h/2
              radius: r
            ]

      else
        console.log "Err: Not uniform"
        console.log (_.clone bounds), (_.clone style)

    else
      obj =
        type: "rect"
        x: c.x
        y: c.y
        width: bounds.width
        height: bounds.height

    obj
