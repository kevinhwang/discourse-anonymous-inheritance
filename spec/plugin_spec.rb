# frozen_string_literal: true

RSpec.describe "DiscourseAnonymousInheritance" do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[3]) }
  fab!(:group)
  fab!(:category) do
    cat = Fabricate(:category)
    cat.set_permissions(group => :full)
    cat.save!
    cat
  end

  let(:shadow) { AnonymousShadowCreator.get(user) }

  before do
    SiteSetting.allow_anonymous_mode = true
    SiteSetting.anonymous_posting_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
    enable_current_plugin
    SiteSetting.anonymous_inheritance_enabled = true
    SiteSetting.anonymous_inheritance_inheritable_groups = group.id.to_s
    group.add(user)
  end

  describe ".inheritable_group_ids_for" do
    it "returns the master's inheritable group IDs for an anonymous user" do
      expect(
        DiscourseAnonymousInheritance.inheritable_group_ids_for(shadow)
      ).to contain_exactly(group.id)
    end

    it "returns empty when the master is not in any inheritable groups" do
      group.remove(user)
      expect(
        DiscourseAnonymousInheritance.inheritable_group_ids_for(shadow)
      ).to be_empty
    end

    it "returns empty for a non-anonymous user" do
      expect(
        DiscourseAnonymousInheritance.inheritable_group_ids_for(user)
      ).to be_empty
    end

    it "returns empty when plugin is disabled" do
      SiteSetting.anonymous_inheritance_enabled = false
      expect(
        DiscourseAnonymousInheritance.inheritable_group_ids_for(shadow)
      ).to be_empty
    end

    it "returns empty for nil user" do
      expect(
        DiscourseAnonymousInheritance.inheritable_group_ids_for(nil)
      ).to be_empty
    end

    it "returns empty when no inheritable groups are configured" do
      SiteSetting.anonymous_inheritance_inheritable_groups = ""
      expect(
        DiscourseAnonymousInheritance.inheritable_group_ids_for(shadow)
      ).to be_empty
    end

    it "only returns groups in the inheritable list" do
      other_group = Fabricate(:group)
      other_group.add(user)
      expect(
        DiscourseAnonymousInheritance.inheritable_group_ids_for(shadow)
      ).to contain_exactly(group.id)
    end

    it "returns multiple groups when master is in multiple inheritable groups" do
      group_b = Fabricate(:group)
      group_b.add(user)
      SiteSetting.anonymous_inheritance_inheritable_groups = "#{group.id}|#{group_b.id}"

      expect(
        DiscourseAnonymousInheritance.inheritable_group_ids_for(shadow)
      ).to contain_exactly(group.id, group_b.id)
    end

    it "returns only the inheritable subset when master is in extra groups" do
      group_b = Fabricate(:group)
      group_c = Fabricate(:group)
      group_b.add(user)
      group_c.add(user)
      SiteSetting.anonymous_inheritance_inheritable_groups = "#{group.id}|#{group_b.id}"

      result = DiscourseAnonymousInheritance.inheritable_group_ids_for(shadow)
      expect(result).to contain_exactly(group.id, group_b.id)
      expect(result).not_to include(group_c.id)
    end
  end

  describe "end-to-end: access changes with master's groups" do
    it "grants access immediately when master is added to an inheritable group" do
      group.remove(user)
      shadow.reload
      expect(Guardian.new(shadow).can_see_category?(category)).to eq(false)

      group.add(user)
      shadow.reload
      expect(Guardian.new(shadow).can_see_category?(category)).to eq(true)
    end

    it "revokes access immediately when master is removed from an inheritable group" do
      expect(Guardian.new(shadow).can_see_category?(category)).to eq(true)

      group.remove(user)
      shadow.reload
      expect(Guardian.new(shadow).can_see_category?(category)).to eq(false)
    end

    it "anonymous user does not appear in group member listings" do
      expect(group.users).to include(user)
      expect(group.users).not_to include(shadow)
    end

    it "updates access when inheritable groups setting changes" do
      expect(Guardian.new(shadow).can_see_category?(category)).to eq(true)

      SiteSetting.anonymous_inheritance_inheritable_groups = ""
      shadow.reload
      expect(Guardian.new(shadow).can_see_category?(category)).to eq(false)
    end

    it "handles adding a new group to the inheritable list" do
      group_b = Fabricate(:group)
      group_b.add(user)
      cat_b = Fabricate(:category)
      cat_b.set_permissions(group_b => :full)
      cat_b.save!

      expect(Guardian.new(shadow).can_see_category?(cat_b)).to eq(false)

      SiteSetting.anonymous_inheritance_inheritable_groups = "#{group.id}|#{group_b.id}"
      shadow.reload
      expect(Guardian.new(shadow).can_see_category?(cat_b)).to eq(true)
    end

    it "grants full posting access through inherited group membership" do
      topic = Fabricate(:topic, category: category, user: user)
      expect(Guardian.new(shadow).can_see_category?(category)).to eq(true)
      expect(Guardian.new(shadow).can_post_in_category?(category)).to eq(true)
      expect(Guardian.new(shadow).can_create_post?(topic)).to eq(true)
    end
  end
end
