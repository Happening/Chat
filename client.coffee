Db = require 'db'
Dom = require 'dom'
Chat = require 'chat'
Event = require 'event'
Form = require 'form'
Obs = require 'obs'
Page = require 'page'
Photo = require 'photo'
Plugin = require 'plugin'
Server = require 'server'
Time = require 'time'
Ui = require 'ui'
{tr} = require 'i18n'

myUserId = Plugin.userId()
if Plugin.groupId() < 0
	contactUserId = 3-myUserId

exports.render = !->
	log 'render'
	
	Dom.style
		fontSize: '90%'

	Chat.renderMessages
		newCount: Obs.peek -> Event.unread() || 0
		content: (msg, num) !->
			return if !msg.isHash()
			byUserId = msg.get('by')
			name = Plugin.userName byUserId

			type = msg.get('type')
			if type in [10,11,12]
				Dom.div !->
					Dom.cls 'chat-system'
					Dom.div !->
						Dom.cls 'chat-content'
						if byUserId is myUserId
							name = tr("You")
						Dom.text if type is 10
								tr("%1 created the happening", name)
							else if type is 11
								tr("%1 joined", name)
							else
								tr("%1 left", name)
						Dom.onTap !->
							Plugin.userInfo(byUserId)
				return

			# normal message
			Dom.div !->
				Dom.cls 'chat-msg'
				if byUserId is myUserId
					Dom.cls 'chat-me'
				
				Ui.avatar Plugin.userAvatar(byUserId), undefined, undefined, !->
					Plugin.userInfo(byUserId)
	
				Dom.div !->
					Dom.cls 'chat-content'
					photoKey = msg.get('photo')
					if photoKey
						Dom.img !->
							Dom.prop 'src', Photo.url(photoKey, 200)
							Dom.onTap !->
								Page.nav !->
									renderPhoto msg, num
										
					else if photoKey is ''
						Dom.div !->
							Dom.cls 'chat-nophoto'
							Dom.text tr("Photo")
							Dom.br()
							Dom.text tr("removed")

					text = msg.get('text')
					Dom.userText text if text

					Dom.div !->
						Dom.cls 'chat-info'
						Dom.text name
						Dom.text " • "
						if time = msg.get('time')
							Time.deltaText time, 'short'
						else
							Dom.text tr("sending")
							Ui.dots()

					Dom.onTap !->
						msgModal msg, num

	typingSub = Obs.create {}
	Server.send 'typingSub', (delta) !-> typingSub.patch delta
	Obs.observe !->
	Dom.div !->
		wasNearBottom = Page.nearBottom()
		users = (Plugin.userName(userId) for userId of typingSub.get() when +userId isnt myUserId)
		
		Dom.style
			fontSize: '80%'
			padding: '4px 0'
			color: '#999'
			height: '16px' # reserve fixed space so redrawing does not trigger new scroll-down
			display: if users.length then '' else 'none'

		if len=users.length
			Dom.text users.join(' & ')
			Dom.text if len>1 then tr(" are typing") else tr(" is typing")
			Ui.dots()
		if wasNearBottom
			Page.scroll 'down', true

	Page.setFooter !->
		Chat.renderInput
			typing: true

renderPhoto = (msg, num) !->

	byUserId = msg.get('by')
	photoKey = msg.get('photo')

	Page.setTitle tr("Photo")
	Page.setSubTitle tr("added by %1", Plugin.userName(byUserId))
	opts = []
	if Photo.share
		opts.push
			label: tr("Share")
			icon: 'share'
			action: !-> Photo.share photoKey
	if Photo.download
		opts.push
			label: tr("Download")
			icon: 'boxdown'
			action: !-> Photo.download photoKey
	if byUserId is myUserId or Plugin.userIsAdmin()
		opts.push
			label: tr("Remove")
			icon: 'trash'
			action: !->
				require('modal').confirm null, tr("Remove photo?"), !->
					Server.sync 'removePhoto', num, !->
						msg.set('photo', '')
					Page.back()
	Page.setActions opts

	Dom.style
		padding: 0
		backgroundColor: '#444'
	#Dom.img !->
	#	Dom.prop src: Photo.url(photoKey, 800)
		
	(require 'photoview').render
		key: photoKey

msgModal = (msg, num) !->
	time = msg.get('time')
	return if !time

	Modal = require('modal')
	byUserId = msg.get('by')

	Modal.show false, !->
		Dom.div !->
			Dom.style
				margin: '-12px'
			Ui.item !->
				Ui.avatar Plugin.userAvatar(byUserId)
				Dom.div !->
					Dom.text tr("Sent by %1", Plugin.userName(byUserId))
					Dom.div !->
						Dom.style fontSize: '80%'
						Dom.text (new Date(time*1000)+'').replace(/\s[\S]+\s[\S]+$/, '')
				Dom.onTap !->
					Plugin.userInfo byUserId

			if !!Form.clipboard and clipboard = Form.clipboard()
				Ui.item !->
					Dom.text tr("Copy text")
					Dom.onTap !->
						clipboard(msg.get('text'))
						require('toast').show tr("Copied to clipboard")
						Modal.remove()

			return if contactUserId and byUserId is contactUserId

			read = Obs.create false
			Server.send 'getRead', num, read.func()
			Ui.item !->
				if read.get() is false
					Dom.div !->
						Dom.style Flex: 1
						Dom.text tr("Seen by")
					Ui.spinner 24

				else if contactUserId
					if read.get(contactUserId)
						Dom.text tr("Seen by %1", Plugin.userName(contactUserId))
					else
						Dom.text tr("Not seen by %1", Plugin.userName(contactUserId))

				else
					count = read.count().get()
					if count >= Plugin.users.count().get()-1
						Dom.text tr("Seen by all members")
					else
						Dom.text tr("Seen by %1 member|s", count)

					Dom.onTap !->
						Modal.show tr("Seen by"), !->
							Dom.div !->
								Dom.style
									margin: '-12px'
									maxHeight: '60%'
									minWidth: '15em'
								Dom.overflow()
								read.iterate (r) !->
									Ui.item !->
										id = r.key()
										Ui.avatar Plugin.userAvatar(id)
										Dom.text Plugin.userName(id)
										Dom.onTap !->
											Plugin.userInfo id
								, (r) -> +r.key()

	, undefined, ['ok', tr("Close")]


Dom.css
	'.msg.tap':
		background: '#ddd !important'
