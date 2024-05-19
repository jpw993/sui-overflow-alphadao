#[test_only]
module alpha_dao::alpha_fund_tests {
    use alpha_dao::alpha_fund::{Self, Fund};
    use sui::test_utils;
    use sui::test_scenario;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};

    const MANAGER: address = @0x1;
    const INVESTOR_1: address = @0x2;
    const INVESTOR_2: address = @0x3;
    const INVESTOR_3: address = @0x4;
    const TRADER_1: address = @0x5;
    const TRADER_2: address = @0x6;
    const TRADER_3: address = @0x7;

    #[test]
    fun test_alpha_fund() {
        let mut scenario = test_scenario::begin(MANAGER);        
        let manager_ctx = scenario.ctx();        
        let fee: u16 = 300;
        // create fund
        let (mut fund, manager_cap) = alpha_fund::new_for_testing(fee, manager_ctx);

        assert!(fund.get_manager() == manager_ctx.sender(), 0);
        assert!(fund.get_trader_allocation(fund.get_manager()).extract() == 0, 0);

        // take investment deposit from INVESTOR_1
        scenario.next_tx(INVESTOR_1);
        let investor_1_ctx = scenario.ctx();
        let coin = coin::mint_for_testing<SUI>(10_000, investor_1_ctx);
        fund.invest(coin, investor_1_ctx);
        assert!(fund.get_investor_despoit(INVESTOR_1).extract() == 10_000, 0);
        assert!(fund.get_trader_allocation(fund.get_manager()).extract() == 10_000, 0);

        // take investment deposit from INVESTOR_1
        scenario.next_tx(INVESTOR_2);
        let investor_2_ctx = scenario.ctx();
        let coin = coin::mint_for_testing<SUI>(5_000, investor_2_ctx);
        fund.invest(coin, investor_2_ctx);
        assert!(fund.get_investor_despoit(INVESTOR_2).extract() == 5_000, 0);
        assert!(fund.get_trader_allocation(fund.get_manager()).extract() == 15_000, 0);
        assert!(fund.get_total_deposits() == 15_000, 0);

        test_utils::destroy(fund);
        test_utils::destroy(manager_cap);  

        scenario.end();
    }
}
