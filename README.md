# discourse-anonymous-inheritance

[![Status Badge](https://github.com/kevinhwang/discourse-anonymous-inheritance/actions/workflows/discourse-plugin.yml/badge.svg)](https://github.com/kevinhwang/discourse-anonymous-inheritance/actions/workflows/discourse-plugin.yml)

A Discourse plugin that allows anonymous users to inherit configurable attributes from their backing authenticated user.

Currently only supports inheriting group memberships.

## Context

Discourse's anonymous mode creates a separate shadow user with no group memberships. This means anonymous users can't participate in group-restricted categories, even when the admin has enabled anonymous posting for those users.

## How It Works

Admins select which groups are "inheritable." When a user switches to anonymous mode, their anonymous identity automatically gains access to categories restricted to those groups — without creating any visible group membership for the anonymous user.

Access is always resolved live from the backing user's current group memberships. If the real user is added to or removed from a group, the anonymous user's access updates immediately.

## Setup

1. Install the plugin in your Discourse instance
2. Go to **Admin > Settings** and search for "anonymous inheritance"
3. Enable **anonymous inheritance enabled**
4. In **anonymous inheritance inheritable groups**, select the groups whose memberships should carry over to anonymous users
5. Ensure **allow anonymous mode** (core Discourse setting) is also enabled

## Privacy Considerations

This plugin introduces a privacy tradeoff. If an anonymous user posts in a lot of specific categories, attackers may be able to correlate that with real users who have access to those same categories.

This is a known privacy tradeoff you have to accept when using the plugin.

The anonymous user does not appear in any group directory listings, so correlation requires an anonymous user post in enough categories, the intersection of which contains a meaningfully unique subset of real users.

Admins with database access can already deanonymize users, so this plugin does not change the admin threat model.

## Technical Details

See [DESIGN.md](./DESIGN.md).
