Plugin = require 'plugin'
Db = require 'db'
Event = require 'event'
Subscription = require 'subscription'

exports.client_typingSub = (cb) !->
	cb.subscribe 'typing'

exports.client_typing = (typing) !->
	Subscription.push 'typing', Plugin.userId(), if typing then true else null

exports.client_msg = (text) !->

	msg =
		text: text
		time: 0|(new Date()/1000)
		by: Plugin.userId()

	maxId = 1 + (0|(Db.shared 'maxId'))

	data = {maxId}
	groupData = {}
	groupData[maxId%100] = msg
	data[0|maxId/100] = groupData

	Db.shared data

	name = Plugin.userName()

	Event.create
		unit: 'msg'
		text: "#{name}: #{text}"
		read: [Plugin.userId()]
