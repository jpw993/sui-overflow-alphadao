#[test_only]
module alpha_dao::alpha_fund_tests {
    use alpha_dao::alpha_fund::{Self, Fund};
    use sui::test_utils;
    use sui::test_scenario;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use std::debug;

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

        // create fund with 10% performance fee 
        let manager_cap = alpha_fund::new(1_000, scenario.ctx());     

        // take investment deposit from INVESTOR_1
        scenario.next_tx(INVESTOR_1);
        {        
            let mut fund = scenario.take_shared<Fund>();
            let investor_1_ctx = scenario.ctx();         
            let coin = coin::mint_for_testing<SUI>(10_000, investor_1_ctx);
            let investor_1_desposit = fund.invest(coin, investor_1_ctx);
            assert!(investor_1_desposit.get_deposit_amount() == 10_000, 0);
            assert!(fund.get_total_deposits() == 10_000, 0);
            test_utils::destroy(investor_1_desposit);
            test_scenario::return_shared(fund);
        };        

        // take investment deposit from INVESTOR_1
        scenario.next_tx(INVESTOR_2);
        {
            let mut fund = scenario.take_shared<Fund>();  
            let investor_2_ctx = scenario.ctx();         
            let coin = coin::mint_for_testing<SUI>(5_000, investor_2_ctx);
            let investor_2_desposit = fund.invest(coin, investor_2_ctx);
            assert!(investor_2_desposit.get_deposit_amount() == 5_000, 0);
            assert!(fund.get_total_deposits() == 15_000, 0);
            test_utils::destroy(investor_2_desposit);
            test_scenario::return_shared(fund);
        };

        scenario.next_tx(MANAGER);
        let (trader_1_alloc, trader_2_alloc) = {
            let mut fund = scenario.take_shared<Fund>();  
            let manager_ctx = scenario.ctx();                   

            // allocate capital to TRADER_1
            let trader_1_alloc = fund.allocate_to_trader_for_testing(&manager_cap, TRADER_1, 1_000, manager_ctx);
            assert!(trader_1_alloc.get_allocation_amount() == 1_000, 0);
            assert!(fund.get_unallocated_capital() == 14_000, 0);           
            
            // allocate capital to TRADER_2
            let trader_2_alloc = fund.allocate_to_trader_for_testing(&manager_cap, TRADER_2, 6_000, manager_ctx);
            assert!(trader_2_alloc.get_allocation_amount()  == 6_000, 0);
            assert!(fund.get_unallocated_capital() == 8_000, 0);            

            test_scenario::return_shared(fund);
            (trader_1_alloc, trader_2_alloc) 
        };

        scenario.next_tx(MANAGER);
        {
            let mut fund = scenario.take_shared<Fund>(); 

            // start trading
            fund.start_trading(&manager_cap);

            // add trading profits
            let trading_profits = coin::mint_for_testing<SUI>(15_000, scenario.ctx());        
            fund.receive(trading_profits);

            // close trading
            fund.close_fund(&manager_cap);

            test_scenario::return_shared(fund);           
        };

        scenario.next_tx(TRADER_1);
        {            
            let mut fund = scenario.take_shared<Fund>(); 
            let fees = fund.collect_fee(trader_1_alloc, scenario.ctx());
            debug::print(&fees.value());
            assert!(fees.value() == 225, 0);            
            test_scenario::return_shared(fund);    
            test_utils::destroy(fees);       
        };

        scenario.next_tx(TRADER_2);
        {            
            let mut fund = scenario.take_shared<Fund>(); 
            let fees = fund.collect_fee(trader_2_alloc, scenario.ctx());
            debug::print(&fees.value());
            assert!(fees.value() == 1350, 0);            
            test_scenario::return_shared(fund);    
            test_utils::destroy(fees);       
        };


        scenario.next_tx(MANAGER);
        {           
            let fund = scenario.take_shared<Fund>();           
            test_utils::destroy(fund);          
        };
  
        test_utils::destroy(manager_cap); 
        scenario.end();
    }

}
