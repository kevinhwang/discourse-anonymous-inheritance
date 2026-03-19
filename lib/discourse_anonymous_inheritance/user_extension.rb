# frozen_string_literal: true

module DiscourseAnonymousInheritance
  module UserExtension
    def belonging_to_group_ids
      ids = super
      return ids unless anonymous? && SiteSetting.anonymous_inheritance_enabled

      inherited = DiscourseAnonymousInheritance.inheritable_group_ids_for(self)
      inherited.present? ? ids | inherited : ids
    end

    def secure_category_ids
      ids = super
      return ids unless anonymous? && SiteSetting.anonymous_inheritance_enabled

      inherited = DiscourseAnonymousInheritance.inheritable_group_ids_for(self)
      return ids if inherited.blank?

      inherited_cat_ids = CategoryGroup.where(group_id: inherited).pluck(:category_id)
      (ids | inherited_cat_ids).sort
    end
  end
end
