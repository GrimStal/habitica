express = require 'express'
router = new express.Router()

scoring = require '../app/scoring'
_ = require 'underscore'
validator = require 'derby-auth/node_modules/validator'
check = validator.check
snaitize = validator.sanitize
icalendar = require 'icalendar'

NO_TOKEN_OR_UID = err: "You must include a token and uid (user id) in your request"
NO_USER_FOUND = err: "No user found."

# ---------- /v1 API ------------
# Every url added beneath router is prefaced by /v1

###
  v1 API. Requires user-id and apiToken, task-id, direction. Test with:
  curl -X POST -H "Content-Type:application/json" -d '{"apiToken":"{TOKEN}"}' localhost:3000/v1/users/{UID}/tasks/productivity/up
###

router.get '/status', (req, res) ->
  res.json
    status: 'up'

router.get '/user', (req, res) ->
  { uid, token } = req.query
  return res.json 500, NO_TOKEN_OR_UID unless uid || token

  model = req.getModel()
  query = model.query('users').withIdAndToken(uid, token)

  query.fetch (err, user) ->
    return res.json 500, err: err if err
    self = user.at(0).get()
    return res.json 500, NO_USER_FOUND if !self || _.isEmpty(self)

    return res.json self

router.post '/user/task', (req, res) ->
  { uid, token } = req.body
  task = { title, text, type, value, note } = req.body
  return res.json 500, NO_TOKEN_OR_UID unless uid || token

  model = req.getModel()
  query = model.query('users').withIdAndToken(uid, token)

  query.fetch (err, user) ->
    return res.json 500, err: err if err
    self = user.at(0).get()
    return res.json 500, NO_USER_FOUND if !self || _.isEmpty(self)
    return res.json 500, err: "type must be habit, todo, daily, reward" unless /habit|todo|daily|reward/.test type
    return res.json 500, err: "must have a title" unless check(title).notEmpty()
    return res.json 500, err: "must have text" unless check(text).notEmpty()
    value ||= 0

    #model.ref '_user', user
    model.refList "_#{type}List", "_user.tasks", "_user.#{type}Ids"
    model.push "_#{type}List", task

    return res.json 201, task

router.get '/users/:uid/calendar.ics', (req, res) ->
  #return next() #disable for now
  {uid} = req.params
  {apiToken} = req.query

  model = req.getModel()
  query = model.query('users').withIdAndToken(uid, apiToken)
  query.fetch (err, result) ->
    return res.send(500, err) if err
    tasks = result.at(0).get('tasks')
    #      tasks = result[0].tasks
    tasksWithDates = _.filter tasks, (task) -> !!task.date
    return res.send(500, "No events found") if _.isEmpty(tasksWithDates)

    ical = new icalendar.iCalendar()
    ical.addProperty('NAME', 'HabitRPG')
    _.each tasksWithDates, (task) ->
      event = new icalendar.VEvent(task.id);
      event.setSummary(task.text);
      d = new Date(task.date)
      d.date_only = true
      event.setDate d
      ical.addComponent event
    res.type('text/calendar')
    formattedIcal = ical.toString().replace(/DTSTART\:/g, 'DTSTART;VALUE=DATE:')
    res.send(200, formattedIcal)

module.exports = router
