# mLua for Zed

`mlua-zed` is a Zed language extension for MapleStory Worlds mLua files.

This extension wraps the official MSW VS Code extension package
[`msw.mlua`](https://marketplace.visualstudio.com/items?itemName=msw.mlua).
On first use, it queries Visual Studio Marketplace, downloads the latest VSIX
package into Zed's extension cache, and starts the bundled mLua language server
through a small Node.js LSP wrapper. The language server behavior comes from the
official MSW extension; this repository provides the Zed integration layer.

## Status

This extension has not been published to the Zed Extension Gallery yet. Install
it as a Zed dev extension from a local checkout.

## Features

- `.mlua` file association and language registration
- Syntax highlighting for Lua and common mLua declarations
- Official MSW mLua language server bridge
- Completion, diagnostics, hover, references, rename, inlay hints, formatting,
  and semantic tokens through the bundled language server
- Semantic token rules for mLua token types
- Latest VSIX lookup with cached fallback

## Requirements

- Zed
- Rust installed via `rustup`, which Zed requires for local dev extensions
- Node.js available through Zed or on `PATH`
- Internet access on first use to download the official MSW VSIX package from
  Visual Studio Marketplace

## Installation

Clone this repository, then install it as a dev extension in Zed:

1. Open Zed.
2. Open the Extensions page or run `zed: install dev extension` from the
   command palette.
3. Select the local `mlua-zed` repository directory.
4. Open a project that contains `.mlua` files.

After updating the local repository, reinstall the dev extension or reload Zed so
the latest extension code is used.

## Recommended Settings

Enable semantic tokens for the best mLua coloring. Add this to your Zed user or
project settings:

```json
{
  "languages": {
    "mLua": {
      "semantic_tokens": "combined"
    }
  }
}
```

## How It Works

The extension does not reimplement the mLua language server. Instead, it:

1. Looks up the latest `msw.mlua` VS Code extension version from Visual Studio
   Marketplace.
2. Downloads and extracts the VSIX package into Zed's extension work directory.
3. Starts the official language server with a Node.js wrapper that adapts it for
   Zed's LSP runtime.
4. Reuses the cached package when Marketplace is unavailable.

The current syntax parser is `tree-sitter-lua`, so syntax-tree features for
mLua-only constructs are best effort. The official language server is the source
of truth for semantic features.

## Troubleshooting

- If the language server does not start, confirm that Node.js is available.
- If the first download fails, confirm that `marketplace.visualstudio.com` and
  `msw.gallery.vsassets.io` are reachable.
- If highlighting looks incomplete, enable semantic tokens with the setting
  shown above.
