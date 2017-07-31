$(".sortable").sortable
    items: ".sticky"

$(".sortable").on "change", "[data-behavior=move-to-stikies]", ->
    $checkbox = $(@)
    $div = $checkbox.closest("div")
    $sortable = $div.closest(".sortable")

    $div.removeClass("sticky") unless $checkbox.attr("checked")

    $lastSticky = $sortable.find(".sticky").last()
    if $div.prev("div").get(0) != $lastSticky.get(0)
        if $lastSticky.size() == 0
            $sortable.prepend($div)
        else
            $div.insertAfter($lastSticky)

    $div.addClass("sticky") if $checkbox.attr("checked")