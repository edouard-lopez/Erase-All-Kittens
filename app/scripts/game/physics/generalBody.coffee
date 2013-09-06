World = require "game/physics/world"

Vector = Box2D.Common.Math.b2Vec2
b2AABB = Box2D.Collision.b2AABB
b2BodyDef = Box2D.Dynamics.b2BodyDef
b2Body = Box2D.Dynamics.b2Body
b2FixtureDef = Box2D.Dynamics.b2FixtureDef
b2Fixture = Box2D.Dynamics.b2Fixture
b2World = Box2D.Dynamics.b2World
b2MassData = Box2D.Collision.Shapes.b2MassData
b2PolygonShape = Box2D.Collision.Shapes.b2PolygonShape
b2CircleShape = Box2D.Collision.Shapes.b2CircleShape
b2DebugDraw = Box2D.Dynamics.b2DebugDraw
b2MouseJointDef =  Box2D.Dynamics.Joints.b2MouseJointDef

scale = World::scale
scl = 1.2

module.exports = class GeneralBody extends Backbone.Model
  constructor: (def) ->
    @bd = new b2BodyDef()
    @def = def
    if def.width is 0 then def.width = 1
    if def.height is 0 then def.height = 1
    @data = if def.data isnt undefined then def.data else {}

  initialize: ->
    bd = @bd
    s = @def

    bd.position.Set s.x / scale, s.y / scale

    @fds = []

    @setupUpdates s

    @createFixes s

    ids = ["*"]
    if s.id isnt undefined
      ids.push s.id

    if s.el isnt undefined
      el = s.el
      ids.push "#" + el.id if el.id isnt ""
      ids.push "." + className for className in el.classList

    ids.push @data.id if @data.id isnt undefined

    @ids = ids

  newFixture: =>
    fd = new b2FixtureDef()
    fd.density = 1
    fd.friction = 0.7
    fd.restitution = 0.3

    if @data.sensor is true
      fd.isSensor = true

    @fds.push fd

    fd

  createFixes: (def, position=false) =>
    def = _.defaults def, GeneralBody::defDefaults
    if def.type is "circle"
      fd = @newFixture()
      fd.shape = new b2CircleShape def.radius / scale
      def.width = def.height = def.radius
      if position
        fd.shape.SetLocalPosition new Vector def.x/scale, def.y/scale
    else if def.type is "rect"
      fd = @newFixture()
      fd.shape = new b2PolygonShape()
      if position
        fd.shape.SetAsOrientedBox def.width / scale / 2, def.height / scale / 2, (new Vector def.x/scale, def.y/scale), 0
      else
        fd.shape.SetAsBox def.width / scale / 2, def.height / scale / 2
    else if def.type is "compound"
      for shape in def.shapes
        @createFixes shape, true

  removeFixes: =>
    @body.DestroyFixture fd for fd in @fixes
    @fds = []
    @fixes = []

  attachFixes: =>
    @fixes = (@body.CreateFixture fd for fd in @fds)

  attachTo: (world) =>
    body = world.world.CreateBody @bd
    body.SetUserData @
    @body = body
    @attachFixes()
    @world = world

  setupUpdates: (def) =>
    hasUpdated = false
    lPos = undefined

    def.onUpdate = (update) =>
      unless hasUpdated
        hasUpdated = true
        @body.SetType b2Body.b2_kinematicBody if @body.GetType() is b2Body.b2_staticBody

      console.log _.clone @body

      if update.updateType in ["translate", "translateTransform"]
        pos =
          x: update.x
          y: update.y

        if lPos isnt undefined
          @linearVelocity x: pos.x - lPos.x, y: pos.y - lPos.y

        @positionUncorrected pos

        lPos = pos

      if update.updateType in ["transform", "translateTransform"]
        @removeFixes()
        @createFixes update
        @attachFixes()

      if update.stop
        @linearVelocity x: 0, y: 0

  destroy: =>
    if @world isnt undefined then @world.world.DestroyBody @body

  halt: =>
    b = @body
    b.SetAngularVelocity 0
    b.SetLinearVelocity new Vector 0, 0

  reset: =>
    @halt()
    @position x:0, y: 0
    @body.SetAngle 0

  isAwake: -> @body.GetType() isnt 0 and @body.IsAwake()

  position: (p) ->
    if p is undefined
      p = @body.GetPosition()
      return x: (p.x * scale) - @def.x, y: (p.y * scale) - @def.y
    else
      @body.SetPosition new Vector (p.x + @def.x) / scale, (p.y + @def.y) / scale

  positionUncorrected:  (p) ->
    if p is undefined
      p = @body.GetPosition()
      return x: (p.x * scale), y: (p.y * scale)
    else
      @body.SetPosition new Vector p.x / scale, p.y / scale

  absolutePosition: ->
    p = @body.GetPosition()
    x: p.x * scale, y: p.y * scale

  linearVelocity: (v) ->
    if v is undefined
      v = @body.GetLinearVelocity()
      return x: v.x * scale, y: v.y * scale
    else
      @body.SetLinearVelocity new Vector v.x * scl, v.y * scl

  angle: -> @body.GetAngle()

  angularVelocity: -> @body.GetAngularVelocity()

  defDefaults:
    x: 0
    y: 0
    width: 1
    height: 1
    radius: 0
    type: "rect"
