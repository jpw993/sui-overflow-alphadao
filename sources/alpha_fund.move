/// Module: alpha_dao
module alpha_dao::alpha_fund {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::bag::{Self, Bag};
    use sui::math;
    use sui::clock::{Clock};

    use cetus_clmm::config::GlobalConfig;
    use cetus_clmm::pool::{Self, Pool};

    /// Error code for unauthorized access.
    const ENotManagerOfThisFund: u64 = 0;
    const ENotEoughCapitalAllocation: u64 = 1;
    const ENotOpenToInvestors: u64 = 2;
    const ENotTrading: u64 = 3;
    // const EStilHasBalance: u64 = 4;
    const ENotAllocationOfThisFund: u64 = 5;
    const ENotDepositOfThisFund: u64 = 6;
    const ENotClosed: u64 = 7;
    const ENotSuiAllocation: u64 = 8;

    // fund states
    const STATE_OPEN_TO_INVESTORS: u8 = 0;
    const STATE_TRADING: u8 = 1; 
    const STATE_CLOSED: u8 = 1; 

    const BASIS_POINTS_100_PERCENT: u16 = 10_000;
    
    public struct Fund has key, store {
        id: UID,
        balances: Bag,
        /// performance fee in basis points
        /// e.g. 10_000 = 100%, 300 = 3%
        performance_fee: u16,
        state: u8,
        total_deposits: u64,
        unallocated_capital: u64,
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

    public struct InvestorDeposit has key, store { 
        id: UID,
        fund_id: ID,
        amount: u64
    }

    public fun get_deposit_amount(investor_deposit: &InvestorDeposit): u64 {
        investor_deposit.amount
    }

    public struct TraderAllocation has key, store { 
        id: UID,
        fund_id: ID,
        coin_id: u64,       
        amount: u64
    }

    public fun get_coin_id(trader_allocation: &TraderAllocation): u64 {
        trader_allocation.coin_id
    }

    public fun get_allocation_amount(trader_allocation: &TraderAllocation): u64 {
        trader_allocation.amount
    }

    /// Create a new fund.
    public fun new(fee_percentage: u16, ctx: &mut TxContext): FundManagerCap {     
        let mut balances = bag::new(ctx);
        balances.add(0, balance::zero<SUI>());

        let fund = Fund {
            id: object::new(ctx),
            balances: balances,
            performance_fee: fee_percentage,       
            state: STATE_OPEN_TO_INVESTORS,      
            total_deposits: 0,
            unallocated_capital: 0,
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
          let mut balances = bag::new(ctx);
        balances.add(0, balance::zero<SUI>());

        let fund = Fund {
            id: object::new(ctx),
            balances: balances,
            performance_fee: fee_percentage,       
            state: STATE_OPEN_TO_INVESTORS,      
            total_deposits: 0,
            unallocated_capital: 0,
            closing_profits: option::none()
        };

        let fund_manager_cap = FundManagerCap {
            id: object::new(ctx),
            fund_id: fund.id.to_inner()
        };

        (fund, fund_manager_cap)
    }

    public fun invest(fund: &mut Fund, investment: Coin<SUI>, ctx: &mut TxContext): InvestorDeposit {
        assert!(fund.state == STATE_OPEN_TO_INVESTORS, ENotOpenToInvestors);

        let investment_balance = investment.into_balance();           

        let investor_deposit = InvestorDeposit {
            id: object::new(ctx),
            fund_id: fund.id.to_inner(),
            amount: investment_balance.value()
        };

        fund.total_deposits = fund.total_deposits + investment_balance.value();
        fund.unallocated_capital = fund.unallocated_capital + investment_balance.value();

        let fund_sui_balance: &mut Balance<SUI> = &mut fund.balances[0];
        fund_sui_balance.join(investment_balance);             
      
        investor_deposit
    }

    public fun get_profit(fund: &Fund): u64 {
        let fund_sui_balance: &Balance<SUI> = &fund.balances[0];
        if (fund_sui_balance.value() <= fund.total_deposits){
            0
        }else{
            fund_sui_balance.value() - fund.total_deposits
        }
    }

    public fun allocate_to_trader(fund: &mut Fund, manager_cap: &FundManagerCap, trader: address, amt: u64, ctx: &mut TxContext) {
        assert!(fund.state == STATE_OPEN_TO_INVESTORS, ENotOpenToInvestors);        
        assert!(fund.id.to_inner() == manager_cap.fund_id, ENotManagerOfThisFund);
                
        assert!(fund.unallocated_capital >= amt, ENotEoughCapitalAllocation);
        fund.unallocated_capital = fund.unallocated_capital - amt;             

        let trader_allocation = TraderAllocation {
             id: object::new(ctx),
            fund_id: fund.id.to_inner(),
            coin_id: 0,
            amount: amt
        };

        transfer::transfer(trader_allocation, trader);        
    }

    #[test_only]
    public fun allocate_to_trader_for_testing(fund: &mut Fund, manager_cap: &FundManagerCap, _trader: address, amt: u64, ctx: &mut TxContext): TraderAllocation {
        assert!(fund.state == STATE_OPEN_TO_INVESTORS, ENotOpenToInvestors);        
        assert!(fund.id.to_inner() == manager_cap.fund_id, ENotManagerOfThisFund);
                
        assert!(fund.unallocated_capital >= amt, ENotEoughCapitalAllocation);
        fund.unallocated_capital = fund.unallocated_capital - amt;             

        TraderAllocation {
            id: object::new(ctx),
            fund_id: fund.id.to_inner(),
            coin_id: 0,
            amount: amt
        }              
    }

    public fun start_trading(fund: &mut Fund, manager_cap: &FundManagerCap) {
        assert!(fund.id.to_inner() == manager_cap.fund_id, ENotManagerOfThisFund);
        fund.state = STATE_TRADING;
    }

    public fun receive(fund: &mut Fund, coin: Coin<SUI>){
        let fund_sui_balance: &mut Balance<SUI> = &mut fund.balances[0];
        fund_sui_balance.join(coin.into_balance());
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

        let fund_sui_balance: &Balance<SUI> = &fund.balances[0];        

        fund.closing_profits = option::some(ClosingProfits {
            closing_balance: fund_sui_balance.value(),
            performance_fees: performance_fee,
            balance_minus_fees: fund_sui_balance.value() - performance_fee
        });

        fund.state = STATE_CLOSED;
    }

    public fun collect_fee(fund: &mut Fund, trader_allocation: TraderAllocation, ctx: &mut TxContext): Coin<SUI> {    
        assert!(fund.state == STATE_CLOSED, ENotClosed);

        let TraderAllocation {id: id, fund_id: fund_id, coin_id: coin_id, amount: amount} = trader_allocation;   
        id.delete();  

        assert!(fund.id.to_inner() == fund_id, ENotAllocationOfThisFund);
        assert!(coin_id == 0, ENotSuiAllocation);

        let closing_profits = fund.closing_profits.borrow();

        assert!(closing_profits.performance_fees > 0, ENotSuiAllocation);   
          
        let allocation_percent = (amount * fund.total_deposits) / (BASIS_POINTS_100_PERCENT as u64);
        assert!(allocation_percent > 0, ENotSuiAllocation);

        let collected_fee = (closing_profits.performance_fees * allocation_percent) / (BASIS_POINTS_100_PERCENT as u64);

        let fund_sui_balance: &mut Balance<SUI> = &mut fund.balances[0];
        let to_pay = math::min(collected_fee, fund_sui_balance.value());
        fund_sui_balance.split(to_pay).into_coin(ctx)                 
    }

    public fun collect_investment(fund: &mut Fund, investor_deposit: InvestorDeposit, ctx: &mut TxContext): Coin<SUI> {    
        assert!(fund.state == STATE_CLOSED, ENotClosed);

        let InvestorDeposit {id: id, fund_id: fund_id, amount: amount} = investor_deposit;   
        id.delete();  

        assert!(fund.id.to_inner() == fund_id, ENotDepositOfThisFund);

        let closing_profits = fund.closing_profits.borrow();

        assert!(closing_profits.balance_minus_fees > 0, ENotSuiAllocation);   
          
        let percentage = (amount * (BASIS_POINTS_100_PERCENT as u64)) / fund.total_deposits;
        let fraction_to_pay = (closing_profits.balance_minus_fees * percentage) / (BASIS_POINTS_100_PERCENT as u64);     
        
        let fund_sui_balance: &mut Balance<SUI> = &mut fund.balances[0];
        let to_pay = math::min(fraction_to_pay, fund_sui_balance.value());
        fund_sui_balance.split(to_pay).into_coin(ctx)                 
    }    


    public fun get_state(fund: &Fund): u8 {
        fund.state
    }

    public fun get_total_deposits(fund: &Fund): u64 {
        fund.total_deposits
    }

     public fun get_unallocated_capital(fund: &Fund): u64 {
        fund.unallocated_capital
    }

    public fun get_sui_balance(fund: &Fund): u64 {
        let fund_sui_balance: &Balance<SUI> = &fund.balances[0];
        fund_sui_balance.value()
    }

    // Swap
    fun centus_swap<CoinTypeA, CoinTypeB>(
        config: &GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        coin_a: &mut Coin<CoinTypeA>,
        coin_b: &mut Coin<CoinTypeB>,
        a2b: bool,
        by_amount_in: bool,
        amount: u64,
        _amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let (receive_a, receive_b, flash_receipt) = pool::flash_swap<CoinTypeA, CoinTypeB>(
            config,
            pool,
            a2b,
            by_amount_in,
            amount,
            sqrt_price_limit,
            clock
        );
        let (in_amount, _out_amount) = (
            pool::swap_pay_amount(&flash_receipt),
            if (a2b) balance::value(&receive_b) else balance::value(&receive_a)
        );

        // pay for flash swap
        let (pay_coin_a, pay_coin_b) = if (a2b) {
            (coin::into_balance(coin::split(coin_a, in_amount, ctx)), balance::zero<CoinTypeB>())
        } else {
            (balance::zero<CoinTypeA>(), coin::into_balance(coin::split(coin_b, in_amount, ctx)))
        };

        coin::join(coin_b, coin::from_balance(receive_b, ctx));
        coin::join(coin_a, coin::from_balance(receive_a, ctx));

        pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
            config,
            pool,
            pay_coin_a,
            pay_coin_b,
            flash_receipt
        );  
    }

    fun centus_swap_a2b<CoinTypeA, CoinTypeB>(
        config: &GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        coin_a: &mut Coin<CoinTypeA>,
        coin_b: &mut Coin<CoinTypeB>,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &Clock,
        ctx: &mut TxContext
    ) {        
        centus_swap(
            config,
            pool,
            coin_a,
            coin_b,
            true,
            by_amount_in,
            amount,
            amount_limit,
            sqrt_price_limit,
            clock,
            ctx
        );
    }

    fun centus_swap_b2a<CoinTypeA, CoinTypeB>(
        config: &GlobalConfig,
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        coin_a: &mut Coin<CoinTypeA>,
        coin_b: &mut Coin<CoinTypeB>,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        centus_swap(
            config,
            pool,
            coin_a,
            coin_b,
            false,
            by_amount_in,
            amount,
            amount_limit,
            sqrt_price_limit,
            clock,
            ctx
        );
    }

     public entry fun swap<CoinTypeA, CoinTypeB>(        
        fund: &mut Fund,
        config: &GlobalConfig,        
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        coin_a_key: u64,
        coin_b_key: u64,
        a_2_b: bool,  
        amount: u64,        
        sqrt_price_limit: u128,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        if (!fund.balances.contains(coin_a_key)){
            fund.balances.add(coin_a_key, balance::zero<CoinTypeA>());
        };
        let coin_a_bal: Balance<CoinTypeA> = fund.balances.remove(coin_a_key);
        let mut coin_a = coin::from_balance(coin_a_bal, ctx);

        if (!fund.balances.contains(coin_b_key)){
            fund.balances.add(coin_b_key, balance::zero<CoinTypeB>());
        };
        let coin_b_bal:  Balance<CoinTypeB> = fund.balances.remove(coin_b_key);
        let mut coin_b = coin::from_balance(coin_b_bal, ctx);

        if (a_2_b) {
            centus_swap_a2b(config, pool, &mut coin_a, &mut coin_b, true, amount, amount, sqrt_price_limit, clock, ctx);            
        }else{
            centus_swap_b2a(config, pool, &mut coin_a, &mut coin_b, true, amount, amount, sqrt_price_limit, clock, ctx);  
        };

        fund.balances.add(coin_a_key, coin_a.into_balance());
        fund.balances.add(coin_b_key, coin_b.into_balance());        
    }


}
