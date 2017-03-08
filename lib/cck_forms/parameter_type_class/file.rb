# Represents a single file.
#
class CckForms::ParameterTypeClass::File
  include CckForms::ParameterTypeClass::Base
  include CckForms::NeofilesDenormalize

  def self.file_type
    ::Neofiles::File
  end

  def file_type
    self.class.file_type
  end

  # Converts Neofiles::File or its ID into denormalized Hash to be stored in MongoDB
  def mongoize
    self.class.neofiles_attrs_or_id value, file_type
  end

  # Converts denormalized attrs hash or ID to Neofiles::File instance (possibly lazy loadable)
  def self.demongoize_value(value, parameter_type_class=nil)
    neofiles_mock_or_load value
  end

  # Constructs HTML form for image upload & manipulation. Basically, it is a DIV with some ID and a Javascript widget
  # creation for that DIV.
  #
  # options:
  #
  #   value     - current value (ID or Neofiles::File)
  #   with_desc - if true, show the description edit richtext (default false)
  def build_form(form_builder, options)
    set_value_in_hash options
    self.class.create_load_form helper: self,
                                file: options[:value].presence,
                                input_name: form_builder.object_name + '[value]',
                                widget_id: form_builder_name_to_id(form_builder, '[value]'),
                                with_desc: options[:with_desc]
  end

  # Create image load DIV & script. A separate function to allow other (non-CCK) fields to utilize this functionality.
  #
  #   helper    - view context for HTML generation (`self` in views or `view_context` in controllers)
  #   file      - Neofiles::File or ID
  #   widget_id - DIV ID
  #   input_name, append_create, clean_remove, disabled, multiple, with_desc
  #             - Neofiles arguments, see Neofiles::AdminController
  def self.create_load_form(helper:, file:, input_name:, append_create: false, clean_remove: false, widget_id: nil, disabled: false, multiple: false, with_desc: false)
    cont_id   = 'container_' + (widget_id.presence || form_name_to_id(input_name))

    # create temporary hidden field to keep the value in form context until AJAX request is finished
    # (otherwise submitting the form before that moment sends it without the file value which can lead to confusion
    # and consequent data loss in a controller)
    file_id = file.is_a?(file_type) ? file.id.to_s : file.to_s
    temp_field, remove_temp_field = '', ''
    if file_id.present?
      temp_id           = "temp_file_field_#{file_id}"
      temp_field        = '<input id="' + temp_id + '" type="hidden" name="' + input_name + '" value="' + file_id + '">'
      remove_temp_field = '$("#' + temp_id + '").remove();'
    end

    file_attributes = {
        id: file_id,
        input_name: input_name,
        widget_id: widget_id,
        append_create: append_create ? '1' : nil,
        clean_remove: clean_remove ? '1' : nil,
        disabled: disabled ? '1' : nil,
        multiple: multiple ? '1' : nil,
        with_desc: with_desc ? '1' : nil
    }

    file_attributes.merge!(additional_file_attributes) if defined? additional_file_attributes

    '<div id="' + cont_id + '"></div>
    ' + temp_field + '

    <script type="text/javascript">
      $(function() {
          $("#' + cont_id + '").load("' + helper.neofiles_file_compact_path(file_attributes) + '", null, function() {
              $(this).children().unwrap();
              ' + remove_temp_field + '
          });
      });
    </script>'
  end

  # Returns empty string
  def to_s(_options = nil)
    ''
  end

  # Returns a file name
  def to_diff_value(_options = {})
    value.try! :name
  end
end
