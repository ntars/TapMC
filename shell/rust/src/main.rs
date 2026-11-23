mod app;
mod config;
mod core_process;
mod protocol;
mod rpc;
mod session;

use app::TapMcApp;
use config::LauncherConfig;
use eframe::egui;

fn main() -> eframe::Result {
    if std::env::args().any(|arg| arg == "--smoke") {
        if let Err(error) = session::run_smoke() {
            eprintln!("[tapmc-shell] 冒烟失败：{error}");
            std::process::exit(1);
        }
        return Ok(());
    }

    let config = LauncherConfig::load();
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_title("TapMC Launcher")
            .with_inner_size([1180.0, 760.0])
            .with_min_inner_size([760.0, 560.0]),
        renderer: eframe::Renderer::Glow,
        ..Default::default()
    };

    eframe::run_native(
        "TapMC Launcher",
        options,
        Box::new(move |cc| Ok(Box::new(TapMcApp::new(cc, config)))),
    )
}
