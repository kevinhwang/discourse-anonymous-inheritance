# frozen_string_literal: true

module DiscourseAnonymousInheritance
  module GuardianExtension
    # The original unconditionally blocks anonymous users from posting.
    def can_post_in_category?(category)
      if authenticated? && is_anonymous? && SiteSetting.anonymous_inheritance_enabled
        return false unless category
        return Category.post_create_allowed(self).exists?(id: category.id)
      end
      super
    end
  end
end
