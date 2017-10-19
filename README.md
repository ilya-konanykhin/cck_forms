CCK Forms
=========
 
CCK Forms is a companion to the yet-to-be-published CCK gem. (CCK stands for Content Construction Kit — a name borrowed
from PHP Drupal CMS.)

Whilst the CCK gem provides ability to store category-related custom fields in an ActiveModel, this gem defines possible
field types for that matter (string, enum, image album etc.)

As CCK is aimed to simplify storing & editing model fields (especially in admin panels), these custom field types define
common (and complex) notions like work hours, sets of images, WYSIWYG-capable fields and so on. "Define" here means
these field types can be stored in CCK-capable models and they all have HTML form templates. The latter implies possible
standalone usage, for example, if you just need a field of type Image inside your model, you can use CCK Forms without
CCK and still have nice looking and convenient editor form template.

The UI is written in Bootstrap 3 and can not be easily changed, sorry folks.


Criticism
---------

Generally speaking, this gem combines two aspects: CCK-related storage things and UI editor forms. The latter is very
project & design dependent and should not be fixed in the gem (especially in the way it is now, with HTML constructed
in class methods, heavily relying on Bootstrap). Moreover, it may be a good idea to completely decouple UI into separate
gem/module using, say, Simpleforms to do the frontend job.

Then, this gem will only define pure classes to be used either with CCK or standalone as proper "types", like String
or MapPoint or anything else.


Installation, dependencies
--------------------------

***Important***: CCK requires a MongoDB database as a mean to store data, so your models must be Mongoid documents.

Add CCK Forms and its dependencies to your gemfile:

``` ruby
# neofiles-related
gem 'neofiles'
gem 'ruby-imagespec', git: 'git://github.com/dim/ruby-imagespec.git'
gem 'mini_magick', '3.7.0'

gem 'cck_forms'
```

This gem requires [Neofiles](https://github.com/ilya-konanykhin/neofiles) for File, Image and Album types. Please read
its installation instructions, there are some gotchas.

Next, include CSS & JS files where needed (say, application.js or admin.js)...

``` javascript
#= require jquery # neofiles requires jquery
#= require neofiles
#= require cck_forms
```

... and application.css/admin.css or whatever place you need it in:

``` css
 *= require neofiles
```

Don't forget to set up Neofiles routing!


Usage with CCK
--------------

Basic usage only, more to come when CCK gem will finally be published.

```ruby
# in model:
class Content
  include Mongoid::Document
  include Cck::Cckable
  
  cck_config do |c|
    c.category 'news' do |cc|
      cc.string 'title', 'News title'
      cc.enum   'region', valid_values: {world: 'World news', local: 'Local news'}
      cc.image  'announce_pic', 'Announce image', hint: '100x100 only'
      cc.text   'body', 'News article body'
      cc.map    'map_point', 'Where did it happen?'
      
      c.require_params %w{title body}
    end
    
    c.category 'page' do |cc|
      ...
    end
  end
  
  field :category_id, type: String
end

# in controller:
def edit
  @content = Content.new category_id: params[:category_id]
end

# in view:
= form_for @content do |ff|
 = cck_fields_for :cck_params
 
# elsewhere:
content = Content.find(...)
content.cck_params[:title].to_s
content.cck_params[:map_point].value[:latitude]
content.cck_params.to_h.each_pair { |k, v| puts "#{k}: #{v}" } # outputs every CCK field with its ID
```


Standalone usage
----------------

First, create a model and add as many CCK fields as you need:

```ruby
class User
  include Mongoid::Document
  
  field :avatar,  type: CckForms::ParameterTypeClass::Image
  field :cv,      type: CckForms::ParameterTypeClass::File
  field :phones,  type: CckForms::ParameterTypeClass::Phones
  
  validates do |doc|
    if doc.avatar.try(:value) && doc.avatar.value.width > 1000
      doc.errors.add :avatar, 'must be no more than 1000 px wide'
    end
    
    if doc.phones.try(:value) && doc.phones.value.count > 2
      doc.errors.add :phones, 'must have at most 2 phone numbers'
    end
  end
end
```

Then in a view form use helper to output UI:

```slim
= form_for @user, html: {class: 'form-horizontal'} do |f|
  .form-group
    label.control-label.col-sm-2 Avatar
    .col-sm-9= f.standalone_cck_field :avatar
 
  .form-group
     label.control-label.col-sm-2 CV
     .col-sm-9= f.standalone_cck_field :cv, with_desc: true

  .form-group
    label.control-label.col-sm-2 Phone numbers
    .col-sm-9= f.standalone_cck_field :phones
end
```

Use model fields as usual with one exception: to get a field value you need to unwrap its first with call to `value`
(as it is a wrapper class instance). Assign values directly though.

```ruby
user = User.first
puts "User avatar file: #{neofiles_image_path user.avatar.value} (#{user.avatar.value.length} bytes)"
puts "User phone#{user.phones.try(:value).try(:count).to_i == 0 ? '' : 's'}: #{user.phones.to_s}"

user.avatar = Neofiles::Image.find(...)
user.phones = ['+7 111 222 33 44', '1231231231', {prefix: '+906', code: '1234', number: '223344'}]
user.save! # should raise exception indicating phones validation failure
```

Common methods:
* `value`: returns the real field value. Each field type has its own value, say Phones returns an array of phone numbers
   and Map returns a hash with keys `:latitude, :longitude, :zoom`
* `to_s`: string representation
* `to_html`: HTML representation
* `to_diff_value`: representation in form was/became to show history of changes
* `search`: returns a Mongoid Criteria filled with search query params specific to this particular field type
* `build_form`: builds an HTML editor form


Available field types
---------------------

***Album***: sortable collection of images.

***Boolean***: checkbox.

***Checkboxes***: several checkboxes. Requires the `valid_values` option.

***Date, DateTime, Time***: date/date&time/time select.

***DateRange***: two sets of selects "date from/till".

***Enum***: select or set of radio buttons. Requires the `valid_values` option.

***File, Image***: single file or image.

***Integer, Float***: numeric input.

***IntegerRange***: two inputs for "number from/till".

***Map***: map point. Two map providers available: Google and Yandex. Google requires an API key.

***Phones***: array of phone numbers.

***String***: text input.

***StringCollection***: set of strings. Represented by a textarea, one line — one string.

***Text***: textarea.

***WorkHours***: complex input to construct work schedule on a weekly basis.

***WatermarklessAlbum***, ***WatermarklessImage***: same as Album & Image, but do not place watermarks. For banners or
important sliders, for example.

Configuration
-------------

CCK Forms offers the following config options which can be set in `config/application.rb` or `config/environments/*.rb`:

```ruby
# load all available type classes on application start
config.cck_forms.load_type_classes = true

# extend default form builder to add `standalone_cck_field` method
config.cck_forms.extend_form_builder = true

# how many phone numbers will the edit form contain by default for each field
config.cck_forms.phones.min_phones_in_form = 3

# which area codes are considered as mobile carrier codes (mobile and landline numbers have different HTML forms)
# the codes listed below are Kazakhstan mobile operators as of year 2016
config.cck_forms.phones.mobile_codes = %w{ 777 705 771   701 702 775 778   700   707 }

# phone number prefix
# +7 is Russia/Kazakhstan
config.cck_forms.phones.prefix = '+7'

# the glue for concatenating phone number parts: 111[glue]22[glue]33
config.cck_forms.phones.number_parts_glue = '-'

# the default map provider; if not specified, google is the default
config.cck_forms.maps.default_type = 'yandex'.freeze
```


Roadmap, TODOs
--------------

- Add new field type: Tags (a collection of — possibly pre-set — strings)
- Extract HTML templates into separate gem/module
- Extract map providers or at lease make them configurable
- Custom phone format on input/ouput (`#build_form, #to_html`)


License
-------

Released under the [MIT License](http://www.opensource.org/licenses/MIT).
