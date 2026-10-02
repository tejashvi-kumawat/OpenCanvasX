//! Native Rust entry points exposed to Flutter via [`flutter_rust_bridge`].
#![allow(unexpected_cfgs)]

/// Returns the native core version string (Phase 0 smoke test).
#[flutter_rust_bridge::frb(sync)]
pub fn ods_native_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn version_is_non_empty() {
        assert!(!ods_native_version().is_empty());
    }
}
