# mLua for Zed

Zed extension for `.mlua` files.

This extension does not vendor the official mLua VS Code extension. On first use,
it queries Visual Studio Marketplace for the latest `msw.mlua` version, downloads
the corresponding CDN VSIX asset into a versioned local cache, and runs its
bundled language server through a small Node.js LSP wrapper.

## Features

- `.mlua` language registration
- Lua-based Tree-sitter highlighting as a fallback
- Official mLua language server bridge
- Latest VSIX version lookup with cached fallback
- mLua initialization data built from the downloaded VSIX package
- Semantic token rules for mLua token types

## Notes

The current parser is `tree-sitter-lua`, so Zed's syntax tree features are best
effort for mLua-only syntax. The language server is the source of truth for
completion, diagnostics, hover, references, rename, inlay hints, formatting, and
semantic tokens.

To let the LSP drive mLua coloring without installing an mLua-only theme, enable
semantic tokens for this language in Zed settings:

```json
{
  "languages": {
    "mLua": {
      "semantic_tokens": "combined"
    }
  }
}
```

If Zed blocks downloads with restricted extension capabilities, allow downloads
from `marketplace.visualstudio.com`. If the version lookup cannot reach
Marketplace, the extension uses the newest local cache that is already present.
