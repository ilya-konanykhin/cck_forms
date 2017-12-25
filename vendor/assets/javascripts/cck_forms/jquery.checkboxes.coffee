$ ->

  #
  # Helper widget to allow sorting of checkboxes, if jquery.sortable is available
  #
  $.widget "cck.checkboxes",
    
    _create: ->
      @_checkBoxBlockSelector = ".form_check_box_block"

      @_ensureSortableIsAvailable =>
        @_initStickies()
        @_bind()

    _ensureSortableIsAvailable: (callback)->
      callback() if $(document).sortable

    _initStickies: ->
      @element.find("input:checked").each (_i, checkbox)=>
        $(checkbox).closest(@_checkBoxBlockSelector).addClass("sticky")

      @element.sortable
        items: ".sticky"

    _bind: ->
      @element.on "change", "#{@_checkBoxBlockSelector} input:checkbox", (e)=>
        @_checkboxChange($(e.target))

    _checkboxChange: ($checkbox)->
      $container = $checkbox.closest(@_checkBoxBlockSelector)

      $container.removeClass("sticky") unless $checkbox.is(":checked")

      $lastSticky = @element.find(".sticky").last()

      if $container.prev(@_checkBoxBlockSelector).get(0) != $lastSticky.get(0)
        if $lastSticky.size() == 0
          @element.prepend($container)
        else
          $container.insertAfter($lastSticky)

      $container.addClass("sticky") if $checkbox.is(":checked")