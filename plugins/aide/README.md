# speckit-ext-aide

**AIDE Workflow** — Vision and requirements analysis for AI-driven development

An extension plugin for the [Spec Kit](https://github.com/speckit-community/cc-spec-kit) workflow.

## Installation

1. Install this plugin from the marketplace
2. Run the install command:
   ```
   /speckit-ext-aide:install
   ```
3. Restart your session to pick up the new skills

## Available Commands

After installation, the following commands are available in your project:

- `speckit.aide.vision`
- `speckit.aide.requirements`

## Registered Hooks

This extension registers the following lifecycle hooks:

- `before_specify`
- `before_plan`

## Removal

To remove this extension from your project:

```
/speckit-ext-aide:remove
```

This will:
- Delete runtime files from `.specify/extensions/aide/`
- Remove command skills from `.claude/skills/`
- Clean hook entries from `.specify/extensions.yml`
- Remove the registry entry

## Requirements

- Core Spec Kit plugin must be initialized (`/speckit:init`)
- No additional runtime dependencies

## License

MIT
