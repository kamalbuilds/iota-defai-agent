/*
    IOTA DeFiAI - Lending Pool Smart Contract
    
    This contract implements a lending pool for IOTA tokens and stable coins.
    It allows users to:
    - Deposit assets into the lending pool
    - Borrow assets with collateral
    - Repay loans with interest
    - Withdraw deposited assets with earned interest
    
    Key features:
    - Variable interest rates based on utilization
    - Collateralization requirements for safe borrowing
    - Liquidation mechanisms for undercollateralized positions
*/

module defi_ai::lending_pool {
    use std::signer;
    use std::error;
    use std::string::{Self, String};
    use std::vector;
    
    use iota::coin::{Self, Coin};
    
    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_POOL_ALREADY_EXISTS: u64 = 2;
    const E_POOL_NOT_FOUND: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    const E_INSUFFICIENT_COLLATERAL: u64 = 5;
    const E_INVALID_AMOUNT: u64 = 6;
    const E_INVALID_ASSET: u64 = 7;
    const E_BORROW_LIMIT_EXCEEDED: u64 = 8;
    const E_POSITION_NOT_FOUND: u64 = 9;
    
    // Pool configuration constants
    const MIN_COLLATERAL_RATIO: u64 = 150; // 150% minimum collateralization
    const LIQUIDATION_THRESHOLD: u64 = 125; // Liquidation at 125% collateralization
    const BASE_INTEREST_RATE: u64 = 2; // 2% base interest rate
    const OPTIMAL_UTILIZATION: u64 = 80; // 80% optimal utilization
    const SLOPE1: u64 = 4; // Interest rate slope below optimal utilization
    const SLOPE2: u64 = 75; // Interest rate slope above optimal utilization
    
    // Represents a lending pool for a specific asset
    struct LendingPool has key {
        admin: address,
        pool_id: String,
        asset_type: String,
        total_deposits: u64,
        total_borrows: u64,
        reserve: Coin,
        deposit_apy: u64, // APY in basis points (1/100 of a percent)
        borrow_apr: u64,  // APR in basis points
        collateral_ratio: u64, // Required collateral ratio in percentage
        created_at: u64,
        last_updated_at: u64
    }
    
    // Represents a user's deposit in a lending pool
    struct DepositPosition has key, store {
        pool_id: String,
        depositor: address,
        amount: u64,
        deposit_time: u64,
        last_interest_update: u64,
        accrued_interest: u64
    }
    
    // Represents a user's borrow position in a lending pool
    struct BorrowPosition has key, store {
        pool_id: String,
        borrower: address,
        amount: u64,
        collateral: Coin,
        collateral_amount: u64,
        collateral_asset_type: String,
        borrow_time: u64,
        last_interest_update: u64,
        accrued_interest: u64
    }
    
    // Creates a new lending pool
    public entry fun create_pool(
        admin: &signer,
        pool_id: String,
        asset_type: String,
        initial_deposit: Coin,
        collateral_ratio: u64,
        timestamp: u64
    ) {
        let admin_addr = signer::address_of(admin);
        
        // Ensure pool doesn't already exist
        assert!(!exists<LendingPool>(admin_addr), error::already_exists(E_POOL_ALREADY_EXISTS));
        
        // Ensure valid collateral ratio
        assert!(collateral_ratio >= MIN_COLLATERAL_RATIO, error::invalid_argument(E_INVALID_AMOUNT));
        
        // Ensure valid initial deposit
        let deposit_amount = coin::value(&initial_deposit);
        assert!(deposit_amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        
        // Calculate initial interest rates based on 0 utilization
        let deposit_apy = BASE_INTEREST_RATE; // At 0 utilization, deposit APY equals base rate
        let borrow_apr = BASE_INTEREST_RATE + SLOPE1; // At 0 utilization, borrow APR equals base rate + slope1
        
        // Create the lending pool
        let pool = LendingPool {
            admin: admin_addr,
            pool_id,
            asset_type,
            total_deposits: deposit_amount,
            total_borrows: 0,
            reserve: initial_deposit,
            deposit_apy,
            borrow_apr,
            collateral_ratio,
            created_at: timestamp,
            last_updated_at: timestamp
        };
        
        move_to(admin, pool);
    }
    
    // Deposits assets into a lending pool
    public entry fun deposit(
        depositor: &signer,
        pool_addr: address,
        amount: Coin,
        timestamp: u64
    ) acquires LendingPool, DepositPosition {
        let depositor_addr = signer::address_of(depositor);
        
        // Ensure lending pool exists
        assert!(exists<LendingPool>(pool_addr), error::not_found(E_POOL_NOT_FOUND));
        
        // Get deposit amount
        let deposit_amount = coin::value(&amount);
        assert!(deposit_amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        
        // Get lending pool
        let pool = borrow_global_mut<LendingPool>(pool_addr);
        
        // Verify asset type
        assert!(coin::asset_type(&amount) == pool.asset_type, error::invalid_argument(E_INVALID_ASSET));
        
        // Update pool state
        pool.total_deposits = pool.total_deposits + deposit_amount;
        coin::merge(&mut pool.reserve, amount);
        
        // Update interest rates
        update_interest_rates(pool);
        
        // Update timestamp
        pool.last_updated_at = timestamp;
        
        // Create or update deposit position
        if (exists<DepositPosition>(depositor_addr)) {
            // Update existing position
            let position = borrow_global_mut<DepositPosition>(depositor_addr);
            
            // Calculate accrued interest
            let time_elapsed = timestamp - position.last_interest_update;
            let interest = calculate_deposit_interest(position.amount, pool.deposit_apy, time_elapsed);
            
            // Update position
            position.amount = position.amount + deposit_amount;
            position.accrued_interest = position.accrued_interest + interest;
            position.last_interest_update = timestamp;
        } else {
            // Create new position
            let position = DepositPosition {
                pool_id: pool.pool_id,
                depositor: depositor_addr,
                amount: deposit_amount,
                deposit_time: timestamp,
                last_interest_update: timestamp,
                accrued_interest: 0
            };
            
            move_to(depositor, position);
        }
    }
    
    // Withdraw assets from a lending pool
    public entry fun withdraw(
        depositor: &signer,
        pool_addr: address,
        amount: u64,
        timestamp: u64
    ) acquires LendingPool, DepositPosition {
        let depositor_addr = signer::address_of(depositor);
        
        // Ensure lending pool exists and deposit position exists
        assert!(exists<LendingPool>(pool_addr), error::not_found(E_POOL_NOT_FOUND));
        assert!(exists<DepositPosition>(depositor_addr), error::not_found(E_POSITION_NOT_FOUND));
        
        // Get lending pool and deposit position
        let pool = borrow_global_mut<LendingPool>(pool_addr);
        let position = borrow_global_mut<DepositPosition>(depositor_addr);
        
        // Calculate accrued interest
        let time_elapsed = timestamp - position.last_interest_update;
        let interest = calculate_deposit_interest(position.amount, pool.deposit_apy, time_elapsed);
        position.accrued_interest = position.accrued_interest + interest;
        
        // Calculate total available amount (principal + interest)
        let total_available = position.amount + position.accrued_interest;
        
        // Ensure sufficient available amount
        assert!(amount <= total_available, error::invalid_argument(E_INSUFFICIENT_BALANCE));
        
        // Calculate available liquidity in the pool
        let available_liquidity = pool.total_deposits - pool.total_borrows;
        assert!(amount <= available_liquidity, error::invalid_argument(E_INSUFFICIENT_BALANCE));
        
        // Update position
        if (amount == total_available) {
            // Full withdrawal, remove position
            let DepositPosition {
                pool_id: _,
                depositor: _,
                amount: _,
                deposit_time: _,
                last_interest_update: _,
                accrued_interest: _
            } = move_from<DepositPosition>(depositor_addr);
        } else {
            // Partial withdrawal, update position
            if (amount <= position.accrued_interest) {
                // Withdraw only from accrued interest
                position.accrued_interest = position.accrued_interest - amount;
            } else {
                // Withdraw from principal and interest
                let interest_part = position.accrued_interest;
                let principal_part = amount - interest_part;
                
                position.amount = position.amount - principal_part;
                position.accrued_interest = 0;
            }
            
            position.last_interest_update = timestamp;
        }
        
        // Update pool state
        pool.total_deposits = pool.total_deposits - amount;
        
        // Extract coins from reserve
        let withdraw_coin = coin::extract(&mut pool.reserve, amount);
        
        // Transfer to user
        coin::deposit(depositor_addr, withdraw_coin);
        
        // Update interest rates
        update_interest_rates(pool);
        
        // Update timestamp
        pool.last_updated_at = timestamp;
    }
    
    // Borrow assets from a lending pool with collateral
    public entry fun borrow(
        borrower: &signer,
        pool_addr: address,
        borrow_amount: u64,
        collateral: Coin,
        timestamp: u64
    ) acquires LendingPool, BorrowPosition {
        let borrower_addr = signer::address_of(borrower);
        
        // Ensure lending pool exists
        assert!(exists<LendingPool>(pool_addr), error::not_found(E_POOL_NOT_FOUND));
        
        // Get lending pool
        let pool = borrow_global_mut<LendingPool>(pool_addr);
        
        // Ensure sufficient liquidity
        let available_liquidity = pool.total_deposits - pool.total_borrows;
        assert!(borrow_amount <= available_liquidity, error::invalid_argument(E_INSUFFICIENT_BALANCE));
        
        // Get collateral details
        let collateral_asset_type = coin::asset_type(&collateral);
        let collateral_amount = coin::value(&collateral);
        
        // Calculate collateral value and verify it meets requirements
        // For simplicity, we're using a 1:1 value between assets
        // In a real implementation, this would use price oracles
        let collateral_value = collateral_amount;
        let required_collateral = (borrow_amount * pool.collateral_ratio) / 100;
        
        assert!(collateral_value >= required_collateral, error::invalid_argument(E_INSUFFICIENT_COLLATERAL));
        
        // Update pool state
        pool.total_borrows = pool.total_borrows + borrow_amount;
        
        // Extract borrowed coins from reserve
        let borrowed_coin = coin::extract(&mut pool.reserve, borrow_amount);
        
        // Transfer to borrower
        coin::deposit(borrower_addr, borrowed_coin);
        
        // Create or update borrow position
        if (exists<BorrowPosition>(borrower_addr)) {
            // Update existing position
            let position = borrow_global_mut<BorrowPosition>(borrower_addr);
            
            // Calculate accrued interest
            let time_elapsed = timestamp - position.last_interest_update;
            let interest = calculate_borrow_interest(position.amount, pool.borrow_apr, time_elapsed);
            
            // Merge collateral
            coin::merge(&mut position.collateral, collateral);
            
            // Update position
            position.amount = position.amount + borrow_amount;
            position.collateral_amount = position.collateral_amount + collateral_amount;
            position.accrued_interest = position.accrued_interest + interest;
            position.last_interest_update = timestamp;
        } else {
            // Create new position
            let position = BorrowPosition {
                pool_id: pool.pool_id,
                borrower: borrower_addr,
                amount: borrow_amount,
                collateral,
                collateral_amount,
                collateral_asset_type,
                borrow_time: timestamp,
                last_interest_update: timestamp,
                accrued_interest: 0
            };
            
            move_to(borrower, position);
        }
        
        // Update interest rates
        update_interest_rates(pool);
        
        // Update timestamp
        pool.last_updated_at = timestamp;
    }
    
    // Repay borrowed assets with interest
    public entry fun repay(
        borrower: &signer,
        pool_addr: address,
        repay_coin: Coin,
        timestamp: u64
    ) acquires LendingPool, BorrowPosition {
        let borrower_addr = signer::address_of(borrower);
        
        // Ensure lending pool exists and borrow position exists
        assert!(exists<LendingPool>(pool_addr), error::not_found(E_POOL_NOT_FOUND));
        assert!(exists<BorrowPosition>(borrower_addr), error::not_found(E_POSITION_NOT_FOUND));
        
        // Get lending pool and borrow position
        let pool = borrow_global_mut<LendingPool>(pool_addr);
        let position = borrow_global_mut<BorrowPosition>(borrower_addr);
        
        // Verify asset type
        assert!(coin::asset_type(&repay_coin) == pool.asset_type, error::invalid_argument(E_INVALID_ASSET));
        
        // Calculate accrued interest
        let time_elapsed = timestamp - position.last_interest_update;
        let interest = calculate_borrow_interest(position.amount, pool.borrow_apr, time_elapsed);
        position.accrued_interest = position.accrued_interest + interest;
        
        // Calculate total debt
        let total_debt = position.amount + position.accrued_interest;
        
        // Get repay amount
        let repay_amount = coin::value(&repay_coin);
        
        // Add repayment to pool reserve
        coin::merge(&mut pool.reserve, repay_coin);
        
        // Update position and pool state
        if (repay_amount >= total_debt) {
            // Full repayment
            pool.total_borrows = pool.total_borrows - position.amount;
            
            // Return collateral to borrower
            let collateral = coin::extract(&mut position.collateral, position.collateral_amount);
            coin::deposit(borrower_addr, collateral);
            
            // Remove position
            let BorrowPosition {
                pool_id: _,
                borrower: _,
                amount: _,
                collateral,
                collateral_amount: _,
                collateral_asset_type: _,
                borrow_time: _,
                last_interest_update: _,
                accrued_interest: _
            } = move_from<BorrowPosition>(borrower_addr);
            
            // Destroy empty collateral coin
            coin::destroy_zero(collateral);
        } else {
            // Partial repayment
            if (repay_amount <= position.accrued_interest) {
                // Repay only accrued interest
                position.accrued_interest = position.accrued_interest - repay_amount;
            } else {
                // Repay interest and principal
                let interest_part = position.accrued_interest;
                let principal_part = repay_amount - interest_part;
                
                position.amount = position.amount - principal_part;
                position.accrued_interest = 0;
                pool.total_borrows = pool.total_borrows - principal_part;
            }
            
            position.last_interest_update = timestamp;
        }
        
        // Update interest rates
        update_interest_rates(pool);
        
        // Update timestamp
        pool.last_updated_at = timestamp;
    }
    
    // Liquidate an undercollateralized position
    public entry fun liquidate(
        liquidator: &signer,
        borrower_addr: address,
        pool_addr: address,
        repay_coin: Coin,
        timestamp: u64
    ) acquires LendingPool, BorrowPosition {
        // Ensure lending pool exists and borrow position exists
        assert!(exists<LendingPool>(pool_addr), error::not_found(E_POOL_NOT_FOUND));
        assert!(exists<BorrowPosition>(borrower_addr), error::not_found(E_POSITION_NOT_FOUND));
        
        // Get lending pool and borrow position
        let pool = borrow_global_mut<LendingPool>(pool_addr);
        let position = borrow_global_mut<BorrowPosition>(borrower_addr);
        
        // Verify asset type
        assert!(coin::asset_type(&repay_coin) == pool.asset_type, error::invalid_argument(E_INVALID_ASSET));
        
        // Calculate accrued interest
        let time_elapsed = timestamp - position.last_interest_update;
        let interest = calculate_borrow_interest(position.amount, pool.borrow_apr, time_elapsed);
        position.accrued_interest = position.accrued_interest + interest;
        
        // Calculate total debt
        let total_debt = position.amount + position.accrued_interest;
        
        // Calculate current collateral ratio
        // For simplicity, we're using a 1:1 value between assets
        // In a real implementation, this would use price oracles
        let current_ratio = (position.collateral_amount * 100) / total_debt;
        
        // Check if position is eligible for liquidation
        assert!(current_ratio < LIQUIDATION_THRESHOLD, error::invalid_argument(E_NOT_AUTHORIZED));
        
        // Get repay amount
        let repay_amount = coin::value(&repay_coin);
        assert!(repay_amount > 0, error::invalid_argument(E_INVALID_AMOUNT));
        
        // Calculate max liquidation amount (50% of the debt)
        let max_liquidation = total_debt / 2;
        assert!(repay_amount <= max_liquidation, error::invalid_argument(E_INVALID_AMOUNT));
        
        // Calculate collateral to seize (with 10% bonus)
        let collateral_to_seize = (repay_amount * 110) / 100;
        assert!(collateral_to_seize <= position.collateral_amount, error::invalid_argument(E_INSUFFICIENT_COLLATERAL));
        
        // Add repayment to pool reserve
        coin::merge(&mut pool.reserve, repay_coin);
        
        // Update position and pool state
        if (repay_amount >= total_debt) {
            // Full repayment
            pool.total_borrows = pool.total_borrows - position.amount;
            
            // Return remaining collateral to borrower
            let remaining_collateral = position.collateral_amount - collateral_to_seize;
            if (remaining_collateral > 0) {
                let borrower_collateral = coin::extract(&mut position.collateral, remaining_collateral);
                coin::deposit(borrower_addr, borrower_collateral);
            }
            
            // Transfer seized collateral to liquidator
            let liquidator_addr = signer::address_of(liquidator);
            let liquidator_collateral = coin::extract(&mut position.collateral, collateral_to_seize);
            coin::deposit(liquidator_addr, liquidator_collateral);
            
            // Remove position
            let BorrowPosition {
                pool_id: _,
                borrower: _,
                amount: _,
                collateral,
                collateral_amount: _,
                collateral_asset_type: _,
                borrow_time: _,
                last_interest_update: _,
                accrued_interest: _
            } = move_from<BorrowPosition>(borrower_addr);
            
            // Destroy empty collateral coin
            coin::destroy_zero(collateral);
        } else {
            // Partial repayment
            if (repay_amount <= position.accrued_interest) {
                // Repay only accrued interest
                position.accrued_interest = position.accrued_interest - repay_amount;
            } else {
                // Repay interest and principal
                let interest_part = position.accrued_interest;
                let principal_part = repay_amount - interest_part;
                
                position.amount = position.amount - principal_part;
                position.accrued_interest = 0;
                pool.total_borrows = pool.total_borrows - principal_part;
            }
            
            // Extract seized collateral and transfer to liquidator
            let liquidator_addr = signer::address_of(liquidator);
            position.collateral_amount = position.collateral_amount - collateral_to_seize;
            let liquidator_collateral = coin::extract(&mut position.collateral, collateral_to_seize);
            coin::deposit(liquidator_addr, liquidator_collateral);
            
            position.last_interest_update = timestamp;
        }
        
        // Update interest rates
        update_interest_rates(pool);
        
        // Update timestamp
        pool.last_updated_at = timestamp;
    }
    
    // Calculate deposit interest based on APY and time elapsed
    fun calculate_deposit_interest(amount: u64, apy_bps: u64, time_elapsed_seconds: u64): u64 {
        // Convert APY from basis points to decimal (1 basis point = 0.0001)
        let apy_decimal = (apy_bps as u128) / 10000;
        
        // Convert seconds to years (approximate)
        let years = (time_elapsed_seconds as u128) / 31536000; // 60 * 60 * 24 * 365
        
        // Calculate interest: principal * apy * time
        let interest = ((amount as u128) * apy_decimal * years) / 100;
        
        (interest as u64)
    }
    
    // Calculate borrow interest based on APR and time elapsed
    fun calculate_borrow_interest(amount: u64, apr_bps: u64, time_elapsed_seconds: u64): u64 {
        // Convert APR from basis points to decimal (1 basis point = 0.0001)
        let apr_decimal = (apr_bps as u128) / 10000;
        
        // Convert seconds to years (approximate)
        let years = (time_elapsed_seconds as u128) / 31536000; // 60 * 60 * 24 * 365
        
        // Calculate interest: principal * apr * time
        let interest = ((amount as u128) * apr_decimal * years) / 100;
        
        (interest as u64)
    }
    
    // Update interest rates based on utilization
    fun update_interest_rates(pool: &mut LendingPool) {
        if (pool.total_deposits == 0) {
            // No deposits, set default rates
            pool.deposit_apy = BASE_INTEREST_RATE;
            pool.borrow_apr = BASE_INTEREST_RATE + SLOPE1;
            return
        }
        
        // Calculate utilization rate (0-100%)
        let utilization = (pool.total_borrows * 100) / pool.total_deposits;
        
        // Calculate borrow interest rate
        let borrow_rate = if (utilization <= OPTIMAL_UTILIZATION) {
            // Below optimal: base_rate + slope1 * utilization
            BASE_INTEREST_RATE + ((SLOPE1 * utilization) / OPTIMAL_UTILIZATION)
        } else {
            // Above optimal: base_rate + slope1 + slope2 * excess_utilization
            let excess_utilization = utilization - OPTIMAL_UTILIZATION;
            let max_excess = 100 - OPTIMAL_UTILIZATION;
            BASE_INTEREST_RATE + SLOPE1 + ((SLOPE2 * excess_utilization) / max_excess)
        };
        
        // Calculate deposit interest rate: borrow_rate * utilization * (1 - reserve_factor)
        // For simplicity, we're using a 10% reserve factor
        let deposit_rate = (borrow_rate * utilization * 90) / 10000;
        
        // Update rates
        pool.borrow_apr = borrow_rate;
        pool.deposit_apy = deposit_rate;
    }
    
    // Get lending pool info (public view function)
    public fun get_pool_info(pool_addr: address): (String, String, u64, u64, u64, u64, u64) acquires LendingPool {
        let pool = borrow_global<LendingPool>(pool_addr);
        
        // Calculate utilization rate
        let utilization = if (pool.total_deposits > 0) {
            (pool.total_borrows * 100) / pool.total_deposits
        } else {
            0
        };
        
        (
            pool.pool_id,
            pool.asset_type,
            pool.total_deposits,
            pool.total_borrows,
            utilization,
            pool.deposit_apy,
            pool.borrow_apr
        )
    }
    
    // Get user deposit position info (public view function)
    public fun get_deposit_info(depositor_addr: address): (String, u64, u64, u64) acquires DepositPosition {
        let position = borrow_global<DepositPosition>(depositor_addr);
        
        (
            position.pool_id,
            position.amount,
            position.accrued_interest,
            position.last_interest_update
        )
    }
    
    // Get user borrow position info (public view function)
    public fun get_borrow_info(borrower_addr: address): (String, u64, u64, String, u64, u64) acquires BorrowPosition {
        let position = borrow_global<BorrowPosition>(borrower_addr);
        
        (
            position.pool_id,
            position.amount,
            position.collateral_amount,
            position.collateral_asset_type,
            position.accrued_interest,
            position.last_interest_update
        )
    }
} 