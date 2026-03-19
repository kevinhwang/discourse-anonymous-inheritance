# frozen_string_literal: true

RSpec.describe DiscourseAnonymousInheritance::UserExtension do
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

  describe "#belonging_to_group_ids" do
    it "includes the master's inheritable groups for anonymous users" do
      expect(shadow.belonging_to_group_ids).to include(group.id)
    end

    it "does not include non-inheritable groups" do
      other_group = Fabricate(:group)
      other_group.add(user)
      expect(shadow.belonging_to_group_ids).not_to include(other_group.id)
    end

    it "returns only the shadow's own groups when plugin is disabled" do
      SiteSetting.anonymous_inheritance_enabled = false
      expect(shadow.belonging_to_group_ids).not_to include(group.id)
    end

    it "reflects changes to the master's groups immediately" do
      expect(shadow.belonging_to_group_ids).to include(group.id)
      group.remove(user)
      shadow.reload
      expect(shadow.belonging_to_group_ids).not_to include(group.id)
    end

    it "does not modify the result for non-anonymous users" do
      original_ids = user.belonging_to_group_ids.dup
      expect(original_ids).to include(group.id)
      expect(user.belonging_to_group_ids).to eq(original_ids)
    end
  end

  describe "#in_any_groups?" do
    it "returns true for anonymous user when master is in an inheritable group" do
      expect(shadow.in_any_groups?([group.id])).to eq(true)
    end

    it "returns false for anonymous user when group is not inheritable" do
      other_group = Fabricate(:group)
      other_group.add(user)
      expect(shadow.in_any_groups?([other_group.id])).to eq(false)
    end

    it "returns false for anonymous user when plugin is disabled" do
      SiteSetting.anonymous_inheritance_enabled = false
      expect(shadow.in_any_groups?([group.id])).to eq(false)
    end
  end

  describe "#secure_category_ids" do
    it "includes categories from the master's inheritable groups" do
      expect(shadow.secure_category_ids).to include(category.id)
    end

    it "does not include categories from non-inheritable groups" do
      other_group = Fabricate(:group)
      other_group.add(user)
      other_cat = Fabricate(:category)
      other_cat.set_permissions(other_group => :full)
      other_cat.save!

      expect(shadow.secure_category_ids).not_to include(other_cat.id)
    end

    it "returns only the shadow's own categories when plugin is disabled" do
      SiteSetting.anonymous_inheritance_enabled = false
      expect(shadow.secure_category_ids).not_to include(category.id)
    end

    it "includes categories from multiple inheritable groups" do
      group_b = Fabricate(:group)
      group_b.add(user)
      cat_b = Fabricate(:category)
      cat_b.set_permissions(group_b => :full)
      cat_b.save!
      SiteSetting.anonymous_inheritance_inheritable_groups = "#{group.id}|#{group_b.id}"

      ids = shadow.secure_category_ids
      expect(ids).to include(category.id)
      expect(ids).to include(cat_b.id)
    end

    it "returns sorted IDs" do
      expect(shadow.secure_category_ids).to eq(shadow.secure_category_ids.sort)
    end
  end
end
