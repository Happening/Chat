Db = require 'db'
Event = require 'event'
Plugin = require 'plugin'
Subscription = require 'subscription'

exports.client_typingSub = (cb) !->
	cb.subscribe 'typing'

exports.client_typing = (typing) !->
	patch = {}
	patch[Plugin.userId()] = if typing then true else null
	Subscription.push 'typing', patch

exports.client_msg = (text) !->

	msg =
		text: text
		time: 0|(new Date()/1000)
		by: Plugin.userId()

	id = Db.shared.modify 'maxId', (v) -> (v||0)+1
	log "#{id} / #{0|id/100} #{id%100}"
	Db.shared.set 0|id/100, id%100, msg

	name = Plugin.userName()

	Event.create
		unit: 'msg'
		text: "#{name}: #{text}"
		read: [Plugin.userId()]
