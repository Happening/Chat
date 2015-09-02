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

	Dom.style
		fontSize: '90%'

	Chat.renderMessages
		newCount: Obs.peek -> Event.unread() || 0
		content: messageContent = (msg, num) !->
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

				Ui.avatar Plugin.userAvatar(byUserId),
					onTap: !->
						Plugin.userInfo(byUserId)

				Dom.div !->
					Dom.cls 'chat-content'
					if  (photoUpload = msg.get("photoUpload"))
						Dom.div !->
							Dom.style
								background: "url(#{msg.get('thumb')}) 50% 50% no-repeat"
								backgroundSize: 'cover'
								width: "90px"
								height: "70px"
								padding: "40px 0 0 60px"
							Ui.spinner 30
					else if (photoKey = msg.get('photo'))
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

					if !photoUpload
						Dom.onTap !->
							msgModal msg, num

	Obs.observe !->
		Photo.uploads.iterate (newPhoto) !-> # Previews of image uploads
			Page.scroll 'down', true # Scroll to the preview of the image that is getting uploaded
			preview = Obs.create newPhoto.get()
			preview.set "photoUpload", true
			preview.set "by", Plugin.userId()
			messageContent(preview)

	typingSub = Obs.create {}
	Server.send 'typingSub', (delta) !-> typingSub.patch delta
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
	Dom.style
		padding: 0

	content = (identifier) !->
		message = Db.shared.ref(0|identifier/100, identifier%100)
		return if !message?
		byUserId = message.get('by')
		photoKey = message.get('photo')
		return if !byUserId? or !photoKey?
		Page.setTitle tr("Posted by %1", Plugin.userName(byUserId))
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
						Server.sync 'removePhoto', identifier, !->
							message.set('photo', '')
						Page.back()
		Page.setActions opts

	(require 'photoview').render
		current: num
		getNeighbourIds: (id) ->
			max = Db.shared.peek('maxId')||0
			right = parseInt(id)-1
			while !((rightValue = Db.shared.peek(0|right/100, right%100, "photo"))?) && right > 0
				right--
			left = parseInt(id)+1
			while !((leftValue = Db.shared.peek(0|left/100, left%100, "photo"))?) && left <= max
				left++
			left = undefined if !leftValue? or leftValue.length is 0
			right = undefined if !rightValue? or rightValue.length is 0
			[left,right]
		idToPhotoKey: (id) ->
			Db.shared.get 0|id/100, id%100, 'photo'
		fullHeight: true
		content: content

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
