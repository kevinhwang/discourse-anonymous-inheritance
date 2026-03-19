# frozen_string_literal: true

RSpec.describe DiscourseAnonymousInheritance::CategoryClassExtension do
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

  describe ".scoped_to_permissions" do
    it "includes group-restricted categories for anonymous users" do
      expect(Category.scoped_to_permissions(guardian, [:full])).to include(category)
    end

    it "excludes group-restricted categories when plugin is disabled" do
      SiteSetting.anonymous_inheritance_enabled = false
      expect(
        Category.scoped_to_permissions(Guardian.new(shadow), [:full])
      ).not_to include(category)
    end

    it "includes unrestricted categories for anonymous users" do
      public_cat = Fabricate(:category)
      expect(Category.scoped_to_permissions(guardian, [:readonly])).to include(public_cat)
    end

    it "does not affect non-anonymous users" do
      expect(
        Category.scoped_to_permissions(Guardian.new(user), [:full])
      ).to include(category)
    end

    it "respects create_post permission level" do
      cat_create = Fabricate(:category)
      cat_create.set_permissions(group => :create_post)
      cat_create.save!

      expect(Category.scoped_to_permissions(guardian, [:create_post])).to include(cat_create)
    end

    it "respects readonly permission level" do
      cat_readonly = Fabricate(:category)
      cat_readonly.set_permissions(group => :readonly)
      cat_readonly.save!

      expect(Category.scoped_to_permissions(guardian, [:readonly])).to include(cat_readonly)
    end

    it "excludes categories when permission level does not match" do
      cat_readonly = Fabricate(:category)
      cat_readonly.set_permissions(group => :readonly)
      cat_readonly.save!

      expect(Category.scoped_to_permissions(guardian, [:full])).not_to include(cat_readonly)
    end

    it "works with unauthenticated users" do
      expect(
        Category.scoped_to_permissions(Guardian.new, [:readonly])
      ).not_to include(category)
    end

    it "works with admin users" do
      admin_guardian = Guardian.new(Fabricate(:admin))
      expect(Category.scoped_to_permissions(admin_guardian, [:full])).to include(category)
    end

    it "preserves categories accessible via the shadow's own group memberships" do
      shadow_own_group = Fabricate(:group)
      shadow_own_cat = Fabricate(:category)
      shadow_own_cat.set_permissions(shadow_own_group => :full)
      shadow_own_cat.save!
      shadow_own_group.add(shadow)

      result = Category.scoped_to_permissions(guardian, [:full])
      expect(result).to include(shadow_own_cat)
      expect(result).to include(category)
    end
  end
end
