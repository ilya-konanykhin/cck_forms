$ ->
  $.widget 'cck.checkboxes', _create: ->

    $element = @element

    $('input:checked').each ->
      $(this).closest('.form_check_box_block').addClass 'sticky'

    $element.sortable items: '.sticky'

    $element.on 'change', '.form_check_box_block input:checkbox', ->

      $checkbox = $(this)
      $div = $checkbox.closest('.form_check_box_block')

      if !$checkbox.prop('checked')
        $div.removeClass 'sticky'

      $lastSticky = $element.find('.sticky').last()

      if $div.prev('.form_check_box_block').get(0) != $lastSticky.get(0)
        if $lastSticky.size() == 0
          $element.prepend $div
        else
          $div.insertAfter $lastSticky
      if $checkbox.prop('checked')
        $div.addClass('sticky')
