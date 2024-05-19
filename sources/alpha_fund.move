/// Module: alpha_dao
module alpha_dao::alpha_fund {
    use sui::balance::{Self, Balance};
    use sui::coin::Coin;
    use sui::sui::SUI;
    use sui::vec_map::{Self, VecMap};

    /// Error code for unauthorized access.
    const ENotManagerOfThisFund: u64 = 0;

    const ENotEoughCapitalAllocation: u64 = 1;

    const ENotOpenToInvestors: u64 = 2;

    const ENotTrading: u64 = 3;

    const EStilHasBalance: u64 = 4;

    // fund states
    const STATE_OPEN_TO_INVESTORS: u8 = 0;
    const STATE_TRADING: u8 = 1; 
    const STATE_CLOSED: u8 = 1; 

    const BASIS_POINTS_100_PERCENT: u16 = 10_000;
    
    public struct Fund has key, store {
        id: UID,
        balance: Balance<SUI>,
        /// performance fee in basis points
        /// e.g. 10_000 = 100%, 300 = 3%
        performance_fee: u16,
        state: u8,
        trader_to_allocation: VecMap<address, u64>,
        investor_to_deposit: VecMap<address, u64>,
        total_deposits: u64,
        closing_profits: Option<ClosingProfits>
    }

    public struct ClosingProfits has store, drop {
        closing_balance: u64,
        performance_fees: u64,
        balance_minus_fees: u64
    }

    /// The capability granting the fund manager the rights to:
    /// start trading, allocate capital, close fund
    public struct FundManagerCap has key, store { 
        id: UID,
        fund_id: ID
    }

    /// Create a new fund.
    public fun new(fee_percentage: u16, ctx: &mut TxContext): FundManagerCap {     
        let mut trader_to_allocation: VecMap<address, u64> = vec_map::empty();
        // set managers initial allocation to zero
        // this also guarantees that the manager is at index 0 of VecMap
        trader_to_allocation.insert(ctx.sender(), 0);

        let fund = Fund {
            id: object::new(ctx),
            performance_fee: fee_percentage,
            balance: balance::zero<SUI>(),
            state: STATE_OPEN_TO_INVESTORS,
            trader_to_allocation: trader_to_allocation,
            investor_to_deposit: vec_map::empty(),      
            total_deposits: 0,
            closing_profits: option::none()
        };

        let fund_manager_cap = FundManagerCap {
            id: object::new(ctx),
            fund_id: fund.id.to_inner()
        };

        transfer::share_object(fund);

        fund_manager_cap
    }

    #[test_only]
    public fun new_for_testing(fee_percentage: u16, ctx: &mut TxContext): (Fund, FundManagerCap) {
        let mut trader_to_allocation: VecMap<address, u64> = vec_map::empty();
        // set managers initial allocation to zero
        // this also guarantees that the manager is at index 0 of VecMap
        trader_to_allocation.insert(ctx.sender(), 0);

        let fund = Fund {
            id: object::new(ctx),
            performance_fee: fee_percentage,
            balance: balance::zero<SUI>(),
            state: STATE_OPEN_TO_INVESTORS,
            trader_to_allocation: trader_to_allocation,
            investor_to_deposit: vec_map::empty(),       
            total_deposits: 0,
            closing_profits: option::none()
        };

        let fund_manager_cap = FundManagerCap {
            id: object::new(ctx),
            fund_id: fund.id.to_inner()
        };

        (fund, fund_manager_cap)
    }

    public fun invest(fund: &mut Fund, investment: Coin<SUI>, ctx: &TxContext) {
        assert!(fund.state == STATE_OPEN_TO_INVESTORS, ENotOpenToInvestors);

        let investment_balance = investment.into_balance();  
        let sender = &ctx.sender();
       
        if (fund.investor_to_deposit.contains(sender)) {
            let invested = fund.investor_to_deposit.get_mut(sender);
            *invested = *invested + investment_balance.value();
        }else{
            fund.investor_to_deposit.insert(*sender, investment_balance.value());
        };

        // initially allocate deposit to manager to who allocate to traders
        let (_key, manager_alloc) = fund.trader_to_allocation.get_entry_by_idx_mut(0);
        *manager_alloc = *manager_alloc + investment_balance.value();

        fund.total_deposits = fund.total_deposits + investment_balance.value();

        fund.balance.join(investment_balance);
    }

    public fun get_profit(fund: &Fund): u64 {
        if (fund.balance.value() <= fund.total_deposits){
            0
        }else{
            fund.balance.value() - fund.total_deposits
        }
    }

    public fun allocate_to_trader(fund: &mut Fund, manager_cap: &FundManagerCap, trader: address, amt: u64) {
        assert!(fund.state == STATE_OPEN_TO_INVESTORS, ENotOpenToInvestors);
        assert!(fund.id.to_inner() == manager_cap.fund_id, ENotManagerOfThisFund);
        
        let (_key, manager_alloc) = fund.trader_to_allocation.get_entry_by_idx_mut(0);
        assert!(*manager_alloc >= amt, ENotEoughCapitalAllocation);
        *manager_alloc = *manager_alloc - amt;

             
        if (fund.trader_to_allocation.contains(&trader)) {
            let allocation = fund.trader_to_allocation.get_mut(&trader);
            *allocation = *allocation + amt;
        } else {
            fund.trader_to_allocation.insert(trader, amt);
        }
    }

    public fun start_trading(fund: &mut Fund, manager_cap: &FundManagerCap) {
        assert!(fund.id.to_inner() == manager_cap.fund_id, ENotManagerOfThisFund);
        fund.state = STATE_TRADING;
    }

    public fun close_fund(fund: &mut Fund, manager_cap: &FundManagerCap) {    
        assert!(fund.state == STATE_TRADING, ENotTrading);
        assert!(fund.id.to_inner() == manager_cap.fund_id, ENotManagerOfThisFund);

        let profit = fund.get_profit();
        let performance_fee = 
            if (profit > 0) {
                (profit * (fund.performance_fee as u64)) / (BASIS_POINTS_100_PERCENT as u64)
            } else {
                0
            };        

        fund.closing_profits = option::some(ClosingProfits {
            closing_balance: fund.balance.value(),
            performance_fees: performance_fee,
            balance_minus_fees: fund.balance.value() - performance_fee
        });

        fund.state = STATE_CLOSED;
    }

    public fun collect_fee(fund: Fund, manager_cap: FundManagerCap) {        
        let FundManagerCap {id: manager_cap_id, fund_id: manager_cap_fund_id} = manager_cap;
    
        let Fund {
                id: id,
                performance_fee: performance_fee,
                balance: balance,
                state: _state,
                trader_to_allocation: trader_to_allocation,
                investor_to_deposit: investor_to_deposit,
                total_deposits: total_deposits,
                closing_profits: _closing_profits
            } = fund;

        assert!(id.to_inner() == manager_cap_fund_id, ENotManagerOfThisFund);
        assert!(alance.value() == 0, EStilHasBalance);

        // check if there have been any profits
        if (balance.value() > total_deposits) {
            // calculate performance fee amount
            let profit = balance.value() - total_deposits;
            let total_performance_fee = (profit * (performance_fee as u64)) / (BASIS_POINTS_100_PERCENT as u64);

            // transfer performance fee to traders based on allocation
            let (mut traders, mut allocations) = trader_to_allocation.into_keys_values();          
            while (traders.length() > 0) {
                let trader = traders.pop_back();
                let allocation = allocations.pop_back();

                let allocation_percent = (allocation * total_deposits) / (BASIS_POINTS_100_PERCENT as u64);
                if (allocation_percent > 0){
                    let performance_fee = (total_performance_fee * allocation_percent) / (BASIS_POINTS_100_PERCENT as u64);
                    let 
                }
            };

            traders.destroy_empty();
            allocations.destroy_empty();          
        };
        
        manager_cap_id.delete();   
        id.delete();        
    }

    public fun delete(fund: Fund, manager_cap: FundManagerCap) {
        let FundManagerCap {id: manager_cap_id, fund_id: manager_cap_fund_id} = manager_cap;
    
        let Fund {
                id: id,
                performance_fee: _performance_fee,
                balance: balance,
                state: _state,
                trader_to_allocation: _trader_to_allocation,
                investor_to_deposit: _investor_to_deposit,
                total_deposits: _total_deposits,
                closing_profits: _closing_profits
            } = fund;

        assert!(id.to_inner() == manager_cap_fund_id, ENotManagerOfThisFund);
        assert!(balance.value() == 0, EStilHasBalance);        
        
        balance.destroy_zero();
        manager_cap_id.delete();   
        id.delete();      
    }


    public fun get_state(fund: &Fund): u8 {
        fund.state
    }

    public fun get_total_deposits(fund: &Fund): u64 {
        fund.total_deposits
    }

    public fun get_balance(fund: &Fund): u64 {
        fund.balance.value()
    }

    public fun get_manager(fund: &Fund): address {
        let (key, _value) = fund.trader_to_allocation.get_entry_by_idx(0);
        *key
    }

    public fun get_investor_despoit(fund: &Fund, investor: address): Option<u64> {
        fund.investor_to_deposit.try_get(&investor)       
    }

     public fun get_trader_allocation(fund: &Fund, trader: address): Option<u64> {
        fund.trader_to_allocation.try_get(&trader)       
    }



}
