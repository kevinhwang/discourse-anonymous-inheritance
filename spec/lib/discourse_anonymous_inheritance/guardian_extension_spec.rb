# frozen_string_literal: true

RSpec.describe DiscourseAnonymousInheritance::GuardianExtension do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[3]) }
  fab!(:group)
  fab!(:category) do
    cat = Fabricate(:category)
    cat.set_permissions(group => :full)
    cat.save!
    cat
  end

  let(:shadow) { AnonymousShadowCreator.get(user) }
  let(:guardian) { Guardian.new(shadow) }

  before do
    SiteSetting.allow_anonymous_mode = true
    SiteSetting.anonymous_posting_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
    enable_current_plugin
    SiteSetting.anonymous_inheritance_enabled = true
    SiteSetting.anonymous_inheritance_inheritable_groups = group.id.to_s
    group.add(user)
  end

  describe "#can_post_in_category?" do
    it "allows the anonymous user to post in a group-restricted category" do
      expect(guardian.can_post_in_category?(category)).to eq(true)
    end

    it "denies posting when plugin is disabled" do
      SiteSetting.anonymous_inheritance_enabled = false
      expect(Guardian.new(shadow).can_post_in_category?(category)).to eq(false)
    end

    it "denies posting when master is not in the group" do
      group.remove(user)
      shadow.reload
      expect(Guardian.new(shadow).can_post_in_category?(category)).to eq(false)
    end

    it "denies posting in categories with non-inheritable groups" do
      other_group = Fabricate(:group)
      other_group.add(user)
      other_cat = Fabricate(:category)
      other_cat.set_permissions(other_group => :full)
      other_cat.save!

      expect(guardian.can_post_in_category?(other_cat)).to eq(false)
    end

    it "returns false for nil category" do
      expect(guardian.can_post_in_category?(nil)).to eq(false)
    end

    it "does not affect non-anonymous users" do
      expect(Guardian.new(user).can_post_in_category?(category)).to eq(true)
    end

    it "non-anonymous users can still post when plugin is disabled" do
      SiteSetting.anonymous_inheritance_enabled = false
      expect(Guardian.new(user).can_post_in_category?(category)).to eq(true)
    end
  end

  describe "#can_see_category?" do
    it "allows the anonymous user to see a group-restricted category" do
      expect(guardian.can_see_category?(category)).to eq(true)
    end

    it "denies access when plugin is disabled" do
      SiteSetting.anonymous_inheritance_enabled = false
      expect(Guardian.new(shadow).can_see_category?(category)).to eq(false)
    end

    it "denies access when master is not in the group" do
      group.remove(user)
      shadow.reload
      expect(Guardian.new(shadow).can_see_category?(category)).to eq(false)
    end

    it "allows access to unrestricted categories regardless of plugin" do
      public_cat = Fabricate(:category)
      expect(guardian.can_see_category?(public_cat)).to eq(true)
    end
  end

  describe "#can_post_in_category? for unauthenticated users" do
    it "does not interfere with unauthenticated user checks" do
      expect(Guardian.new.can_post_in_category?(category)).to eq(false)
    end
  end

  describe "#can_create_topic_on_category?" do
    it "allows topic creation when the inheritable group is in create_topic_allowed_groups" do
      SiteSetting.create_topic_allowed_groups = "#{Group::AUTO_GROUPS[:admins]}|#{group.id}"
      expect(guardian.can_create_topic_on_category?(category)).to eq(true)
    end

    it "denies topic creation when the inheritable group is not in create_topic_allowed_groups" do
      expect(guardian.can_create_topic_on_category?(category)).to eq(false)
    end
  end
end
