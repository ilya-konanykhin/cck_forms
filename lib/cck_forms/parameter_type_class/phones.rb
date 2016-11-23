class CckForms::ParameterTypeClass::Phones
  include CckForms::ParameterTypeClass::Base

  MIN_PHONES_IN_FORM  = Rails.application.config.cck_forms.phones.min_phones_in_form
  MOBILE_CODES        = Rails.application.config.cck_forms.phones.mobile_codes
  PREFIX              = Rails.application.config.cck_forms.phones.prefix
  NUMBER_PARTS_GLUE   = Rails.application.config.cck_forms.phones.number_parts_glue

  def self.name
    'Телефоны'
  end

  # Проверяет входной массив на наличие телефонов (хэша с ключами prefix, code и number).
  # На выходе выдает очищенный массив хэшей с такими ключами, пропуская пустые телефоны.
  #
  # Было в модели: [{prefix: '+7'}, {code: ' 123 ', number: '1234567', zzz: ''}]
  #
  # Стало в базе: [{prefix: '', code: '123', number: '1234567'}]
  def mongoize
    value = self.value
    return [] unless value.respond_to? :each

    value = value.values if value.is_a? Hash

    result = []
    value.each do |phone|
      phone = {} if phone.blank? or !(phone.is_a? Hash)
      phone = blank_phone.merge phone.stringify_keys

      phone['prefix'] = phone['prefix'].strip
      phone['code']   = clean_numbers(phone['code'].to_s)
      phone['number'] = clean_numbers(phone['number'].to_s)

      if phone['code'].present? or phone['number'].present?
        result << {
            'prefix' => phone['prefix'],
            'code'   => phone['code'],
            'number' => phone['number'],
        }
      end
    end

    result
  end

  # Просто приводит телефоны в базе в соответствие формату.
  def self.demongoize_value(value, parameter_type_class=nil)
    if value
      value.map do |phone|
        phone = phone.stringify_keys!
        {
            'prefix' => phone['prefix'],
            'code'   => phone['code'],
            'number' => phone['number'],
        }
      end
    end
  end

  # Строит форму для заполнения телефонов. В ней будет минимум MIN_PHONES_IN_FORM телефонов, если их меньше, остальные
  # будут добавлены пустые.
  #
  # Также, если заполнены все MIN_PHONES_IN_FORM, добавит 1 пустое поле, чтобы можно было добавить новый телефон.
  #
  # Возвращает ХТМЛ.
  def build_form(form_builder, options)
    set_value_in_hash options
    value = options[:value].presence
    value = [] unless !value.blank? and value.is_a? Array

    result = value.map { |phone| build_single_form(form_builder, phone) }

    [1, CckForms::ParameterTypeClass::Phones::MIN_PHONES_IN_FORM - result.length].max.times { result << build_single_form(form_builder, {}) }

    id = form_builder_name_to_id form_builder
    sprintf '<div id="%s">%s</div>%s', id, result.join, script(id)
  end

  # Строит форму для 1 телефона из значения вида {prefix: '', code: '', number: ''}
  def build_single_form(form_builder, phone)
    phone = {} unless phone.is_a? Hash
    phone = blank_phone.merge phone

    phone_form = []

    form_builder.fields_for(:value, index: '') do |phone_builder|
      phone_form << phone_builder.text_field(:prefix, class: 'input-tiny form-control', value: phone['prefix'])
      phone_form << phone_builder.text_field(:code,   class: 'input-mini form-control', value: phone['code'])
      phone_form << phone_builder.text_field(:number, class: 'input-small form-control', value: phone['number'])
    end

    sprintf '<p class="form-inline">%s &mdash; %s &mdash; %s</p>', phone_form[0], phone_form[1], phone_form[2]
  end

  # Возвращает 1 пустой телефон (хэш вида {prefix: '+7', code: '', number: ''}). Так сказать, эталон.
  def blank_phone
    {
        'prefix' => PREFIX,
        'code'   => '',
        'number' => '',
    }
  end

  def script(id)
    <<HTML
    <script type="text/javascript">
      $(function() {
        var $phones = $("##{id}");
        var doTimes = #{CckForms::ParameterTypeClass::Phones::MIN_PHONES_IN_FORM};

        var createPhone = function() {
          var $newPhone = $phones.children("p:last").clone();
          $newPhone.children("input").each(function() {
            var $this = $(this);
            var isPrefix = $this.prop('name').match(/\\[prefix\\]$/);
            $this.val(isPrefix ? "#{blank_phone['prefix']}" : '');
            var index = $this.prop("id").match(/value_([0-9]+)_/);
            if(!index) {
              return;
            }
            index = index[1] * 1;
            $this.prop("id", $this.prop("id").replace(index, index + 1));
            $this.prop("name", $this.prop("name").replace(index, index + 1));
          })
          $phones.children("p:last").after($newPhone);
        }

        $phones.append('<a href="#" class="add_more">Добавить еще телефонов</a>');
        $phones.children(".add_more").click(function() {
          for(var i = 0; i < doTimes; ++ i) {
            createPhone();
          }
          return false;
        })
      });
    </script>
HTML
  end

  def to_html(options = {})
    phones_list = []
    (value || []).each do |phone|
      if phone['number'] && clean_numbers(phone['number'].to_s).present?
        if phone['prefix'].present? || phone['code'].present?
          prefix = phone['prefix'].present? ? "<span class=\"phone-prefix\">#{phone['prefix']}</span>" : ''
          code = phone['code'].present? ? "<span class=\"phone-code\">#{phone['code']}</span>" : ''
          start = sprintf(phone['code'].in?(MOBILE_CODES) ? '<span class="phone-mobile-prefix">%s(%s)</span>' : '<span class="phone-city-prefix">%s(%s)</span>', prefix, code)
        else
          start = ''
        end

        number = split_number(clean_numbers(phone['number'])).join(NUMBER_PARTS_GLUE)
        phones_list << sprintf('<span class="phone">%s<span class="phone-number">%s</span></span>', start, number)
      end
    end

    phones_list = phones_list.take(options[:limit]) if options[:limit]

    if options[:as_list]
      phones_list
    else
      phones_list.join(', ').html_safe
    end
  end

  def to_s(options = {})
    HTML::FullSanitizer.new.sanitize to_html(options)
  end



  private

  # 123-45-67 asdasd -> 1234567
  def clean_numbers(number)
    number.gsub /\D/, ''
  end

  # 1234567 -> 123 45 67 с тэгами
  def split_number(number)
    if number.length > 4
      tokens = []

      # перевернем строку и разобъем на пары
      number.reverse.scan(/.(?:.|$)/) do |token|
        token.reverse!
        if token.length == 1
          tokens.last.prepend token
        else
          tokens << token
        end
      end

      # сольем все обратно
      tokens.reverse!
      tokens.tap do |tokens|
        tokens.map! { |token| yield token } if block_given?
      end
    else
      yield number if block_given?
      [number]
    end
  end
end
