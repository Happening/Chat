Db = require 'db'
Event = require 'event'
Plugin = require 'plugin'
Subscription = require 'subscription'
Photo = require 'photo'
{tr} = require 'i18n'

exports.client_typingSub = (cb) !->
	cb.subscribe 'typing'

exports.client_typing = (typing) !->
	patch = {}
	patch[Plugin.userId()] = if typing then true else null
	Subscription.push 'typing', patch

exports.client_msg = (text) !->
	post {text}, text

post = (msg, text, unit=tr('msg')) !->
	msg.time = 0|(new Date()/1000)
	msg.by = Plugin.userId()

	id = Db.shared.modify 'maxId', (v) -> (v||0)+1
	log "#{id} / #{0|id/100} #{id%100}"
	Db.shared.set 0|id/100, id%100, msg

	name = Plugin.userName()
	Event.create
		unit: unit
		text: "#{name}: #{text}"
		read: [Plugin.userId()]

exports.onPhoto = (info) !->
	post {photo: info.key}, tr('photo'), tr('photo')

exports.client_removePhoto = (num) !->
	msg = Db.shared.ref 0|num/100, num%100
	return if !msg.get('photo') or (msg.get('by') isnt Plugin.userId() and !Plugin.userIsAdmin())

	Photo.remove msg.get('photo')
	msg.set 'photo', ''
