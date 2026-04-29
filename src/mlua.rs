use std::{env, fs, path::Path};

use zed_extension_api::{
    self as zed,
    http_client::{HttpMethod, HttpRequest},
    serde_json::{json, Value},
    settings::LspSettings,
    LanguageServerId, LanguageServerInstallationStatus, Result,
};

const LANGUAGE_SERVER_ID: &str = "mlua-language-server";
const FALLBACK_MLUA_VERSION: &str = "1.1.5";
const CACHE_DIR_PREFIX: &str = "msw-mlua-vsix-";
const MARKETPLACE_QUERY_URL: &str =
    "https://marketplace.visualstudio.com/_apis/public/gallery/extensionquery?api-version=7.2-preview.1";
const WRAPPER_PATH: &str = "mlua-lsp-wrapper.js";
const WRAPPER_JS: &str = include_str!("../server/mlua-lsp-wrapper.js");

struct MluaExtension {
    cached_server_path: Option<String>,
}

struct MluaPackage {
    version: String,
    vsix_url: String,
}

impl MluaExtension {
    fn language_server_path(&mut self, language_server_id: &LanguageServerId) -> Result<String> {
        let package = match Self::latest_marketplace_package() {
            Ok(package) => package,
            Err(err) => {
                if let Some(path) = Self::latest_cached_server_path() {
                    self.cached_server_path = Some(path.clone());
                    return Ok(path);
                }

                eprintln!(
                    "failed to query latest mLua VSIX version, falling back to {FALLBACK_MLUA_VERSION}: {err}"
                );
                MluaPackage {
                    version: FALLBACK_MLUA_VERSION.to_string(),
                    vsix_url: Self::marketplace_vsix_url(FALLBACK_MLUA_VERSION),
                }
            }
        };

        let version_dir = format!("{CACHE_DIR_PREFIX}{}", package.version);
        let server_path = format!("{version_dir}/extension/scripts/server/out/languageServer.js");

        let absolute_server_path = Self::absolute_path(&server_path)?;

        if let Some(path) = &self.cached_server_path {
            if path == &absolute_server_path && fs::metadata(path).is_ok_and(|stat| stat.is_file())
            {
                return Ok(path.clone());
            }
        }

        if !fs::metadata(&server_path).is_ok_and(|stat| stat.is_file()) {
            zed::set_language_server_installation_status(
                language_server_id,
                &LanguageServerInstallationStatus::Downloading,
            );

            zed::download_file(
                &package.vsix_url,
                &version_dir,
                zed::DownloadedFileType::Zip,
            )
            .map_err(|err| format!("failed to download mLua VSIX {}: {err}", package.version))?;
        }

        if !fs::metadata(&server_path).is_ok_and(|stat| stat.is_file()) {
            return Err(format!(
                "mLua language server was not found after extracting VSIX: {server_path}"
            ));
        }

        self.cached_server_path = Some(absolute_server_path.clone());
        Ok(absolute_server_path)
    }

    fn latest_marketplace_package() -> Result<MluaPackage> {
        let body = json!({
            "filters": [{
                "criteria": [{
                    "filterType": 7,
                    "value": "msw.mlua"
                }]
            }],
            "flags": 914
        })
        .to_string();

        let request = HttpRequest::builder()
            .method(HttpMethod::Post)
            .url(MARKETPLACE_QUERY_URL)
            .header("Content-Type", "application/json")
            .header("Accept", "application/json")
            .body(body.into_bytes())
            .build()?;

        let response = request
            .fetch()
            .map_err(|err| format!("failed to query Visual Studio Marketplace: {err}"))?;
        let response_body = String::from_utf8(response.body)
            .map_err(|err| format!("marketplace response was not UTF-8: {err}"))?;
        let response_json: Value = zed::serde_json::from_str(&response_body)
            .map_err(|err| format!("failed to parse marketplace response: {err}"))?;

        let version = response_json
            .pointer("/results/0/extensions/0/versions/0/version")
            .and_then(Value::as_str)
            .map(ToString::to_string)
            .ok_or_else(|| "marketplace response did not include an mLua version".to_string())?;

        let vsix_url = response_json
            .pointer("/results/0/extensions/0/versions/0/files")
            .and_then(Value::as_array)
            .and_then(|files| {
                files.iter().find_map(|file| {
                    let asset_type = file.get("assetType").and_then(Value::as_str)?;
                    if asset_type == "Microsoft.VisualStudio.Services.VSIXPackage" {
                        file.get("source").and_then(Value::as_str)
                    } else {
                        None
                    }
                })
            })
            .map(ToString::to_string)
            .ok_or_else(|| "marketplace response did not include a VSIX asset URL".to_string())?;

        Ok(MluaPackage { version, vsix_url })
    }

    fn marketplace_vsix_url(version: &str) -> String {
        format!(
            "https://msw.gallery.vsassets.io/_apis/public/gallery/publisher/msw/extension/mlua/{version}/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage"
        )
    }

    fn latest_cached_server_path() -> Option<String> {
        let mut candidates = Vec::new();

        for entry in fs::read_dir(".").ok()? {
            let entry = entry.ok()?;
            let file_name = entry.file_name();
            let file_name = file_name.to_string_lossy();
            let Some(version) = file_name.strip_prefix(CACHE_DIR_PREFIX) else {
                continue;
            };

            let server_path = format!("{file_name}/extension/scripts/server/out/languageServer.js");
            if fs::metadata(&server_path).is_ok_and(|stat| stat.is_file()) {
                let absolute_server_path = Self::absolute_path(&server_path).ok()?;
                candidates.push((Self::version_key(version), absolute_server_path));
            }
        }

        candidates.sort_by(|left, right| left.0.cmp(&right.0));
        candidates.pop().map(|(_, path)| path)
    }

    fn version_key(version: &str) -> Vec<u64> {
        version
            .split('.')
            .map(|part| part.parse::<u64>().unwrap_or(0))
            .collect()
    }

    fn node_path(worktree: &zed::Worktree) -> Result<String> {
        zed::node_binary_path().or_else(|_| {
            worktree
                .which("node")
                .ok_or_else(|| "node was not found on PATH".into())
        })
    }

    fn wrapper_path() -> Result<String> {
        let should_write =
            fs::read_to_string(WRAPPER_PATH).map_or(true, |current| current != WRAPPER_JS);

        if should_write {
            fs::write(WRAPPER_PATH, WRAPPER_JS)
                .map_err(|err| format!("failed to write mLua LSP wrapper: {err}"))?;
        }

        Self::absolute_path(WRAPPER_PATH)
    }

    fn absolute_path(path: impl AsRef<Path>) -> Result<String> {
        let path = path.as_ref();
        let absolute = if path.is_absolute() {
            path.to_path_buf()
        } else {
            env::current_dir()
                .map_err(|err| format!("failed to read extension working directory: {err}"))?
                .join(path)
        };

        Ok(absolute.to_string_lossy().into_owned())
    }
}

impl zed::Extension for MluaExtension {
    fn new() -> Self {
        Self {
            cached_server_path: None,
        }
    }

    fn language_server_command(
        &mut self,
        language_server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        if language_server_id.as_ref() != LANGUAGE_SERVER_ID {
            return Err(format!(
                "unknown language server id for mLua extension: {language_server_id}"
            ));
        }

        zed::set_language_server_installation_status(
            language_server_id,
            &LanguageServerInstallationStatus::CheckingForUpdate,
        );

        let node_path = Self::node_path(worktree)?;
        let server_path = self.language_server_path(language_server_id)?;
        let wrapper_path = Self::wrapper_path()?;
        let args = vec![wrapper_path, server_path, worktree.root_path()];

        Ok(zed::Command {
            command: node_path,
            args,
            env: vec![],
        })
    }

    fn language_server_initialization_options(
        &mut self,
        language_server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<Option<zed::serde_json::Value>> {
        LspSettings::for_worktree(language_server_id.as_ref(), worktree)
            .map(|settings| settings.initialization_options)
            .or(Ok(None))
    }
}

zed::register_extension!(MluaExtension);
