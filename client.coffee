Db = require 'db'
Dom = require 'dom'
Form = require 'form'
Obs = require 'obs'
Page = require 'page'
Photo = require 'photo'
Plugin = require 'plugin'
Server = require 'server'
Time = require 'time'
Widgets = require 'widgets'
Loglist = require 'loglist'
{tr} = require 'i18n'

exports.render = !->
	Dom.style
		fontSize: '90%'

	shared = Db.shared
	myUserId = Plugin.userId()
	happeningId = Plugin.groupId()

	firstV = Obs.value Math.max(1, ((shared '#maxId')||0)-10)

	screenE = Dom.get()
	Dom.div !->
		if firstV()==1
			Dom.style display: 'none'
			return
		Dom.style
			padding: '4px'
			textAlign: 'center'

		Widgets.button tr("Earlier messages"), !->
			firstV Math.max(1, Obs.peek(firstV)-10)
			if !Plugin.agent().ios # on ios, this results in content-not-rendered byg
				prevHeight = screenE.prop('scrollHeight')
				Obs.onStable !->
					delta = screenE.prop('scrollHeight') - prevHeight
					# does not account for case when contentHeight < scrollHeight
					Page.scroll Page.scroll() + delta

	Loglist.render firstV, (shared "&maxId"), (num) !->
		Dom.div !->
			msg = (shared "#{0|num/100} #{num%100}")
			if !msg
				return

			memberId = (msg 'by')
			name = Plugin.userName memberId
			avatar = Plugin.userAvatar memberId

			type = (msg 'type')
			if type in [10,11,12]
				Dom.style
					textAlign: 'center'
					padding: '4px'

				if memberId is myUserId
					name = tr("You")

				Dom.div !->
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

			else
				# normal message
				Dom.style
					position: 'relative'
					margin: '4px -4px'

				if memberId is myUserId
					Dom.style textAlign: 'right'
				
				text = (msg 'text')
				Dom.div !->
					Dom.style
						position: 'absolute'
						top: '3px'
						width: '40px'
						height: '40px'
						backgroundSize: 'cover'
						backgroundPosition: '50% 50%'
						borderRadius: '20px'
					if memberId is myUserId
						Dom.style right: '4px'
					else
						Dom.style left: '4px'
					if avatar
						Dom.style
							backgroundImage: "url(#{Photo.url(avatar)})"
							_boxShadow: '0 0 3px rgba(255,255,255,1)'
					else
						Dom.style
							backgroundImage: "url(#{Plugin.resourceUri('silhouette-aaa.png')})"
							width: '36px'
							height: '36px'
							border: 'solid 2px #aaa'
	
				Dom.div !->
					Dom.style
						display: 'inline-block'
						margin: '2px 50px'
						padding: '6px 8px 4px 8px'
						minHeight: '32px'
						borderRadius: '4px'
						_boxShadow: '0 2px 0 rgba(0,0,0,.1)'
						textAlign: 'left'
						background: '#fff'

						#Dom.onTap
						#	longTap: !->
						#		Form.toClipboard text
						#		require('toast').show tr("Copied to clipboard")

					Dom.text text

					Dom.div !->
						Dom.style
							textAlign: 'left'
							fontSize: '70%'
							color: '#aaa'
							padding: '2px 0 0'
						Dom.text name
						Dom.text " - "
						if  time = (msg 'time')
							Time.deltaText time, 'short'
						else
							Dom.text tr("sending")
							renderDots()

	typingSub = Obs.hash()
	Server.send "typingSub", typingSub
	Obs.observe !->
		users = []
		for userId of (typingSub '*')
			if +userId isnt Plugin.userId()
				users.push Plugin.userName(userId)
		if users.length
			Dom.div !->
				Dom.style
					fontSize: '80%'
					padding: '4px 0'
					color: '#999'
				Dom.text users.join(' & ')
				if users.length is 1
					Dom.text tr(" is typing")
				else
					Dom.text tr(" are typing")
				renderDots()

	Obs.observe !->
		(shared "maxId")
		(typingSub '*')
		#if Page.nearBottom()
		Page.scroll('down', isRendered)
	isRendered = true

	Page.setFooter !->
		Dom.style
			background: '#f5f5f5'
			borderTop: 'solid 1px #aaa'

		inputE = false
		isTyping = false
		send = !->
			log 'send', inputE.value(), inputE
			if msg = inputE.value()
				Server.sync 'msg', msg, !->
					id = 1+(shared "#maxId")
					(shared "#{0|id/100} #{id%100}", {time:0,by:Plugin.userId(),text:msg})
					(shared "maxId", id)
				Server.send 'typing', isTyping=false
				inputE.value ""

		Dom.div !->
			# wrap TextArea in a DIV, otherwise chaos ensues
			Dom.style
				background: '#fff'
				border: 'solid 1px #aaa'
				borderRadius: '6px'
				margin: '6px 65px 6px 6px'
				padding: '4px 2px'

			inputE = Form.text
				simple: true
				autogrow: true
				value: (Db.local "#draft")
				onReturn: (value,evt) !->
					if !Plugin.agent().ios
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
						if (value isnt '') != isTyping
							Server.send 'typing', isTyping=(value isnt '')

					Obs.onClean !->
						value = inputE.value()
						(Db.local 'draft', value||null)
						if value
							Server.send 'typing', isTyping=false

		Dom.div !->
			Dom.style
				position: 'absolute'
				bottom: 0
				right: 0
				top: 0
				width: '60px'
				display_: 'box'
				_boxAlign: 'center'
				_boxPack: 'center'
				fontWeight: 'bold'
				color: '#004E63'

			Dom.text tr("Send")
			Dom.onTap
				noBlur: true
				cb: send


dots = ['.', '..', '...']
renderDots = !->
	i = Obs.value(0)
	Obs.observe !->
		Dom.text dots[i()]
	Obs.interval 500, !->
		i (i()+1)%dots.length

