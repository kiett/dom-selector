
# The basic strategy is to:
# 1. bind a document-wide 'mousemove' event,
# 2. find the hovered element,
# 3. place an opaque overlay at the same position as the hovered element
# 4. adjust the hovered element by bumping the keyboard
#
# traps to avoid: when the overlay is showing, skip it when finding the hovered element

do ($ = window.jQuery) ->

	log = (args...) ->
		args.unshift "dom-selector:"
		console.log.apply console, args

	log "Loading..."

	# The callback passed to .selectElement
	waiting = null

	# Shows the controls
	overlay = $("<div id='dom-selector-overlay' style='display:none'><p class='selector-hint' style='margin-bottom:10px'>Move your mouse to highlight an area.<br />Click to select it and return to Conductrics.</p><p class='current-selector' style='color:#226'></p></div>")
	$(document).ready -> overlay.appendTo("body")
	showOverlay = (x,y,w,h) ->
		overlay.css({
			position: "fixed"
			top: parseInt(y) + "px"
			left: parseInt(x) + "px"
			width: parseInt(w) + "px"
			height: parseInt(h) + "px"
			"padding": "10px 5px"
			"border-radius": "5px"
			"border-color": "silver"
			"border-width": "1px"
			"border-style": "solid"
			"box-shadow":"1px 1px 2px silver"
			"opacity": 0.9
			"z-index": 99999999
			background: "#ffc"
			# common
			"text-align": "center"
			"line-height": 1
			"color": "#222"
			"display": "block"
			"margin": 0
			"vertical-align": 'baseline'
			"font-size": "10pt"
			"font": "sans-serif"
		}).find('p').css({
			# common
			"text-align": "center"
			"line-height": 1
			"color": "#222"
			"display": "block"
			"padding": "0"
			"margin": "0"
			"margin-bottom": "10px"
			"vertical-align": 'baseline'
			"font-size": "10pt"
			"font": "sans-serif"
		}).find('p.current-selector').css({
			color: '#226'
		})
	hideOverlay = ->
		overlay.css display: "none"
	setOverlayText = (message) ->
		$("div#dom-selector-overlay .current-selector").text(message)

	notEmpty = (i, s) -> s?.length > 0

	# Compute the unique selector for an element
	getSelector = do ->
		nthChild = (elem) ->
			return "" if (
				not elem? or
				not elem.ownerDocument?
				elem is document or
				elem is document.body or
				elem is document.head
			)
			if parent = elem?.parentNode
				for i in [0...parent.childNodes.length]
					if parent.childNodes[i] is elem
						return ":nth-child(#{i})"
			return ""
		return (element) ->
			hasId = notEmpty 0, element.id
			hasClass = notEmpty 0, element.className
			isElement = element.nodeType is 1
			isRoot = element.parentNode is element.ownerDocument
			hasParent = element.parentNode?
			s = switch true
				when isRoot then ""
				when not isElement then ""
				when hasId then "#" + element.id
				when hasClass then "." + element.className.split(" ").join(".")
				else element.nodeName.toLowerCase() + nthChild(element)
			if hasId
				return s
			if hasParent
				return getSelector(element.parentNode) + " > " + s
			return s

	# Tracks which element is currently pointed at
	hovered = {
		element: null
		background: ""
		# border: ""
		unhighlight: ->
			if @element?
				@element.css "background", @background
				# @element.css "border", @border
			@element = null
		highlight: ->
			if @element?
				@background = @element.css("background")
				# @border = @element.css("border")
				@element.css {
					background: "rgba(255,0,0,.5)"
					# border: "1px solid rgba(255,0,0,.5)"
				}
		update: (target) ->
			if (not target?) or (target is @element?[0]) or (overlay[0] is target) or (overlay.has(target).length)
				return
			@unhighlight()
			# target.scrollIntoView()
			@element = $(target)
			@highlight()
			setOverlayText getSelector target
	}
	keyMap = {
		13: "enter"
		37: "left"
		38: "up"
		39: "right"
		40: "down"
	}

	cancel = (evt) ->
		evt.preventDefault()
		evt.stopPropagation()
		evt.cancelBubble = true
		return false

	firstChild = (elem) ->
		child = elem.childNodes[0]
		while child? and child.nodeType isnt 1 # skip Text Nodes
			child = child.nextSibling
		return child
	nextSibling = (elem) ->
		next = elem.nextSibling
		while next? and next.nodeType isnt 1 # skip Text Nodes
			next = next.nextSibling
		return next
	prevSibling = (elem) ->
		previous = elem.previousSibling
		while previous? and previous.nodeType isnt 1
			previous = previous.previousSibling
		return previous
	onMouseMove = (event) ->
		hovered.update(event.target)
	onKeyUp = (event) ->
		element = hovered.element?[0]
		return unless element?
		hovered.update switch keyMap[event.keyCode]
			when "left" then element.parentNode
			when "right" then firstChild element
			when "down" then nextSibling element
			when "up" then prevSibling element
			when "enter" then onClick(event)
			else null
		if event.keyCode of keyMap
			return cancel(event)
	onKeyDown = (event) ->
		switch keyMap[event.keyCode]
			when "left","right","up","down" then cancel(event)
			else return true
	onClick = (event) ->
		return cancel(event) if (overlay.is(event.target)) or (overlay.has(event.target).length)
		waiting?(hovered.element)
		cancel(event)

	# Starts tracking the mouse and showing the overlay
	enable = ->
		showOverlay( 10,10, 400, 60 )
		log "Binding events"
		$(document.body)
			.mousemove(onMouseMove)
			.keyup(onKeyUp)
			.keydown(onKeyDown)
			.click(onClick)

	# Stops tracking or showing anything
	disable = ->
		log "Unbinding events"
		hideOverlay()
		hovered.unhighlight()
		$(document.body)
			.unbind("mousemove", onMouseMove)
			.unbind("click", onClick)
			.unbind("keyup", onKeyUp)
			.unbind("keydown", onKeyDown)


	selectElement = (cb) ->
		waiting = (selected) ->
			disable()
			cb?(selected[0], getSelector(selected[0]))
		enable()

	window.DOMSelector or= {}
	do window.DOMSelector.attach = (jQ = window.jQuery) ->
		# also changes which jQuery is used in the code above
		$ = jQ.extend jQ,
			selectElement: selectElement
			getSelector: getSelector

