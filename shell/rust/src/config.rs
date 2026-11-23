use std::env;
use std::fs;
use std::path::{Path, PathBuf};

use directories::ProjectDirs;
use serde::{Deserialize, Serialize};

pub const APP_QUALIFIER: &str = "cn";
pub const APP_ORGANIZATION: &str = "ntars";
pub const APP_NAME: &str = "TapMC";

/// User-editable launcher settings.
///
/// The default paths point at the runtime data directory rather than the
/// repository, so launching a release build never writes save data into the
/// checkout.
#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(default)]
pub struct LauncherConfig {
    pub java_path: String,
    pub server_jar: String,
    pub server_host: String,
    pub server_port: u16,
    pub save_file: String,
    pub mods_dir: String,
    pub autosave_seconds: u64,
    pub manage_server: bool,
    pub theme: ThemePreference,
}

#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum ThemePreference {
    #[default]
    Dark,
    Light,
}

impl ThemePreference {
    pub fn label(self) -> &'static str {
        match self {
            Self::Dark => "深色",
            Self::Light => "浅色",
        }
    }

    pub fn toggled(self) -> Self {
        match self {
            Self::Dark => Self::Light,
            Self::Light => Self::Dark,
        }
    }
}

impl Default for LauncherConfig {
    fn default() -> Self {
        let paths = AppPaths::discover();
        Self {
            java_path: "java".to_owned(),
            server_jar: paths
                .repo_root
                .as_ref()
                .map(|root| root.join("dist/server/server-0.1.0-all.jar"))
                .unwrap_or_else(|| PathBuf::from("dist/server/server-0.1.0-all.jar"))
                .display()
                .to_string(),
            server_host: "127.0.0.1".to_owned(),
            server_port: 8777,
            save_file: paths.data_dir.join("world.json").display().to_string(),
            mods_dir: paths.data_dir.join("mods").display().to_string(),
            autosave_seconds: 60,
            manage_server: true,
            theme: ThemePreference::Dark,
        }
    }
}

impl LauncherConfig {
    pub fn load() -> Self {
        let path = AppPaths::discover().config_file;
        fs::read_to_string(&path)
            .ok()
            .and_then(|raw| serde_json::from_str(&raw).ok())
            .unwrap_or_default()
    }

    pub fn save(&self) -> Result<(), String> {
        let paths = AppPaths::discover();
        if let Some(parent) = paths.config_file.parent() {
            fs::create_dir_all(parent)
                .map_err(|error| format!("无法创建配置目录 {}：{error}", parent.display()))?;
        }
        let raw = serde_json::to_string_pretty(self)
            .map_err(|error| format!("无法序列化启动器配置：{error}"))?;
        fs::write(&paths.config_file, raw)
            .map_err(|error| format!("无法写入配置 {}：{error}", paths.config_file.display()))
    }

    pub fn validate(&self) -> Result<(), String> {
        if self.server_port == 0 {
            return Err("服务端端口必须在 1-65535 之间".to_owned());
        }
        if self.server_host.trim().is_empty() {
            return Err("服务端地址不能为空".to_owned());
        }
        if self.java_path.trim().is_empty() {
            return Err("Java 路径不能为空".to_owned());
        }
        if self.manage_server {
            if self.server_jar.trim().is_empty() {
                return Err("托管启动时必须指定服务端 JAR".to_owned());
            }
            if !Path::new(&self.server_jar).is_file() {
                return Err(format!(
                    "服务端 JAR 不存在：{}。请先运行 scripts/build_release.sh",
                    self.server_jar
                ));
            }
            if self.save_file.trim().is_empty() {
                return Err("存档路径不能为空".to_owned());
            }
        }
        Ok(())
    }

    pub fn endpoint(&self) -> String {
        format!("ws://{}:{}/", self.server_host, self.server_port)
    }

    pub fn server_args(&self) -> Vec<String> {
        let mut args = vec![
            "-jar".to_owned(),
            self.server_jar.clone(),
            "--host".to_owned(),
            self.server_host.clone(),
            "--port".to_owned(),
            self.server_port.to_string(),
            "--save-file".to_owned(),
            self.save_file.clone(),
            "--mods".to_owned(),
            self.mods_dir.clone(),
            "--autosave".to_owned(),
            self.autosave_seconds.to_string(),
        ];
        if self.autosave_seconds == 0 {
            args.retain(|arg| arg != "--save-file" && arg != &self.save_file);
        }
        args
    }
}

#[derive(Clone, Debug)]
pub struct AppPaths {
    pub repo_root: Option<PathBuf>,
    pub config_file: PathBuf,
    pub data_dir: PathBuf,
}

impl AppPaths {
    pub fn discover() -> Self {
        let repo_root = env::current_dir()
            .ok()
            .and_then(|dir| find_repo_root(&dir))
            .or_else(|| {
                let exe = env::current_exe().ok()?;
                exe.parent()
                    .and_then(find_repo_root)
                    .or_else(|| exe.parent()?.parent().and_then(find_repo_root))
            });

        let fallback = repo_root
            .clone()
            .unwrap_or_else(|| env::temp_dir().join("tapmc"));
        let project = ProjectDirs::from(APP_QUALIFIER, APP_ORGANIZATION, APP_NAME);
        let config_dir = project
            .as_ref()
            .map(|p| p.config_dir().to_path_buf())
            .unwrap_or_else(|| fallback.join("config"));
        let data_dir = project
            .as_ref()
            .map(|p| p.data_dir().to_path_buf())
            .unwrap_or_else(|| fallback.join("data"));

        Self {
            repo_root,
            config_file: config_dir.join("launcher.json"),
            data_dir,
        }
    }
}

fn find_repo_root(start: &Path) -> Option<PathBuf> {
    start.ancestors().find_map(|candidate| {
        let backend = candidate.join("core/backend/settings.gradle.kts");
        let protocol = candidate.join("core/docs/protocol.md");
        (backend.is_file() && protocol.is_file()).then(|| candidate.to_path_buf())
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_config() -> LauncherConfig {
        LauncherConfig {
            java_path: "java".to_owned(),
            server_jar: "/tmp/server.jar".to_owned(),
            server_host: "127.0.0.1".to_owned(),
            server_port: 8788,
            save_file: "/tmp/world.json".to_owned(),
            mods_dir: "/tmp/mods".to_owned(),
            autosave_seconds: 30,
            manage_server: false,
            theme: ThemePreference::Light,
        }
    }

    #[test]
    fn endpoint_uses_configured_host_and_port() {
        assert_eq!(sample_config().endpoint(), "ws://127.0.0.1:8788/");
    }

    #[test]
    fn server_args_carry_runtime_paths_outside_repo() {
        let args = sample_config().server_args();
        assert!(
            args.windows(2)
                .any(|pair| pair == ["--save-file", "/tmp/world.json"])
        );
        assert!(args.windows(2).any(|pair| pair == ["--mods", "/tmp/mods"]));
        assert!(args.windows(2).any(|pair| pair == ["--autosave", "30"]));
    }

    #[test]
    fn managed_server_requires_existing_jar() {
        let mut config = sample_config();
        config.manage_server = true;
        assert!(config.validate().unwrap_err().contains("服务端 JAR 不存在"));
    }

    #[test]
    fn config_round_trips_through_json() {
        let config = sample_config();
        let raw = serde_json::to_string(&config).unwrap();
        assert_eq!(
            serde_json::from_str::<LauncherConfig>(&raw).unwrap(),
            config
        );
    }
}
