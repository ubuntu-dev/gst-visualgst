GtkConcreteWidget subclass: GtkTextWidget [
    | findWidget replaceWidget textWidget userAction undoStack lastCommand cut textSaved lastSavedCommand |

    GtkTextWidget class >> newWithBuffer: aGtkTextBuffer [
        <category: 'instance creation'>

	^ self new
	    initialize;
	    buffer: aGtkTextBuffer;
	    yourself
    ]

    connectSignals [
	<category: 'initialization'>

	textWidget
	    connectSignal: 'paste-clipboard' to: self selector: #paste userData: nil;
            connectSignal: 'cut-clipboard' to: self selector: #cut userData: nil.

	(textWidget getBuffer)
            connectSignal: 'begin-user-action' to: self selector: #'beginUserAction' userData: nil;
            connectSignal: 'end-user-action' to: self selector: #'endUserAction' userData: nil;
            connectSignal: 'insert-text' to: self selector: #'insert:at:text:size:' userData: nil;
            connectSignal: 'delete-range' to: self selector: #'delete:from:to:' userData: nil
    ]

    initialize [
        <category: 'initialization'>

	textSaved := false.
        cut := userAction := false.
        undoStack := (UndoStack new)
                        initialize;
                        yourself.
	textWidget := GTK.GtkTextView new.
	self 
	    mainWidget: self buildWidget;
	    connectSignals.
	
    ]

    postInitialize [
        <category: 'initialize'>

        findWidget mainWidget hide.
        replaceWidget mainWidget hide
    ]

    buildWidget [
	<category: 'user interface'>

        ^ (GTK.GtkVBox new: false spacing: 3)
                    packStart: (GTK.GtkScrolledWindow withChild: textWidget) expand: true fill: true padding: 0;
                    packEnd: ((findWidget := GtkFindWidget new) initialize; mainWidget) expand: false fill: false padding: 0;
                    packEnd: ((replaceWidget := GtkReplaceWidget new) initialize; mainWidget) expand: false fill: false padding: 0;
                    yourself
    ]

    beginUserAction [
        <category: 'buffer events'>

        userAction := true
    ]

    endUserAction [
        <category: 'buffer events'>

        userAction := false
    ]

    paste [
        <category: 'clipboard events'>

        lastCommand := nil
    ]

    cut [
        <category: 'clipboard events'>

        cut := true and: [ self getBuffer getHasSelection ].
        cut ifTrue: [ lastCommand := nil ]
    ]

    insert: aGtkTextBuffer at: aCObject text: aString size: anInteger [
        <category: 'buffer events'>

        | gtkTextIter offset |
        userAction ifFalse: [ ^ self ].
        gtkTextIter := GTK.GtkTextIter address: aCObject address.
	(aString size = 1 and: [ aString first = Character lf]) 
	    ifTrue: [ lastCommand := InsertTextCommand insert: aString at: gtkTextIter getOffset on: self getBuffer.
                undoStack push: lastCommand.
		lastCommand := nil.
		^ self ].
        (lastCommand isNil or: [ aString size > 1 ])
            ifTrue: [ lastCommand := InsertTextCommand insert: aString at: gtkTextIter getOffset on: self getBuffer.
                undoStack push: lastCommand.
                aString size > 1 ifTrue: [ lastCommand := nil ].
                ^ self ].
        ((gtkTextIter getOffset = (lastCommand offset + lastCommand size)) and: [ lastCommand isInsertCommand ])
            ifTrue: [ lastCommand string: (lastCommand string, aString).
                ^ self ].
        lastCommand := InsertTextCommand insert: aString at: gtkTextIter getOffset on: self getBuffer.
        undoStack push: lastCommand.
    ]

    delete: aGtkTextBuffer from: aStartCObject to: anEndCObject [
        <category: 'buffer events'>

        | startIter endIter text |
        userAction ifFalse: [ cut := false. ^ self ].
        startIter := GTK.GtkTextIter address: aStartCObject address.
        endIter := GTK.GtkTextIter address: anEndCObject address.
        text := self getBuffer getText: startIter end: endIter includeHiddenChars: false.
        (lastCommand isNil or: [ cut ])
            ifTrue: [ lastCommand := DeleteTextCommand from: startIter getOffset to: endIter getOffset text: text on: self getBuffer.
                undoStack push: lastCommand.
                cut ifTrue: [ lastCommand := nil ].
                cut := false.
                ^ self ].
        ((startIter getOffset = (lastCommand offset - lastCommand size)) and: [ lastCommand isDeleteCommand ])
            ifTrue: [ lastCommand string: (text, lastCommand string).
                ^ self ].
        lastCommand := DeleteTextCommand from: startIter getOffset to: endIter getOffset text: text on: self getBuffer.
        undoStack push: lastCommand.
    ]

    hasChanged [
        <category: 'testing'>

        ^ textSaved
            ifTrue: [ (self lastUndoCommand == lastSavedCommand) not ]
            ifFalse: [ self hasUndo
                            ifFalse: [ false ]
                            ifTrue: [ true ] ]
    ]

    hasUndo [
	<category: 'buffer events'>

	^ undoStack hasUndo
    ]

    clearUndo [
	<category: 'buffer events'>

        textSaved := false.
        lastSavedCommand := nil.
	undoStack clear
    ]

    undo [
        <category: 'buffer events'>

        undoStack undo.
        lastCommand := nil.
    ]

    redo [
        <category: 'buffer events'>

        undoStack redo.
        lastCommand := nil.
    ]

    emptyStack [
	<category: 'stack events'>

	undoStack clear
    ]

    lastUndoCommand [
	<category: 'buffer events'>

	^ undoStack lasUndoCommand
    ]

    textSaved [
        <category: 'accessing'>

        textSaved := true.
        lastCommand := nil.
        lastSavedCommand := self lastUndoCommand
    ]

    textWidget [
	<category: 'accessing'>

	^ textWidget
    ]

    buffer [
	<category: 'accessing'>

	^ textWidget getBuffer
    ]

    buffer: aGtkTextBuffer [
	<category: 'accessing'>

	textWidget setBuffer: aGtkTextBuffer
    ]

    showFind [
        <category: 'user interface'>

        findWidget mainWidget getVisible ifTrue: [ ^ findWidget mainWidget hide ].
        replaceWidget mainWidget hide.
        findWidget mainWidget show
    ]

    showReplace [
        <category: 'user interface'>

        replaceWidget mainWidget getVisible ifTrue: [ ^ replaceWidget mainWidget hide ].
        findWidget mainWidget hide.
        replaceWidget mainWidget show
    ]
]
