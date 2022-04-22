$(function() {

    /**
     * Helper widget to set & obtain data from HTML of a single day or days group (almost identical)
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
         * Day name (mod, tue)
         */
        day: function() {
            return this._$day.val();
        },

        /**
         * Gets or sets "open 24 hours" checkbox state
         */
        open24Hours: function(value) {
            if(value !== undefined) {
                this._$open24Hours.prop("checked", value);
            } else {
                return !!this._$open24Hours.prop("checked");
            }
        },

        /**
         * Gets or sets "open until last client" checkbox state
         */
        openUntilLastClient: function(value) {
            if(value !== undefined) {
                this._$openUntilLastClient.prop("checked", value);
            } else {
                return !!this._$openUntilLastClient.prop("checked");
            }
        },

        /**
         * Converts passed input values to string of form "20:35". If failed, or any of values is empty, returns null
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
         * Converts a hash of form {hours: 20, minutes: 5} into input values
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
         * Get (as a string) or set (from a hash) open time values
         */
        openTime: function(value) {
            if(value !== undefined) {
                this.timeToInputs(value, this._$openTimeH, this._$openTimeM);
            } else {
                return this.inputsToTime(this._$openTimeH, this._$openTimeM);
            }
        },

        /**
         * Get (as a string) or set (from a hash) close time values
         */
        closeTime: function(value) {
            if(value !== undefined) {
                this.timeToInputs(value, this._$closeTimeH, this._$closeTimeM);
            } else {
                return this.inputsToTime(this._$closeTimeH, this._$closeTimeM);
            }
        },

        /**
         * Returns true, if the day is empty, that is neither open/close times are set nor checkboxes are checked
         */
        isEmpty: function() {
            return !this.open24Hours() && !this.openUntilLastClient() && !this.openTime() && !this.closeTime();
        },

        /**
         * If this object is equal to another
         */
        equalTo: function($other) {
            return (
                this.open24Hours() == $other.workhoursday("open24Hours") &&
                this.openUntilLastClient() == $other.workhoursday("openUntilLastClient") &&
                this.openTime() == $other.workhoursday("openTime") &&
                this.closeTime() == $other.workhoursday("closeTime")
            );
        },

        /**
         * Gets or sets current state from array: [is_open_24h, is_open_until_last_client, open_time, close_time]
         * Open and close times are string of form "hh:mm"
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



    // the last group ID taken
    var cckWorkhoursGroupId = 0;

    /**
     * Work hours widget. Accepts a series of DIVs for each week day and converts it into a grouped series, where
     * days are grouped by the same "work value" (checkboxes & open/close time):
     *
     *   > [^] Mon   [^] Tue   [^] Wed   [^] Thu   [^] Fri   [_] Sat   [_] Sun
     *   > from [09]:[00] till [20]:[00]   [_] open 24 hours   [_] open until last client
     *
     *   > [_] Mon   [_] Tue   [_] Wed   [_] Thu   [_] Fri   [^] Sat   [^] Sun
     *   > from [10]:[00] till [__]:[__]   [_] open 24 hours    [^] open until last client
     *
     *   [ Add days ]
     *
     * "Add days" link add an empty group. If a day is added to a group, it is removed from the previous group where it
     * was. If a group is emptied (no more days left), it is deleted.
     *
     * The key is, when manipulating groups all the data is propagated to the hidden inputs in original HTML, thus
     * the overall form data stays in the same format and a controller will not even now the widget was constructed.
     */
    $.widget("cck.workhours", {

        options: {

        },

        _days: [],
        _$template: null,

        /**
         * Constructor
         */
        _create: function() {
            var $form =  this.element;
            var $widget = this;

            // TODO: i18n in JS?
            var $addGroupLink = $('<a href="#add-group">Добавить дней</a>').click(function() {
                $widget.createGroup([], []);
            });

            this._lastP = $('<p></p>').appendTo($form).append($addGroupLink);

            this._$template = $form.find(".form_work_hours_day_template");

            var groups = [];
            $widget._days = [];

            // split existing days into groups and hide their DIVs
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
         * Creates new DOM node for a group & bind event listeners
         */
        createGroup: function(days, value) {

            // make HTML, substitute id|name ~= template for a real ID (new one)
            var newHtml = this._$template[0].outerHTML.replace(/((?:id|name)="[^"]*)template([^"]*")/g, "$1" + this.newGroupId() + "$2");
            var $newGroup = $(newHtml);

            // mark checkboxes
            for(var i = 0, ic = days.length; i < ic; ++ i) {
                $newGroup.find("input[name$=\"[days]\"][value=" + days[i] + "]").prop("checked", true).closest(".nav-link").addClass("active");
            }

            // hide checkboxes, link-o-buttons will be in their place
            $newGroup.find("input[name$=\"[days]\"]").hide();
            $newGroup.find(".nav-pills").on("click", "a", function(event) {
                // skip events originated at checkbox inside this link
                if(event.target == this) {
                    $(this).children("input:checkbox").click();
                    return false;
                }
            });

            // listen for the form changes to propagate to the original DOM nodes
            var $widget = this;
            $newGroup.on("change", "input, select", function() {
                $widget.groupChangeListener(this);
            });

            // make HTML & instantiate widget workhoursday
            $newGroup.workhoursday().workhoursday("value", value).insertBefore(this._lastP).show();
        },

        /**
         * Listens for a group events
         */
        groupChangeListener: function(input) {

            var $group = $(input).closest(".form_work_hours_day");

            // an event from day checkboxes?
            if(input.getAttribute("name").substr(-6) == '[days]') {

                if(input.checked) {

                    // this day is on in this group, so make it off in another groups
                    var dayName = input.value;

                    if (!$group.data("multiDays")) {
                        input.setAttribute("data-hold-check", "1");
                        this.element.find("input:checked[name$='[days]'][value=" + dayName + "][data-hold-check!=1]").prop("checked", false).change();
                        input.removeAttribute("data-hold-check");
                    }

                    // propagate all the fields from this group to the day's original fields
                    this._days[dayName].workhoursday("value", $group.workhoursday("value"));

                    // mark the day as active
                    input.parentNode.className += " active";

                } else {

                    // propagate the off state to the day's original fields
                    this._days[input.value].workhoursday("value", []);

                    // remove this group if no more days left inside
                    if($group.find("input:checked[name$='[days]']").size() == 0) {
                        $group.remove();
                    } else {
                        input.parentNode.className = input.parentNode.className.replace(/(^|\s)active($|\s)/, "$1");
                    }
                }

            // an event not from day checkboxes -> propagate the value to the original node
            } else {

                var match = input.getAttribute("name").match(/(?:\[(open_time|close_time)\])?\[([^\]]*)\]$/);
                var fieldName = (match[1] ? match[1] + '_' : '') + match[2];
                var inputNodeName = input.nodeName.toLowerCase();

                // active days in this group
                var days = [];
                $group.find("input:checked[name$='[days]']").each(function() {
                    days.push(this.value);
                });

                // some UX friendly checks
                if(inputNodeName == "input" && input.checked || inputNodeName == "select" && input.value != '') {
                    switch(fieldName) {

                        // open 24 hours? nullify open/close time
                        case "open_24_hours":
                            $group.workhoursday("openTime", {hours: '', minutes: ''}).workhoursday("closeTime", {hours: '', minutes: ''});
                        break;

                        // open until last client? nullify close time
                        case "open_until_last_client":
                            $group.workhoursday("closeTime", {hours: '', minutes: ''});
                        break;

                        // close time set? uncheck "open until last" checkbox
                        case "close_time_hours":
                        case "close_time_minutes":
                            $group.workhoursday("openUntilLastClient", false);
                        // break skipped on purpose!

                        // any time set? uncheck "open 24h" checkbox
                        case "open_time_hours":
                        case "open_time_minutes":
                            $group.workhoursday("open24Hours", false);
                        break;
                    }

                    // hour is set but minutes are not? set :00
                    var camelCasedTime = this.camelCaseTime(fieldName, 6);
                    if((fieldName == "open_time_hours" || fieldName == "close_time_hours") && !$group.workhoursday(camelCasedTime)) {
                        $group.workhoursday(camelCasedTime, {minutes: 0})
                    }

                // not input
                } else {

                    // setting hours or minutes? nullify minutes or hours respectively
                    if(fieldName == "open_time_hours" || fieldName == "close_time_hours") {
                        $group.workhoursday(this.camelCaseTime(fieldName, 6), {minutes: ''});
                    } else if(fieldName == "open_time_minutes" || fieldName == "close_time_minutes") {
                        $group.workhoursday(this.camelCaseTime(fieldName, 8), {hours: ''});
                    }
                }

                // all checks are made, propagate the value to days inside this group
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
         * Generates a unique sequential group DOM ID
         */
        newGroupId: function() {
            return 'group' + (cckWorkhoursGroupId ++);
        },

        /**
         * To not worry about redundant comma after the last hash key
         */
        slashzero: null

    });
});
