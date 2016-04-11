GoManageImportsView = require './go-manage-imports-view'
{CompositeDisposable} = require 'atom'

module.exports = GoManageImports =
  goManageImportsView: null
  subscriptions: null
  # panel: null

  activate: (state) ->
    @goManageImportsView = new GoManageImportsView()

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'go-manage-imports:toggle': => @toggle()

    @toggle()

  serialize: ->
    goManageImportsViewState: @goManageImportsView.serialize()

  toggle: ->
    console.log 'GoManageImports was toggled!'
    @goManageImportsView.toggle()
