#[test_only]
module alpha_dao::alpha_fund_tests {
    use alpha_dao::alpha_fund::{Self, Fund};
    use sui::test_utils;

    #[test]
    fun test_alpha_fund() {
        // Arrange
        let ctx = &mut tx_context::dummy();
        let fee: u16 = 300;
        let (fund, manager_cap) = alpha_fund::new_for_testing(fee, ctx);

        assert!(fund.get_manager() == ctx.sender(), 0);


        test_utils::destroy(fund);
        test_utils::destroy(manager_cap);  
    }
}
