Db = require 'db'
Event = require 'event'
Photo = require 'photo'
Plugin = require 'plugin'
Subscription = require 'subscription'
{tr} = require 'i18n'

exports.client_msg = exports.client_chat = (text) !->
	post {text}, text

exports.onPhoto = (info) !->
	post {photo: info.key}, tr("(photo)")

post = (msg, text) !->
	msg.time = 0|(new Date()/1000)
	msg.by = Plugin.userId()

	id = Db.shared.modify 'maxId', (v) -> (v||0)+1
	log "#{id} / #{0|id/100} #{id%100}"
	Db.shared.set 0|id/100, id%100, msg

	name = Plugin.userName()
	Event.create
		text: if Plugin.groupId() < 0 then text else "#{name}: #{text}"
		senderText: "You: #{text}" if Plugin.groupId() > 0
		sender: Plugin.userId()

exports.onJoin = onJoin = (userId, left = false) !->
	msg =
		time: 0|(new Date()/1000)
		by: userId
		type: if left then 12 else 11

	id = Db.shared.modify 'maxId', (v) -> (v||0)+1
	Db.shared.set 0|id/100, id%100, msg

	if !left
		Event.create
			text: "#{Plugin.userName(userId)} joined"
			senderText: "You joined"
			ticker: "#{Plugin.userName(userId)} joined '#{Plugin.groupName()}'"
			sender: userId

exports.onLeave = (userId) !->
	onJoin userId, true
	
exports.client_typingSub = (cb) !->
	cb.subscribe 'typing'

exports.client_typing = (typing) !->
	patch = {}
	patch[Plugin.userId()] = if typing then true else null
	Subscription.push 'typing', patch

exports.client_getRead = (id, cb) !->
	maxId = Db.shared.get('maxId')
	byUserId = Db.shared.get 0|id/100, id%100, 'by'

	read = {}
	for userId in Plugin.userIds()
		continue if userId is byUserId
		unread = Event.getUnread(userId)
		read[userId] = true if maxId - unread >= id
	cb.reply read

exports.client_removePhoto = (num) !->
	msg = Db.shared.ref 0|num/100, num%100
	return if !msg.get('photo') or (msg.get('by') isnt Plugin.userId() and !Plugin.userIsAdmin())

	Photo.remove msg.get('photo')
	msg.set 'photo', ''
