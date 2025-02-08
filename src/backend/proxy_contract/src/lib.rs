#[ic_cdk::query]
fn cycles_left() -> u64 {
    ic_cdk::api::canister_balance()
}
