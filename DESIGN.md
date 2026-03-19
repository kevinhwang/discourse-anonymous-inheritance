# Technical Design

## Discourse Anonymous Mode

When a user toggles into anonymous mode, Discourse creates a separate "shadow" user — a distinct user record with a generated username, no email, and no group memberships. The shadow is linked to the original "master" user in the database. Discourse authenticates the browser session as the shadow, so from the application's perspective it's a completely separate logged-in user.

## Group-Based Category Access

Discourse restricts category access through groups. Each category can be associated with one or more groups at a given permission level (full access, create posts, or read-only). When determining whether a user can see or post in a category, Discourse checks the user's group memberships at multiple layers of the authorization stack: the database query that filters visible categories, the user model that resolves which groups and secured categories a user belongs to, and the Guardian authorization layer that makes the final allow/deny decisions.

Because the shadow user has no group memberships, every layer denies it access to group-restricted categories. Additionally, the Guardian explicitly blocks all anonymous users from posting in any category, regardless of group membership.

## Approach

The plugin patches Discourse's authorization stack so that when an anonymous shadow user is being evaluated, the system also considers the master user's memberships in admin-designated "inheritable" groups. This is done entirely at the read path — no group membership records are created for the shadow user. Instead, each authorization check is extended to look up the master user's live group data on demand.

Four authorization components are patched:

- **Category permission scoping** — The database query that determines which categories a user can access is extended to also check the master user's inheritable group memberships.
- **User group membership resolution** — The user model's group membership lookup is extended to include inherited groups, which flows into downstream permission checks like whether the user is allowed to create topics.
- **Secured category resolution** — The list of read-restricted categories visible to the user is extended to include categories accessible via inherited groups, which flows into the Guardian's category visibility check.
- **Anonymous posting restriction** — The Guardian's blanket block on anonymous users posting in categories is relaxed: instead of denying outright, it delegates to the (now inheritance-aware) category permission check.

All patches fall through to the original Discourse behavior for non-anonymous users and when the plugin is disabled.

## Alternatives Considered

The alternative approach was to actually create group membership records for the shadow user in the database, synced from the master's memberships whenever the user toggles anonymous mode, the master's groups change, or the admin changes the inheritable groups setting. This would work transparently with all existing authorization code without needing to patch it.

This was rejected because it introduces a consistency problem: any path that modifies group memberships outside the hooked events (direct database changes, rake tasks, other plugins) would leave the shadow's memberships stale. It also creates visible side effects — the shadow user would appear in group member listings, inflate group member counts, and require cleanup when the plugin is disabled.

The read-path approach avoids all of these issues. There is no derived state to keep in sync, so it is always consistent with the master user's current group memberships. The tradeoff is a broader patch surface and one additional database query per request for anonymous users.

## Configuration

Two site settings control the plugin: a master toggle, and a group picker where admins select which groups' memberships should be inherited by anonymous shadow users.

## Limitations

Discourse automatically assigns users to "auto-groups" based on trust level, but shadow users do not receive these auto-group memberships. Features gated on auto-group membership (such as topic creation) require the admin to explicitly add an inheritable group to those settings.
