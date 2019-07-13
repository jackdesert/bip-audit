var bindAuditFilters = function(){
    'use strict'

    var checkTheBoxes = function($textBox, $optionsDiv){
        var values = $textBox.val().split(', ')

        if (values[0] === ''){
            values = []
        }

        $optionsDiv.find('input').each(function(index, element){
            if (values.indexOf(element.id) > -1){
                element.checked = true
            }else{
                element.checked = false
            }

        })
    }

    //$('.audit-filter__has-options').click(function(event){
    $('body').click(function(event){
        var hasOptionsKlass = 'audit-filter__has-options',
            optionsKlass = 'audit-filter__options',
            $allOptions = $('.' + optionsKlass),
            $target = $(event.target),
            $options = $target.prev().find('.' + optionsKlass)

        if ($target.hasClass(hasOptionsKlass)){
            $allOptions.hide()
            $options.show()
            checkTheBoxes($target, $options)
        }else if ($target.parents('.' + optionsKlass).length > 0){
            // click was inside an inflated div. Do nothing.
        }else{
            $allOptions.hide()
        }

    })

    $('.audit-filter__option').on('change', function(event){
        var $parentDiv = $(event.target).parents('.audit-filter__options'),
            klassList = $parentDiv.attr('class').split(' '),
            textBoxId = klassList[1],
            values = []


        $parentDiv.find('input').each(function(index, element){
            var id = element.id
            if (element.checked){
                values.push(id)
            }
        })
        $('#' + textBoxId).val(values.join(', '))
    })

    $('input').on('keyup', function(event){
        var keypressed = event.keyCode || event.which
        if (keypressed == 13) {
            redirect()
        }

    })

}
