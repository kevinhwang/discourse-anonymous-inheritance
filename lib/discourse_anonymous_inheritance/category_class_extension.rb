# frozen_string_literal: true

module DiscourseAnonymousInheritance
  # Override scoped_to_permissions for shadow users to additionally append onto
  # their permissions the (inheritable) permissions of their linked master user.
  #
  # This introduces two extra lookups (inheritable group IDs, then category
  # IDs) in the authz path, but keeps things readable and aligned with
  # Discourse's model layer compared to a raw SQL query.
  module CategoryClassExtension
    def scoped_to_permissions(guardian, permission_types)
      base = super
      return base unless guardian&.authenticated? && guardian.is_anonymous? &&
        SiteSetting.anonymous_inheritance_enabled

      master = guardian.user.master_user
      inheritable = SiteSetting.anonymous_inheritance_inheritable_groups_map
      return base unless master && inheritable.present?

      permissions = permission_types.map { |p| CategoryGroup.permission_types[p] }
      inherited_cat_ids =
        CategoryGroup
          .where(
            group_id: master.group_users.where(group_id: inheritable).select(:group_id),
            permission_type: permissions,
          )
          .pluck(:category_id)
      return base if inherited_cat_ids.empty?

      base.or(where(id: inherited_cat_ids))
    end
  end
end
