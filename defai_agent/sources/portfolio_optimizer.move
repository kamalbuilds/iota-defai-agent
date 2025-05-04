/*
    IOTA DeFiAI - Portfolio Optimizer Smart Contract
    
    This contract implements AI-driven portfolio optimization strategies for IOTA tokens and other assets.
    It allows users to:
    - Create investment strategies based on risk profiles
    - Automatically rebalance portfolios based on market conditions
    - Execute trades according to AI recommendations
    
    Key features:
    - Risk-based portfolio allocation
    - Automatic rebalancing based on market conditions
    - Integration with lending pools for yield optimization
*/

module defi_ai::portfolio_optimizer {
    use std::signer;
    use std::error;
    use std::string::{Self, String};
    use std::vector;
    
    use iota::coin::{Self, Coin};
    use defi_ai::lending_pool;
    
    // Error codes
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_STRATEGY_ALREADY_EXISTS: u64 = 2;
    const E_STRATEGY_NOT_FOUND: u64 = 3;
    const E_INSUFFICIENT_BALANCE: u64 = 4;
    const E_INVALID_AMOUNT: u64 = 5;
    const E_INVALID_ASSET: u64 = 6;
    const E_INVALID_RISK_PROFILE: u64 = 7;
    
    // Risk profile constants
    const RISK_CONSERVATIVE: u8 = 1;
    const RISK_MODERATE: u8 = 2;
    const RISK_AGGRESSIVE: u8 = 3;
    
    // Strategy constants
    const MAX_ASSETS_PER_STRATEGY: u64 = 10;
    const MIN_REBALANCE_INTERVAL: u64 = 86400; // 1 day in seconds
    
    // Asset allocation for different risk profiles (in percentage)
    // Conservative: 60% stablecoins, 30% IOTA, 10% other crypto
    // Moderate: 40% stablecoins, 40% IOTA, 20% other crypto
    // Aggressive: 20% stablecoins, 50% IOTA, 30% other crypto
    
    // Represents an asset allocation in the portfolio
    struct AssetAllocation has store, drop, copy {
        asset_type: String,
        target_percentage: u64, // in basis points (1/100 of a percent)
        current_percentage: u64,
        amount: u64
    }
    
    // Represents a portfolio optimization strategy
    struct OptimizationStrategy has key {
        owner: address,
        strategy_id: String,
        risk_profile: u8,
        assets: vector<AssetAllocation>,
        total_value: u64,
        last_rebalanced: u64,
        rebalance_threshold: u64, // in basis points
        rebalance_interval: u64, // in seconds
        auto_compound: bool,
        created_at: u64,
        last_updated_at: u64
    }
    
    // Creates a new portfolio optimization strategy
    public entry fun create_strategy(
        owner: &signer,
        strategy_id: String,
        risk_profile: u8,
        rebalance_threshold: u64,
        rebalance_interval: u64,
        auto_compound: bool,
        timestamp: u64
    ) {
        let owner_addr = signer::address_of(owner);
        
        // Ensure strategy doesn't already exist
        assert!(!exists<OptimizationStrategy>(owner_addr), error::already_exists(E_STRATEGY_ALREADY_EXISTS));
        
        // Validate risk profile
        assert!(
            risk_profile == RISK_CONSERVATIVE || 
            risk_profile == RISK_MODERATE || 
            risk_profile == RISK_AGGRESSIVE,
            error::invalid_argument(E_INVALID_RISK_PROFILE)
        );
        
        // Ensure valid rebalance interval
        assert!(rebalance_interval >= MIN_REBALANCE_INTERVAL, error::invalid_argument(E_INVALID_AMOUNT));
        
        // Create empty asset allocations vector
        let assets = vector::empty<AssetAllocation>();
        
        // Initialize asset allocations based on risk profile
        if (risk_profile == RISK_CONSERVATIVE) {
            vector::push_back(&mut assets, AssetAllocation {
                asset_type: string::utf8(b"USDT"),
                target_percentage: 6000, // 60%
                current_percentage: 0,
                amount: 0
            });
            vector::push_back(&mut assets, AssetAllocation {
                asset_type: string::utf8(b"IOTA"),
                target_percentage: 3000, // 30%
                current_percentage: 0,
                amount: 0
            });
            vector::push_back(&mut assets, AssetAllocation {
                asset_type: string::utf8(b"BTC"),
                target_percentage: 1000, // 10%
                current_percentage: 0,
                amount: 0
            });
        } else if (risk_profile == RISK_MODERATE) {
            vector::push_back(&mut assets, AssetAllocation {
                asset_type: string::utf8(b"USDT"),
                target_percentage: 4000, // 40%
                current_percentage: 0,
                amount: 0
            });
            vector::push_back(&mut assets, AssetAllocation {
                asset_type: string::utf8(b"IOTA"),
                target_percentage: 4000, // 40%
                current_percentage: 0,
                amount: 0
            });
            vector::push_back(&mut assets, AssetAllocation {
                asset_type: string::utf8(b"BTC"),
                target_percentage: 2000, // 20%
                current_percentage: 0,
                amount: 0
            });
        } else { // RISK_AGGRESSIVE
            vector::push_back(&mut assets, AssetAllocation {
                asset_type: string::utf8(b"USDT"),
                target_percentage: 2000, // 20%
                current_percentage: 0,
                amount: 0
            });
            vector::push_back(&mut assets, AssetAllocation {
                asset_type: string::utf8(b"IOTA"),
                target_percentage: 5000, // 50%
                current_percentage: 0,
                amount: 0
            });
            vector::push_back(&mut assets, AssetAllocation {
                asset_type: string::utf8(b"BTC"),
                target_percentage: 3000, // 30%
                current_percentage: 0,
                amount: 0
            });
        };
        
        // Create the optimization strategy
        let strategy = OptimizationStrategy {
            owner: owner_addr,
            strategy_id,
            risk_profile,
            assets,
            total_value: 0,
            last_rebalanced: timestamp,
            rebalance_threshold,
            rebalance_interval,
            auto_compound,
            created_at: timestamp,
            last_updated_at: timestamp
        };
        
        move_to(owner, strategy);
    }
    
    // Adds an asset to the portfolio
    public entry fun add_asset(
        owner: &signer,
        asset: Coin,
        timestamp: u64
    ) acquires OptimizationStrategy {
        let owner_addr = signer::address_of(owner);
        
        // Ensure strategy exists
        assert!(exists<OptimizationStrategy>(owner_addr), error::not_found(E_STRATEGY_NOT_FOUND));
        
        // Get asset details
        let asset_type = coin::asset_type(&asset);
        let asset_amount = coin::value(&asset);
        
        // Get strategy
        let strategy = borrow_global_mut<OptimizationStrategy>(owner_addr);
        
        // Find or add asset to the portfolio
        let assets_len = vector::length(&strategy.assets);
        let asset_index = find_asset_index(&strategy.assets, &asset_type);
        
        if (asset_index == assets_len) {
            // Asset not found, add it if there's room
            assert!(assets_len < MAX_ASSETS_PER_STRATEGY, error::invalid_state(E_INVALID_ASSET));
            
            // Add new asset with 0 target allocation
            // Note: In a real implementation, we would automatically adjust allocations
            vector::push_back(&mut strategy.assets, AssetAllocation {
                asset_type,
                target_percentage: 0, // Start with 0% target, will need to be adjusted
                current_percentage: 0,
                amount: asset_amount
            });
        } else {
            // Asset found, update amount
            let asset_allocation = vector::borrow_mut(&mut strategy.assets, asset_index);
            asset_allocation.amount = asset_allocation.amount + asset_amount;
        };
        
        // Update total value and recalculate percentages
        strategy.total_value = strategy.total_value + asset_amount;
        update_current_percentages(strategy);
        
        // For simplicity, we're just depositing the coin to the owner's address
        // In a real implementation, we would store coins in the contract or deposit into lending pools
        coin::deposit(owner_addr, asset);
        
        // Update timestamp
        strategy.last_updated_at = timestamp;
    }
    
    // Removes an asset from the portfolio
    public entry fun remove_asset(
        owner: &signer,
        asset_type: String,
        amount: u64,
        timestamp: u64
    ) acquires OptimizationStrategy {
        let owner_addr = signer::address_of(owner);
        
        // Ensure strategy exists
        assert!(exists<OptimizationStrategy>(owner_addr), error::not_found(E_STRATEGY_NOT_FOUND));
        
        // Get strategy
        let strategy = borrow_global_mut<OptimizationStrategy>(owner_addr);
        
        // Find asset in the portfolio
        let asset_index = find_asset_index(&strategy.assets, &asset_type);
        let assets_len = vector::length(&strategy.assets);
        
        assert!(asset_index < assets_len, error::invalid_argument(E_INVALID_ASSET));
        
        // Get asset allocation
        let asset_allocation = vector::borrow_mut(&mut strategy.assets, asset_index);
        
        // Ensure sufficient balance
        assert!(amount <= asset_allocation.amount, error::invalid_argument(E_INSUFFICIENT_BALANCE));
        
        // Update asset amount
        asset_allocation.amount = asset_allocation.amount - amount;
        
        // Update total value
        strategy.total_value = strategy.total_value - amount;
        
        // Remove asset if amount is zero
        if (asset_allocation.amount == 0) {
            let removed_allocation = vector::remove(&mut strategy.assets, asset_index);
            let AssetAllocation { asset_type: _, target_percentage: _, current_percentage: _, amount: _ } = removed_allocation;
        };
        
        // Recalculate percentages
        update_current_percentages(strategy);
        
        // In a real implementation, we would withdraw from lending pools or the contract's storage
        // Here, we're just performing the logic without actual coin operations
        
        // Update timestamp
        strategy.last_updated_at = timestamp;
    }
    
    // Updates asset allocation percentages
    public entry fun update_allocations(
        owner: &signer,
        asset_types: vector<String>,
        target_percentages: vector<u64>,
        timestamp: u64
    ) acquires OptimizationStrategy {
        let owner_addr = signer::address_of(owner);
        
        // Ensure strategy exists
        assert!(exists<OptimizationStrategy>(owner_addr), error::not_found(E_STRATEGY_NOT_FOUND));
        
        // Validate input vectors
        let asset_types_len = vector::length(&asset_types);
        let target_percentages_len = vector::length(&target_percentages);
        
        assert!(asset_types_len == target_percentages_len, error::invalid_argument(E_INVALID_AMOUNT));
        assert!(asset_types_len > 0, error::invalid_argument(E_INVALID_AMOUNT));
        
        // Get strategy
        let strategy = borrow_global_mut<OptimizationStrategy>(owner_addr);
        
        // Validate total percentage adds up to 100%
        let total_percentage = 0;
        let i = 0;
        while (i < target_percentages_len) {
            total_percentage = total_percentage + *vector::borrow(&target_percentages, i);
            i = i + 1;
        };
        assert!(total_percentage == 10000, error::invalid_argument(E_INVALID_AMOUNT)); // 100% = 10000 basis points
        
        // Update target percentages
        i = 0;
        while (i < asset_types_len) {
            let asset_type = vector::borrow(&asset_types, i);
            let target_percentage = *vector::borrow(&target_percentages, i);
            
            let asset_index = find_asset_index(&strategy.assets, asset_type);
            let strategy_assets_len = vector::length(&strategy.assets);
            
            if (asset_index < strategy_assets_len) {
                // Update existing asset
                let asset_allocation = vector::borrow_mut(&mut strategy.assets, asset_index);
                asset_allocation.target_percentage = target_percentage;
            } else {
                // Add new asset with 0 amount
                vector::push_back(&mut strategy.assets, AssetAllocation {
                    asset_type: *asset_type,
                    target_percentage,
                    current_percentage: 0,
                    amount: 0
                });
            };
            
            i = i + 1;
        };
        
        // Update current percentages
        update_current_percentages(strategy);
        
        // Update timestamp
        strategy.last_updated_at = timestamp;
    }
    
    // Rebalances the portfolio to match target allocations
    public entry fun rebalance(
        owner: &signer,
        timestamp: u64
    ) acquires OptimizationStrategy {
        let owner_addr = signer::address_of(owner);
        
        // Ensure strategy exists
        assert!(exists<OptimizationStrategy>(owner_addr), error::not_found(E_STRATEGY_NOT_FOUND));
        
        // Get strategy
        let strategy = borrow_global_mut<OptimizationStrategy>(owner_addr);
        
        // Check if rebalance is needed
        let time_since_last_rebalance = timestamp - strategy.last_rebalanced;
        assert!(time_since_last_rebalance >= strategy.rebalance_interval, error::invalid_state(E_NOT_AUTHORIZED));
        
        // Calculate deviation and check if it exceeds threshold
        let max_deviation = calculate_max_deviation(strategy);
        assert!(max_deviation >= strategy.rebalance_threshold, error::invalid_state(E_NOT_AUTHORIZED));
        
        // Perform rebalancing
        // This is a simplified implementation - in a real system, this would involve
        // trading assets or moving funds between lending pools
        
        // Calculate target amounts for each asset
        let i = 0;
        let assets_len = vector::length(&strategy.assets);
        
        while (i < assets_len) {
            let asset_allocation = vector::borrow_mut(&mut strategy.assets, i);
            let target_amount = (strategy.total_value * asset_allocation.target_percentage) / 10000;
            
            // In a real implementation, we would execute trades here
            // For this example, we're just updating the amounts as if trades occurred perfectly
            
            // Track the delta for debugging/events
            let delta = if (asset_allocation.amount > target_amount) {
                asset_allocation.amount - target_amount // Selling excess
            } else {
                target_amount - asset_allocation.amount // Buying more
            };
            
            // Update to target amount (simulating perfect trades)
            asset_allocation.amount = target_amount;
            
            i = i + 1;
        };
        
        // Update current percentages after rebalancing
        update_current_percentages(strategy);
        
        // Update last rebalanced timestamp
        strategy.last_rebalanced = timestamp;
        strategy.last_updated_at = timestamp;
    }
    
    // Checks if portfolio needs rebalancing and returns the maximum deviation
    public fun needs_rebalancing(owner_addr: address, timestamp: u64): (bool, u64) acquires OptimizationStrategy {
        // Ensure strategy exists
        assert!(exists<OptimizationStrategy>(owner_addr), error::not_found(E_STRATEGY_NOT_FOUND));
        
        // Get strategy
        let strategy = borrow_global<OptimizationStrategy>(owner_addr);
        
        // Check time interval
        let time_since_last_rebalance = timestamp - strategy.last_rebalanced;
        if (time_since_last_rebalance < strategy.rebalance_interval) {
            return (false, 0)
        };
        
        // Calculate maximum deviation
        let max_deviation = calculate_max_deviation(strategy);
        
        // Check if deviation exceeds threshold
        (max_deviation >= strategy.rebalance_threshold, max_deviation)
    }
    
    // Helper function to find asset index in the strategy assets vector
    fun find_asset_index(assets: &vector<AssetAllocation>, asset_type: &String): u64 {
        let i = 0;
        let len = vector::length(assets);
        
        while (i < len) {
            let allocation = vector::borrow(assets, i);
            if (&allocation.asset_type == asset_type) {
                return i
            };
            i = i + 1;
        };
        
        len // Return length if not found
    }
    
    // Helper function to update current percentages
    fun update_current_percentages(strategy: &mut OptimizationStrategy) {
        let i = 0;
        let len = vector::length(&strategy.assets);
        
        // If total value is zero, set all current percentages to zero
        if (strategy.total_value == 0) {
            while (i < len) {
                let allocation = vector::borrow_mut(&mut strategy.assets, i);
                allocation.current_percentage = 0;
                i = i + 1;
            };
            return
        };
        
        // Calculate current percentages
        while (i < len) {
            let allocation = vector::borrow_mut(&mut strategy.assets, i);
            allocation.current_percentage = (allocation.amount * 10000) / strategy.total_value;
            i = i + 1;
        };
    }
    
    // Helper function to calculate maximum deviation from target
    fun calculate_max_deviation(strategy: &OptimizationStrategy): u64 {
        let i = 0;
        let len = vector::length(&strategy.assets);
        let max_deviation = 0;
        
        while (i < len) {
            let allocation = vector::borrow(&strategy.assets, i);
            let deviation = if (allocation.current_percentage > allocation.target_percentage) {
                allocation.current_percentage - allocation.target_percentage
            } else {
                allocation.target_percentage - allocation.current_percentage
            };
            
            if (deviation > max_deviation) {
                max_deviation = deviation;
            };
            
            i = i + 1;
        };
        
        max_deviation
    }
    
    // Get strategy info (public view function)
    public fun get_strategy_info(owner_addr: address): (String, u8, u64, u64, u64, bool) acquires OptimizationStrategy {
        // Ensure strategy exists
        assert!(exists<OptimizationStrategy>(owner_addr), error::not_found(E_STRATEGY_NOT_FOUND));
        
        // Get strategy
        let strategy = borrow_global<OptimizationStrategy>(owner_addr);
        
        (
            strategy.strategy_id,
            strategy.risk_profile,
            strategy.total_value,
            strategy.last_rebalanced,
            strategy.rebalance_threshold,
            strategy.auto_compound
        )
    }
    
    // Get asset allocations (public view function)
    public fun get_asset_allocations(owner_addr: address): vector<AssetAllocation> acquires OptimizationStrategy {
        // Ensure strategy exists
        assert!(exists<OptimizationStrategy>(owner_addr), error::not_found(E_STRATEGY_NOT_FOUND));
        
        // Get strategy
        let strategy = borrow_global<OptimizationStrategy>(owner_addr);
        
        // Return a copy of the assets vector
        strategy.assets
    }
} 