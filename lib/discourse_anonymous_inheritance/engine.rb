# frozen_string_literal: true

module ::DiscourseAnonymousInheritance
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseAnonymousInheritance
  end
end

require_relative "category_class_extension"
require_relative "user_extension"
require_relative "guardian_extension"
