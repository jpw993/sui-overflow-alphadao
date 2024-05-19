/// Module: alpha_dao
module alpha_dao::alpha_fund {
    use sui::balance::{Self, Balance};
    use sui::coin::Coin;
    use sui::sui::SUI;
    use sui::vec_map::{Self, VecMap};

    /// Error code for unauthorized access.
    const ENotManagerOfThisFund: u64 = 0;

    const ENotEoughCapitalAllocation: u64 = 1;

    // fund states
    const STATE_OPEN_TO_INVESTORS: u8 = 0;
    const STATE_TRADING: u8 = 1;
    const STATE_CLOSED: u8 = 2;
    
    public struct Fund has key, store {
        id: UID,
        balance: Balance<SUI>,
        // performance fee in basis points
        performance_fee: u16,
        state: u8,
        trader_to_allocation: VecMap<address, u64>,
        investor_to_deposit: VecMap<address, u64>,
        total_deposits: u64
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
            total_deposits: 0      
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
            total_deposits: 0       
        };

        let fund_manager_cap = FundManagerCap {
            id: object::new(ctx),
            fund_id: fund.id.to_inner()
        };

        (fund, fund_manager_cap)
    }

    public fun invest(fund: &mut Fund, investment: Coin<SUI>, ctx: &TxContext) {
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

    public fun allocate_to_trader(fund: &mut Fund, manager_cap: &FundManagerCap, trader: address, amt: u64){
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

    public fun get_total_deposits(fund: &Fund): u64 {
        fund.total_deposits
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
