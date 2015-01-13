Db = require 'db'
Dom = require 'dom'
Form = require 'form'
Icon = require 'icon'
Loglist = require 'loglist'
Obs = require 'obs'
Page = require 'page'
Photo = require 'photo'
Plugin = require 'plugin'
Server = require 'server'
Time = require 'time'
Ui = require 'ui'
try
	Event = require 'event'
{tr} = require 'i18n'

shared = Db.shared
myUserId = Plugin.userId()

if Plugin.groupId() < 0
	contactUserId = 3-myUserId

exports.render = !->

	log 'render'

	isRendered = false
		# False when first-render, true for granular redraws
	
	Dom.style
		fontSize: '90%'

	unreadCount = Obs.peek -> if Event then Event.unread() else 0
	firstO = Page.state.ref('first')
	maxIdO = shared.ref('maxId')
	if !firstO.peek()
		heightCount = Math.round(Dom.viewport.peek('height')/50) + 5
		msgCount = Math.max(10, (if unreadCount > 100 then 0 else unreadCount), heightCount)
			# if more than 100 unseen, don't even try
		log 'unread=', unreadCount, 'height=', heightCount, 'msgCount=', msgCount
		firstO.set Math.max(1, (maxIdO.peek()||0)-msgCount)

	screenE = Dom.get()
	Dom.div !->
		if firstO.get()==1
			# todo: render WhatsApp invite
			Dom.style display: 'none'
			return
		Dom.style
			padding: '4px'
			textAlign: 'center'

		Ui.button tr("Earlier messages"), !->
			nfv = firstO.modify (v) -> Math.max(1, (v||0)-10)
			if true #!Plugin.agent().ios # on ios, this results in content-not-rendered bug
				prevHeight = screenE.prop('scrollHeight')
				Obs.onStable !->
					delta = screenE.prop('scrollHeight') - prevHeight
					# does not account for case when contentHeight < scrollHeight
					Page.scroll Page.scroll() + delta

	wasNearBottom = true
		# Observers are always called in order: update wasNearBottom flag before
		# new messages are inserted. After insertion, a similar observer uses the
		# flag to scroll down
	Obs.observe !->
		maxIdO.get()
		wasNearBottom = Page.nearBottom()

	log 'firstO=', firstO.peek(), 'maxO=', maxIdO.peek()

	Loglist.render firstO, maxIdO, (num) !->
		#log 'render', num
		if !isRendered and num is maxIdO.peek() - unreadCount + 1
			Dom.div !->
				Dom.style
					margin: '8px -8px'
					textAlign: 'center'
					padding: '4px 4px 2px 4px'
					background: '#f5f5f5'
					color: '#5b0'
					textShadow: '0 1px 0 #fff'
					textTransform: 'uppercase'
					fontWeight: 'bold'
					borderBottom: '1px solid #fdfdfd'
					borderTop: '1px solid #d4d4d4'
					fontSize: '75%'
				Dom.text tr("▼ New messages")

		Dom.div !->
			msg = shared.ref(0|num/100, num%100)
			if !msg.isHash()
				return

			byUserId = msg.get('by')
			name = Plugin.userName byUserId

			type = msg.get('type')
			if type in [10,11,12]
				Dom.style
					textAlign: 'center'
					padding: '4px'

				if byUserId is myUserId
					name = tr("You")

				Dom.div !->
					Dom.cls 'msg'
					Dom.style
						display: 'inline-block'
						padding: '4px 6px'
						borderRadius: '5px'
						background: '#bbb'
						color: '#fff'
					Dom.text if type is 10
							tr("%1 created the happening", name)
						else if type is 11
							tr("%1 joined", name)
						else
							tr("%1 left", name)
					Dom.onTap (!-> Plugin.userInfo(byUserId))

			else
				# normal message
				Dom.style
					position: 'relative'
					margin: '4px -4px'

				if byUserId is myUserId
					Dom.style textAlign: 'right'
				else
					Dom.style textAlign: 'left'
				
				text = msg.get('text')
				Ui.avatar Plugin.userAvatar(byUserId), !->
					if byUserId is myUserId
						Dom.style right: '4px'
					else
						Dom.style left: '4px'
					Dom.style
						position: 'absolute'
						top: '3px'
						margin: 0
				, null, (!-> Plugin.userInfo(byUserId))
	
				Dom.div !->
					Dom.cls 'msg'
					Dom.style
						display: 'inline-block'
						margin: '2px 50px'
						padding: '6px 8px 4px 8px'
						minHeight: '32px'
						borderRadius: '4px'
						_boxShadow: '0 2px 0 rgba(0,0,0,.1)'
						textAlign: 'left'
						background: '#fff'
						_userSelect: 'text'

					if text
						Dom.userText text
					else if photoKey = msg.get('photo')
						Dom.div !->
							Dom.style
								position: 'relative'
								margin: '2px 0'
								width: '120px'
								height: '120px'
								backgroundSize: 'cover'
								backgroundImage: Photo.css(photoKey, 200)
							Dom.div !->
								Dom.style width: '100%', height: '100%'
								Dom.onTap !->
									Page.nav !->
										renderPhoto num, msg
										
					else if msg.get('photo') is ''
						# photo removed (no photo and no text)
						Dom.div !->
							Dom.style
								Box: 'center middle'
								textAlign: 'center'
								color: '#fff'
								margin: '2px 0'
								backgroundColor: '#ccc'
								minWidth: '104px'
								padding: '8px'
							Dom.text tr("Photo")
							Dom.br()
							Dom.text tr("removed")

					Dom.div !->
						Dom.style
							textAlign: 'left'
							fontSize: '70%'
							color: '#aaa'
							padding: '2px 0 0'
						Dom.text name
						Dom.text " • "
						if time = msg.get('time')
							Time.deltaText time, 'short'
						else
							Dom.text tr("sending")
							renderDots()

					Dom.onTap !->
						messageModal(num, msg)

	typingSub = Obs.create {}
	Server.send 'typingSub', (delta) !-> typingSub.patch delta
	Obs.observe !->
	Dom.div !->
		wasNearBottom2 = Page.nearBottom()
		users = []
		for userId of typingSub.get()
			if +userId isnt myUserId
				users.push Plugin.userName(userId)
				
		Dom.style
			fontSize: '80%'
			padding: '4px 0'
			color: '#999'
			height: '16px' # reserve fixed space so redrawing does not trigger new scroll-down
			display: if users.length then '' else 'none'

		if l=users.length
			Dom.text users.join(' & ')
			Dom.text if l>1 then tr(" are typing") else tr(" is typing")
			renderDots()
		if wasNearBottom2
			Page.scroll 'down', true

	Obs.observe !->
		maxIdO.get()
		if !isRendered
			if unreadCount < 10
				Page.scroll 'down' # no scroll-animation on first render

		else if wasNearBottom
			Page.scroll 'down', true

		else
			#if +shared.peek(0|mid/100, mid%100, 'by') != Plugin.userId()
			require('toast').show tr("Scroll for new message")


	###
	Dom._listen Dom._get().parentNode, 'scroll', !->
		if Page.nearBottom()
			require('toast').clear()
	###

	isRendered = true

	Page.setFooter !->
		Dom.style
			background: '#f5f5f5'
			borderTop: 'solid 1px #aaa'

		inputE = false
		isTyping = false
		initValue = Db.local.peek("draft") || ''
		emptyO = Obs.create(initValue=='')

		send = !->
			log 'send', inputE.value(), inputE
			if msg = inputE.value()
				msg = Form.smileyToEmoji msg
				Server.sync 'msg', msg, !->
					id = maxIdO.modify (v) -> (v||0)+1
					shared.set 0|id/100, id%100,
						time: 0
						by: Plugin.userId()
						text: msg
				Server.send 'typing', isTyping=false
				emptyO.set true
				inputE.value ""

		Dom.div !->
			# wrap TextArea in a DIV, otherwise chaos ensues
			Dom.style
				background: '#fff'
				border: 'solid 1px #aaa'
				borderRadius: '6px'
				margin: '6px 60px 6px 6px'
				padding: '4px 2px'

			inputE = Form.text
				simple: true
				autogrow: true
				value: initValue
				onReturn: (value,evt) !->
					if !Plugin.agent().ios && !evt.prop('shiftKey')
						evt.kill true, true
						send()
				inScope: !->
					Dom.style
						width: '100%'
						fontSize: '17px'
						border: 'none'
						borderColor: 'transparent'
						background: 'transparent'
						padding: '0'
						margin: '0'
						fontFamily: 'Helvetica,sans-serif' # for android 4.4

					Dom.prop 'rows', 1
					Dom.on 'input', !->
						value = inputE.value()
						emptyO.set(value=='')
						if (value isnt '') != isTyping
							Server.send 'typing', isTyping=(value isnt '')

					Obs.onClean !->
						value = inputE.value()
						Db.local.set 'draft', value||null
						if value
							Server.send 'typing', isTyping=false

		Obs.observe !->
			empty = emptyO.get()
			Icon.render
				style:
					position: 'absolute'
					padding: "10px"
					bottom: 0
					right: 0
				color: if empty then '#555' else Plugin.colors().highlight
				size: 36
				data: if empty then 'camera' else 'send-button'
				onTap:
					noBlur: true
					cb: !->
						if empty
							Photo.pick()
						else
							send()
	
renderPhoto = (num, msg) !->

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

messageModal = (num, msg) !->
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


dots = ['.', '..', '...']
renderDots = !->
	i = 0
	Obs.observe !->
		i = (i+1)%dots.length
		Dom.text dots[i]
		Dom.span !->
			Dom.style color: 'transparent'
			Dom.text dots[2-i]
		Obs.delay 500

Dom.css
	'.msg.tap':
		background: '#ddd !important'
