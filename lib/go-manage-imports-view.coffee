{$$, SelectListView} = require 'atom-space-pen-views'
{spawn} = require 'child_process'
{BufferedProcess} = require 'atom'
{match} = require 'fuzzaldrin'

module.exports =
class GoManageImportsView extends SelectListView
    @highlightMatches: (context, name, matches, offsetIndex=0) ->
        lastIndex = 0
        matchedChars = [] # Build up a set of matched chars to be more semantic

        for matchIndex in matches
            matchIndex -= offsetIndex
            console.log("offsetIndex", offsetIndex, "matchIndex", matchIndex)
            continue if matchIndex < 0 # If marking up the basename, omit name matches
            unmatched = name.substring(lastIndex, matchIndex)
            if unmatched
                context.span matchedChars.join(''), class: 'character-match' if matchedChars.length
                matchedChars = []
                context.text unmatched
                console.log("unmatched", unmatched)
            matchedChars.push(name[matchIndex])
            lastIndex = matchIndex + 1

        context.span matchedChars.join(''), class: 'character-match' if matchedChars.length

        # Remaining characters are plain text
        context.text name.substring(lastIndex)

    initialize: ->
        super
        @addClass('overlay from-top')
        @panel ?= atom.workspace.addModalPanel(item: this)
        @imports = []
        @goimports = []

    viewForItem: (name) ->
        # Style matched characters in search results
        matches = match(name, @getFilterQuery())
        console.log("name", name, "matches", matches)

        $$ ->
            @li class: 'two-lines', =>
                if matches.length == 0
                    @div "#{name}", class: 'primary-line'
                else
                    @div class: 'primary-line', => GoManageImportsView.highlightMatches(this, name, matches)


    confirmed: (item) ->
        console.log("#{item} was selected")
        # save active editor so local changes are note overidden when the tool saves a new copy of the file
        if item.startsWith("\(")
            tokens = item.split " "
            imp = tokens[1].slice(0, -1)
            console.log "deleting " + imp
            @deleteImport(@getPath(), imp)
        else
            console.log "adding " + item
            @addImport(@getPath(), item)
        @panel.hide()
        @imports = []
        @goimports = []
        atom.workspace.getActiveTextEditor().save()

    deleteImport: (filePath, importPath) ->
        command = 'imports'
        args = ['remove', '-f', filePath, '-i', importPath]
        @delErr = ''
        stdout = (output)=>
            @delErr += output
        stderr = (output)=>
            @delErr += output
        exit = (code)=>
            if code == 0
                message = 'deleted ' + importPath
                console.log("message", message)
                atom.notifications.addSuccess message
            else
                atom.notifications.addError "Cannot delete import" + @delErr
        process = new BufferedProcess({command, args, stdout, stderr, exit})

    addImport: (filePath, importPath) ->
        command = 'imports'
        args = ['add', '-f', filePath, '-i', importPath]
        @addErr = ''
        stdout = (output)=>
            @addErr += output
        stderr = (output)=>
            @addErr += output
        exit = (code)=>
            if code == 0
                message = "added " + importPath
                console.log message
                atom.notifications.addSuccess message
            else
                atom.notifications.addError "Cannot add import" + @addErr
        process = new BufferedProcess({command, args, stdout, stderr, exit})

    cancelled: ->
        console.log("This view was cancelled")
        @setItems([])
        @panel.hide()
        @imports = []
        @goimports = []

    toggle: ->
        console.log("Toggle")
        if @panel.isVisible()
            @panel.hide()
        else if filePath = @getPath()
            if filePath.endsWith(".go") && editor = @getEditor()
                atom.workspace.getActiveTextEditor().save()
                @populateFileImports(filePath)
                @populateAvailableImports()

    getEditor: -> atom.workspace.getActiveTextEditor()

    getPath: -> @getEditor()?.getPath()

    populateFileImports: (path) ->
        command = 'imports'
        args = ['list', '-f', path, '-json']
        stdout = (output)=>
            @result = output
            @imports = JSON.parse(output)
        stderr = (output)=>
            @result = output
        exit = (code)=>
            if code == 0
                @addStuff()
            else
                atom.notifications.addError "Could not get imports: " + @result
        process = new BufferedProcess({command, args, stdout, stderr, exit})

    populateAvailableImports: ->
        command = 'go'
        args = ['list', '...']
        stdout = (output)=>
            @goimports = @goimports.concat(output.split "\n")
        stderr = (output)=>
            @err = output
        exit = (code)=>
            if code == 0
                @addStuff()
            else
                atom.notifications.addError @err
        process = new BufferedProcess({command, args, stdout, stderr, exit})

    attach: ->
        @storeFocusedElement()
        @panel.show()
        @focusFilterEditor()

    addStuff: ->
        console.log("length:" + @goimports.length)
        if @goimports.length > 0
            @items = []
            localImports = []
            for item in @imports
                @items.push '(delete: ' + item['Path'] + ')'
                localImports.push item['Path']
            for item in @goimports
                if item not in localImports
                    @items.push item
            @setItems(@items)
            @attach()

String::startsWith ?= (s) -> @slice(0, s.length) == s
String::endsWith   ?= (s) -> s == '' or @slice(-s.length) == s
