# frozen_string_literal: true

# name: discourse-anonymous-inheritance
# about: Allows anonymous shadow users to inherit group memberships from their backing user
# version: 0.1.0
# authors: Kevin Hwang <hellokevinhwang@gmail.com>
# url: https://github.com/kevinhwang/discourse-anonymous-inheritance

enabled_site_setting :anonymous_inheritance_enabled

module ::DiscourseAnonymousInheritance
  PLUGIN_NAME = "discourse-anonymous-inheritance"

  def self.inheritable_group_ids_for(user)
    return [] unless SiteSetting.anonymous_inheritance_enabled
    return [] unless user&.anonymous?

    master = user.master_user
    return [] unless master

    inheritable = SiteSetting.anonymous_inheritance_inheritable_groups_map
    return [] if inheritable.empty?

    master.group_users.where(group_id: inheritable).pluck(:group_id)
  end
end

require_relative "lib/discourse_anonymous_inheritance/engine"

after_initialize do
  reloadable_patch do
    Category.singleton_class.prepend DiscourseAnonymousInheritance::CategoryClassExtension
    User.prepend DiscourseAnonymousInheritance::UserExtension
    Guardian.prepend DiscourseAnonymousInheritance::GuardianExtension
  end
end
