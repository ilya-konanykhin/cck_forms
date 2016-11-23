$(function() {

    /**
     * Виджет-помогайка для установки и получения значения из ХТМЛ-объекта 1 дня или группы (поля у низ почти одинаковые).
     * При установке значения событи change не вызывается!
     */
    $.widget("cck.workhoursday", {

        options: {

        },

        _$day: null,
        _$open24Hours: null,
        _$openUntilLastClient: null,
        _$openTimeH: null,
        _$openTimeM: null,
        _$closeTimeH: null,
        _$closeTimeM: null,

        _create: function() {
            var $form = this.element;
            this._$day = $form.find('input[name$="[day]"]');
            this._$open24Hours = $form.find('input:checkbox[name$="[open_24_hours]"]');
            this._$openUntilLastClient = $form.find('input:checkbox[name$="[open_until_last_client]"]');
            this._$openTimeH = $form.find('select[name$="[open_time][hours]"]');
            this._$openTimeM = $form.find('select[name$="[open_time][minutes]"]');
            this._$closeTimeH = $form.find('select[name$="[close_time][hours]"]');
            this._$closeTimeM = $form.find('select[name$="[close_time][minutes]"]');
        },

        /**
         * Получить название дня (mod, tue).
         */
        day: function() {
            return this._$day.val();
        },

        /**
         * Получить или установить галку "круглосуточно".
         */
        open24Hours: function(value) {
            if(value !== undefined) {
                this._$open24Hours.prop("checked", value);
            } else {
                return !!this._$open24Hours.prop("checked");
            }
        },

        /**
         * Получить или установить галку "до последнего клиента".
         */
        openUntilLastClient: function(value) {
            if(value !== undefined) {
                this._$openUntilLastClient.prop("checked", value);
            } else {
                return !!this._$openUntilLastClient.prop("checked");
            }
        },

        /**
         * Преобразовать значения переданных инпутов в строку вида "20:35". Если не получится, или одно из значений пустое,
         * вернет null.
         */
        inputsToTime: function($hoursInput, $minutesInput) {
            var h = $hoursInput.val() == '' ? null : $hoursInput.val() * 1;
            var m = $minutesInput.val() == '' ? null : $minutesInput.val() * 1;

            if(h === null || m === null) {
                return null;
            }

            return h + ":" + m;
        },

        /**
         * Преобразовать хэш вида {hours: 20, minutes: 5} в значения переданных инпутов. Можно по одному.
         */
        timeToInputs: function(value, $hoursInput, $minutesInput) {
            if(value.hours !== undefined) {
                $hoursInput.val(value.hours);
            }

            if(value.minutes !== undefined) {
                $minutesInput.val(value.minutes);
            }
        },

        /**
         * Вернуть (строка) или установить (из хэша) значения времени открытия.
         */
        openTime: function(value) {
            if(value !== undefined) {
                this.timeToInputs(value, this._$openTimeH, this._$openTimeM);
            } else {
                return this.inputsToTime(this._$openTimeH, this._$openTimeM);
            }
        },

        /**
         * Вернуть (строка) или установить (из хэша) значения времени закрытия.
         */
        closeTime: function(value) {
            if(value !== undefined) {
                this.timeToInputs(value, this._$closeTimeH, this._$closeTimeM);
            } else {
                return this.inputsToTime(this._$closeTimeH, this._$closeTimeM);
            }
        },

        /**
         * Пустой ли день? Пустой тогда, когда не выбрано времени и чекбоксы не включены.
         */
        isEmpty: function() {
            return !this.open24Hours() && !this.openUntilLastClient() && !this.openTime() && !this.closeTime();
        },

        equalTo: function($other) {
            return (
                this.open24Hours() == $other.workhoursday("open24Hours") &&
                this.openUntilLastClient() == $other.workhoursday("openUntilLastClient") &&
                this.openTime() == $other.workhoursday("openTime") &&
                this.closeTime() == $other.workhoursday("closeTime")
            );
        },

        /**
         * Вернет или установит текущее значение скопом. Через массив, порядок элементов: "круглосуточно", "до послед.
         * клиента", "время открытия", "время закрытия". Время открытия и закрытия устанавливается через строку "ЧЧ:ММ",
         * в отличие от метода closeTime({hours: ..., minutes: ...}).
         */
        value: function(value) {
            if(value) {

                this._$open24Hours.prop("checked", !!value[0]);
                this._$openUntilLastClient.prop("checked", !!value[1]);
                this._$openTimeH.val(value[2] ? value[2].split(":")[0].replace(/^0(.)$/, '$1') : '');
                this._$openTimeM.val(value[2] ? value[2].split(":")[1].replace(/^0(.)$/, '$1') : '');
                this._$closeTimeH.val(value[3] ? value[3].split(":")[0].replace(/^0(.)$/, '$1') : '');
                this._$closeTimeM.val(value[3] ? value[3].split(":")[1].replace(/^0(.)$/, '$1') : '');

                return this.element;

            } else {

                return [
                    this.open24Hours(),
                    this.openUntilLastClient(),
                    this.openTime(),
                    this.closeTime()
                ];
            }
        },

        slashzero: null

    });



    // последний использованный ID группы
    var cckWorkhoursGroupId = 0;

    /**
     * Виджет блока "режим работы". Навешивается на весь ДИВ со строками для каждого дня недели, прячет их и подменяет
     * сгруппированными строками, когда на несколько дней (определяется включенными галочками) идет один режим работы:
     *
     *   > [^] Пн   [^] Вт   [^] Ср   [^] Чт   [^] Пт   [_] Сб   [_] Вс
     *   > c [09]:[00] по [20]:[00]   [_] круглосуточно   [_] до последнего клиента
     *
     *   > [_] Пн   [_] Вт   [_] Ср   [_] Чт   [_] Пт   [^] Сб   [^] Вс
     *   > c [10]:[00] по [__]:[__]   [_] круглосуточно   [^] до последнего клиента
     *
     *   [ Добавить дней ]
     *
     * Ссылка "Добавить дней" добавляет еще одну пусту группу. При указании в группе дня, который уже есть в другой,
     * оттуда он удаляется. Если группа опустела (нет дней), она удаляется.
     *
     * Реально данные из группы при всех манипуляциях переносятся в спрятанные строки, так что для бэкенда ничего
     * не меняется - профит!
     */
    $.widget("cck.workhours", {

        options: {

        },

        _days: [],
        _$template: null,

        /**
         * Инициализируем виджет.
         */
        _create: function() {
            var $form =  this.element;
            var $widget = this;

            var $addGroupLink = $('<a href="#add-group">Добавить дней</a>').click(function() {
                $widget.createGroup([], []);
            });

            this._lastP = $('<p></p>').appendTo($form).append($addGroupLink);

            this._$template = $form.find(".form_work_hours_day_template");

            var groups = [];
            $widget._days = [];

            // существующие дни распихаем по группам и спрячем
            $form.children(".form_work_hours_day:not(.form_work_hours_day_template)").each(function() {
                var $day = $(this).workhoursday().hide();
                var dayName = $day.workhoursday("day");
                var value = $day.workhoursday("value");
                var valueHash = value.join("/");

                $widget._days[dayName] = $day;

                if(!groups[valueHash]) {
                    groups[valueHash] = {days: [], value: value};
                }

                groups[valueHash].days.push(dayName);
            });

            for(var i in groups) {
                if (groups.hasOwnProperty(i)) {
                    $widget.createGroup(groups[i].days, groups[i].value);
                }
            }
        },

        /**
         * Создаем новый ДОМ-элемент "группы" дней из шаблона. Навешиваем нужных слушателей.
         */
        createGroup: function(days, value) {

            // сделаем ХТМЛ новой группы, заменив id|name ~= template на какой-то новый ID
            var newHtml = this._$template[0].outerHTML.replace(/((?:id|name)="[^"]*)template([^"]*")/g, "$1" + this.newGroupId() + "$2");
            var $newGroup = $(newHtml);

            // отметим чекбоксы, соотв. выбранным дням
            for(var i = 0, ic = days.length; i < ic; ++ i) {
                $newGroup.find("input[name$=\"[days]\"][value=" + days[i] + "]").prop("checked", true).closest("li").addClass("active");
            }

            // спрячем чекбоксы, вместо них будут ссылко-кнопки
            $newGroup.find("input[name$=\"[days]\"]").hide();
            $newGroup.find(".nav-pills").on("click", "a", function(event) {
                // событие могло произойти на чекбоксе внутри этой ссылки, это нам не нужно
                if(event.target == this) {
                    $(this).children("input:checkbox").click();
                    return false;
                }
            });

            // будем слушать изменения в формах, чтобы транслировать в соотв. группе скрытые поля дней
            var $widget = this;
            $newGroup.on("change", "input, select", function() {
                $widget.groupChangeListener(this);
            });

            // добавим ХТМЛ и его виджет workhoursday
            $newGroup.workhoursday().workhoursday("value", value).insertBefore(this._lastP).show();
        },

        /**
         * Слушаем изменения полей группы.
         */
        groupChangeListener: function(input) {

            var $group = $(input).closest(".form_work_hours_day");

            // если событие произошло на чекбоксах "Пн", "Вт"
            if(input.getAttribute("name").substr(-6) == '[days]') {

                if(input.checked) {

                    // "включили" этот день, значит, "выключим" его в другой группе (группах)
                    // сделаем себе временную метку, чтобы себя не выключить тоже
                    var dayName = input.value;

                    if (!$group.data("multiDays")) {
                        input.setAttribute("data-hold-check", "1");
                        this.element.find("input:checked[name$='[days]'][value=" + dayName + "][data-hold-check!=1]").prop("checked", false).change();
                        input.removeAttribute("data-hold-check");
                    }

                    // теперь обновим все поля из нашей группы для нового (включенного) дня
                    this._days[dayName].workhoursday("value", $group.workhoursday("value"));

                    // выделим метку этого инпута
                    input.parentNode.parentNode.className += " active";

                } else {

                    // "выключили" этот день в нашей группе, значит, обнулим его поля
                    this._days[input.value].workhoursday("value", []);

                    // удалим группу, если в ней не осталось включенных дней, иначе уберем метку активного дня
                    if($group.find("input:checked[name$='[days]']").size() == 0) {
                        $group.remove();
                    } else {
                        input.parentNode.parentNode.className = input.parentNode.parentNode.className.replace(/(^|\s)active($|\s)/, "$1");
                    }
                }

            // если событие НЕ на чекбоксах "Пн", "Вт" и т. п., то транслируем в соотв. скрытые поля
            } else {

                var match = input.getAttribute("name").match(/(?:\[(open_time|close_time)\])?\[([^\]]*)\]$/);
                var fieldName = (match[1] ? match[1] + '_' : '') + match[2];
                var inputNodeName = input.nodeName.toLowerCase();

                // сначала получим текущие отмеченные дни в группе
                var days = [];
                $group.find("input:checked[name$='[days]']").each(function() {
                    days.push(this.value);
                });

                // сделаем несколько простых проверок и отреагируем, меняя значения полей для удобства пользователя
                // если текущее поле выбрано, то...
                if(inputNodeName == "input" && input.checked || inputNodeName == "select" && input.value != '') {
                    switch(fieldName) {

                        // открыто 24 часа? обнулим время работы
                        case "open_24_hours":
                            $group.workhoursday("openTime", {hours: '', minutes: ''}).workhoursday("closeTime", {hours: '', minutes: ''});
                        break;

                        // открыто до последнего клиента? обнулим время закрытия
                        case "open_until_last_client":
                            $group.workhoursday("closeTime", {hours: '', minutes: ''});
                        break;

                        // выбрано время закрытия? уберем галку "открыто до последнего клиента"
                        case "close_time_hours":
                        case "close_time_minutes":
                            $group.workhoursday("openUntilLastClient", false);
                        // break пропущен намеренно

                        // выбрано к. л. время? уберем галку "открыто 24 часа"
                        case "open_time_hours":
                        case "open_time_minutes":
                            $group.workhoursday("open24Hours", false);
                        break;
                    }

                    // указан час, но не указаны минуты? установим :00
                    var camelCasedTime = this.camelCaseTime(fieldName, 6);
                    if((fieldName == "open_time_hours" || fieldName == "close_time_hours") && !$group.workhoursday(camelCasedTime)) {
                        $group.workhoursday(camelCasedTime, {minutes: 0})
                    }

                // если текущее поле не выбрано...
                } else {

                    // устанавливаем часы или минуты? обнулим минуты или часы соотв.
                    if(fieldName == "open_time_hours" || fieldName == "close_time_hours") {
                        $group.workhoursday(this.camelCaseTime(fieldName, 6), {minutes: ''});
                    } else if(fieldName == "open_time_minutes" || fieldName == "close_time_minutes") {
                        $group.workhoursday(this.camelCaseTime(fieldName, 8), {hours: ''});
                    }
                }

                // теперь найдем соотв. скрытые дни и установим у них значение группы
                var value = $group.workhoursday("value");
                for(var i = 0, ic = days.length; i < ic; ++ i) {
                    this._days[days[i]].workhoursday("value", value);
                }

            }
        },

        /**
         * "(open|close)_time_(hours|minutes)" -> "(open|close)Time"
         */
        camelCaseTime: function(under_scored, stripTrailingSymbols) {
            if(stripTrailingSymbols > 0) {
                under_scored = under_scored.substr(0, under_scored.length - stripTrailingSymbols);
            }

            var tokens = under_scored.split('_');
            return tokens[0] + tokens[1].substr(0, 1).toUpperCase() + tokens[1].substr(1)
        },

        /**
         * Сгенерируем новый уникальный ID группы.
         */
        newGroupId: function() {
            return 'group' + (cckWorkhoursGroupId ++);
        },

        /**
         * Затычка, чтобы у предыдущих полей объекта всегда ставить в конце запятую.
         */
        slashzero: null

    });
});
