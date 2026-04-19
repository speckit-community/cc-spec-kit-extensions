# speckit-ext-{EXT_ID}

**{EXT_NAME}** — {EXT_DESCRIPTION}

An extension plugin for the [Spec Kit](https://github.com/speckit-community/cc-spec-kit) workflow.

## Installation

1. Install this plugin from the marketplace
2. Run the install command:
   ```
   /speckit-ext-{EXT_ID}:install
   ```
3. Restart your session to pick up the new skills

## Available Commands

After installation, the following commands are available in your project:

{COMMAND_LIST}

## Registered Hooks

This extension registers the following lifecycle hooks:

{HOOK_LIST}

## Removal

To remove this extension from your project:

```
/speckit-ext-{EXT_ID}:remove
```

This will:
- Delete runtime files from `.specify/extensions/{EXT_ID}/`
- Remove command skills from `.claude/skills/`
- Clean hook entries from `.specify/extensions.yml`
- Remove the registry entry

## Requirements

- Core Spec Kit plugin must be initialized (`/speckit:init`)
- No additional runtime dependencies

## License

{EXT_LICENSE}
