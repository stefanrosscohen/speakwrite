mod commands;
mod capture;
mod features;
mod integrations;
mod storage;
mod crypto;
mod state;

use state::AppState;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let app_state = AppState::new().expect("Failed to initialize app state");

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(app_state)
        .invoke_handler(tauri::generate_handler![
            commands::capture::record_keystroke_batch,
            commands::session::start_session,
            commands::session::end_session,
            commands::session::checkpoint_session,
            commands::query::get_proof_status,
            commands::document::save_document,
            commands::document::load_document,
            commands::document::list_documents,
            commands::publish::publish_to_notion,
            commands::publish::publish_to_substack,
            commands::publish::export_html,
            commands::publish::verify_content_binding,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
