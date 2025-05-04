import json
import os
from typing import Dict, List, Any, Optional

from agentpress.tool import Tool, ToolResult, openapi_schema, xml_schema

class IOTADeFiTool(Tool):
    """Tool for interacting with IOTA blockchain and DeFi smart contracts."""

    def __init__(self):
        super().__init__()
        self.iota_node_url = os.environ.get("IOTA_NODE_URL", "https://api.testnet.iota.cafe")
        self.iota_explorer_url = os.environ.get("IOTA_EXPLORER_URL", "https://explorer.rebased.iota.org/?network=testnet")
        
        # Mock data for development/demo purposes
        self.market_data = {
            "assets": [
                {"symbol": "IOTA", "price_usd": 0.1452, "change_24h": 2.34, "market_cap_usd": 403782401},
                {"symbol": "BTC", "price_usd": 63245.78, "change_24h": -1.23, "market_cap_usd": 1234567890123},
                {"symbol": "ETH", "price_usd": 3071.45, "change_24h": 0.87, "market_cap_usd": 369123456789}
            ],
            "lending_pools": [
                {
                    "id": "pool_1",
                    "name": "IOTA Stable Pool",
                    "total_deposits": 2500000,
                    "apy": 4.52,
                    "utilization_rate": 68.3,
                    "collateral_ratio": 150,
                    "assets": ["IOTA", "USDT", "USDC"]
                },
                {
                    "id": "pool_2",
                    "name": "IOTA High Yield",
                    "total_deposits": 1200000,
                    "apy": 8.76,
                    "utilization_rate": 82.1,
                    "collateral_ratio": 200,
                    "assets": ["IOTA", "BTC", "ETH"]
                }
            ],
            "risk_metrics": {
                "market_volatility": 0.42,  # 0-1 scale
                "liquidation_risk": 0.31,   # 0-1 scale
                "protocol_health": 0.89     # 0-1 scale
            }
        }
        
        # Mock user portfolios for demo
        self.user_portfolios = {
            "user_123": {
                "wallet_balance": {
                    "IOTA": 10000,
                    "USDT": 5000
                },
                "lending_positions": [
                    {
                        "pool_id": "pool_1",
                        "deposited": 4000,
                        "asset": "IOTA",
                        "apy": 4.52,
                        "deposit_date": "2023-10-15"
                    }
                ],
                "borrowing_positions": [
                    {
                        "pool_id": "pool_2",
                        "borrowed": 2000,
                        "asset": "USDT",
                        "apr": 5.67,
                        "borrow_date": "2023-11-01",
                        "collateral": {
                            "asset": "IOTA",
                            "amount": 6000,
                            "ratio": 175
                        }
                    }
                ]
            }
        }

    @openapi_schema({
        "type": "function",
        "function": {
            "name": "get_market_data",
            "description": "Get current market data for IOTA and other assets",
            "parameters": {
                "type": "object",
                "properties": {
                    "assets": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "List of asset symbols to get data for (e.g., ['IOTA', 'BTC']). If empty, returns data for all available assets."
                    }
                }
            }
        }
    })
    @xml_schema(
        tag_name="get-market-data",
        mappings=[
            {"param_name": "assets", "node_type": "content", "path": "assets"}
        ],
        example='''
        <!-- 
        The get-market-data tool retrieves current market data for IOTA and other assets.
        Use this tool to get latest prices, market cap, and 24h changes.
        -->
        
        <!-- Example to get market data for specific assets -->
        <get-market-data>
            <assets>["IOTA", "BTC"]</assets>
        </get-market-data>
        
        <!-- Example to get all available market data -->
        <get-market-data>
            <assets>[]</assets>
        </get-market-data>
        '''
    )
    async def get_market_data(
        self,
        assets: Optional[List[str]] = None
    ) -> ToolResult:
        """
        Get current market data for IOTA and other assets.
        
        Parameters:
        - assets: List of asset symbols to get data for. If empty, returns data for all available assets.
        """
        try:
            # Parse the assets parameter if it's a string
            if isinstance(assets, str):
                try:
                    assets = json.loads(assets)
                except json.JSONDecodeError:
                    return self.fail_response("Invalid JSON format for assets parameter.")
            
            # If assets is None or empty list, return all assets
            if not assets:
                return self.success_response(self.market_data["assets"])
            
            # Filter assets based on the provided symbols
            filtered_assets = [
                asset for asset in self.market_data["assets"]
                if asset["symbol"] in assets
            ]
            
            if not filtered_assets:
                return self.fail_response(f"No data found for assets: {assets}")
            
            return self.success_response(filtered_assets)
            
        except Exception as e:
            return self.fail_response(f"Error getting market data: {str(e)}")

    @openapi_schema({
        "type": "function",
        "function": {
            "name": "get_lending_pools",
            "description": "Get information about available lending pools",
            "parameters": {
                "type": "object",
                "properties": {
                    "min_apy": {
                        "type": "number",
                        "description": "Minimum APY to filter pools by"
                    },
                    "assets": {
                        "type": "array",
                        "items": {
                            "type": "string"
                        },
                        "description": "Filter pools that support these assets"
                    }
                }
            }
        }
    })
    @xml_schema(
        tag_name="get-lending-pools",
        mappings=[
            {"param_name": "min_apy", "node_type": "attribute", "path": "min_apy"},
            {"param_name": "assets", "node_type": "content", "path": "assets"}
        ],
        example='''
        <!-- 
        The get-lending-pools tool retrieves information about available lending pools.
        Use this tool to explore lending opportunities and their current rates.
        -->
        
        <!-- Example to get all lending pools with APY at least 5% -->
        <get-lending-pools min_apy="5">
            <assets>[]</assets>
        </get-lending-pools>
        
        <!-- Example to get lending pools that support IOTA -->
        <get-lending-pools>
            <assets>["IOTA"]</assets>
        </get-lending-pools>
        '''
    )
    async def get_lending_pools(
        self,
        min_apy: Optional[float] = None,
        assets: Optional[List[str]] = None
    ) -> ToolResult:
        """
        Get information about available lending pools.
        
        Parameters:
        - min_apy: Minimum APY to filter pools by
        - assets: Filter pools that support these assets
        """
        try:
            # Parse the assets parameter if it's a string
            if isinstance(assets, str):
                try:
                    assets = json.loads(assets)
                except json.JSONDecodeError:
                    return self.fail_response("Invalid JSON format for assets parameter.")
            
            # Get all pools
            pools = self.market_data["lending_pools"]
            
            # Apply min_apy filter if provided
            if min_apy is not None:
                pools = [pool for pool in pools if pool["apy"] >= float(min_apy)]
            
            # Apply assets filter if provided
            if assets:
                pools = [
                    pool for pool in pools 
                    if any(asset in pool["assets"] for asset in assets)
                ]
            
            if not pools:
                filters = []
                if min_apy is not None:
                    filters.append(f"min_apy={min_apy}")
                if assets:
                    filters.append(f"assets={assets}")
                filter_str = ", ".join(filters)
                return self.fail_response(f"No lending pools found with filters: {filter_str}")
            
            return self.success_response(pools)
            
        except Exception as e:
            return self.fail_response(f"Error getting lending pools: {str(e)}")

    @openapi_schema({
        "type": "function",
        "function": {
            "name": "get_risk_assessment",
            "description": "Get AI-powered risk assessment for the market or specific lending pools",
            "parameters": {
                "type": "object",
                "properties": {
                    "pool_id": {
                        "type": "string",
                        "description": "ID of the lending pool to get risk assessment for"
                    }
                }
            }
        }
    })
    @xml_schema(
        tag_name="get-risk-assessment",
        mappings=[
            {"param_name": "pool_id", "node_type": "attribute", "path": "pool_id"}
        ],
        example='''
        <!-- 
        The get-risk-assessment tool provides AI-powered risk evaluation.
        Use this tool to get insights about market risks or specific pool risks.
        -->
        
        <!-- Example to get overall market risk assessment -->
        <get-risk-assessment>
        </get-risk-assessment>
        
        <!-- Example to get risk assessment for a specific pool -->
        <get-risk-assessment pool_id="pool_1">
        </get-risk-assessment>
        '''
    )
    async def get_risk_assessment(
        self,
        pool_id: Optional[str] = None
    ) -> ToolResult:
        """
        Get AI-powered risk assessment for the market or specific lending pools.
        
        Parameters:
        - pool_id: ID of the lending pool to get risk assessment for
        """
        try:
            # Get overall market risk assessment
            if not pool_id:
                risk_metrics = self.market_data["risk_metrics"]
                
                # Generate risk analysis text based on metrics
                market_risk = "low" if risk_metrics["market_volatility"] < 0.3 else "moderate" if risk_metrics["market_volatility"] < 0.7 else "high"
                liquidation_risk = "low" if risk_metrics["liquidation_risk"] < 0.3 else "moderate" if risk_metrics["liquidation_risk"] < 0.7 else "high"
                protocol_health = "excellent" if risk_metrics["protocol_health"] > 0.8 else "good" if risk_metrics["protocol_health"] > 0.5 else "concerning"
                
                analysis = {
                    "metrics": risk_metrics,
                    "assessment": f"The current market presents {market_risk} volatility with {liquidation_risk} liquidation risk. Overall protocol health is {protocol_health}.",
                    "recommendations": [
                        "Maintain appropriate collateralization ratios above 150%",
                        "Diversify lending positions across multiple pools",
                        "Consider hedging strategies in high volatility periods"
                    ]
                }
                
                return self.success_response(analysis)
            
            # Get risk assessment for specific pool
            pool = next((p for p in self.market_data["lending_pools"] if p["id"] == pool_id), None)
            if not pool:
                return self.fail_response(f"Lending pool with ID '{pool_id}' not found")
            
            # Generate pool-specific risk assessment
            utilization = pool["utilization_rate"]
            collateral = pool["collateral_ratio"]
            
            utilization_risk = "low" if utilization < 60 else "moderate" if utilization < 80 else "high"
            collateral_safety = "high" if collateral > 180 else "moderate" if collateral > 140 else "low"
            
            analysis = {
                "pool": pool,
                "assessment": f"Pool '{pool['name']}' has {utilization_risk} utilization risk and {collateral_safety} collateral safety.",
                "recommendations": [
                    f"{'Consider depositing more assets to earn higher yields' if utilization > 80 else 'This pool has capacity for more deposits'}",
                    f"{'Maintain higher collateral ratios due to high utilization' if utilization > 80 else 'Standard collateral ratios are likely sufficient'}"
                ]
            }
            
            return self.success_response(analysis)
            
        except Exception as e:
            return self.fail_response(f"Error getting risk assessment: {str(e)}")

    @openapi_schema({
        "type": "function",
        "function": {
            "name": "get_user_portfolio",
            "description": "Get a user's DeFi portfolio including wallet balances and positions",
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {
                        "type": "string",
                        "description": "User ID to get portfolio for"
                    }
                },
                "required": ["user_id"]
            }
        }
    })
    @xml_schema(
        tag_name="get-user-portfolio",
        mappings=[
            {"param_name": "user_id", "node_type": "attribute", "path": "user_id"}
        ],
        example='''
        <!-- 
        The get-user-portfolio tool retrieves a user's DeFi portfolio.
        Use this tool to see wallet balances, lending positions, and borrowing positions.
        -->
        
        <!-- Example to get a user's portfolio -->
        <get-user-portfolio user_id="user_123">
        </get-user-portfolio>
        '''
    )
    async def get_user_portfolio(
        self,
        user_id: str
    ) -> ToolResult:
        """
        Get a user's DeFi portfolio including wallet balances and positions.
        
        Parameters:
        - user_id: User ID to get portfolio for
        """
        try:
            if not user_id:
                return self.fail_response("User ID is required")
            
            # Get user portfolio data
            portfolio = self.user_portfolios.get(user_id)
            if not portfolio:
                return self.fail_response(f"No portfolio found for user ID: {user_id}")
            
            # Get current market prices
            asset_prices = {asset["symbol"]: asset["price_usd"] for asset in self.market_data["assets"]}
            
            # Calculate total portfolio value
            wallet_value = sum(
                amount * asset_prices.get(asset, 0)
                for asset, amount in portfolio["wallet_balance"].items()
            )
            
            lending_value = sum(
                position["deposited"] * asset_prices.get(position["asset"], 0)
                for position in portfolio["lending_positions"]
            )
            
            borrowing_value = sum(
                position["borrowed"] * asset_prices.get(position["asset"], 0)
                for position in portfolio["borrowing_positions"]
            )
            
            collateral_value = sum(
                position["collateral"]["amount"] * asset_prices.get(position["collateral"]["asset"], 0)
                for position in portfolio["borrowing_positions"]
                if "collateral" in position
            )
            
            # Add calculated metrics to portfolio
            portfolio_with_metrics = {
                **portfolio,
                "metrics": {
                    "total_wallet_value_usd": round(wallet_value, 2),
                    "total_lending_value_usd": round(lending_value, 2),
                    "total_borrowing_value_usd": round(borrowing_value, 2),
                    "total_collateral_value_usd": round(collateral_value, 2),
                    "net_position_usd": round(wallet_value + lending_value - borrowing_value, 2),
                    "health_factor": round(collateral_value / borrowing_value if borrowing_value > 0 else float('inf'), 2)
                }
            }
            
            return self.success_response(portfolio_with_metrics)
            
        except Exception as e:
            return self.fail_response(f"Error getting user portfolio: {str(e)}")

    @openapi_schema({
        "type": "function",
        "function": {
            "name": "get_ai_investment_recommendations",
            "description": "Get AI-powered investment recommendations based on market conditions and user profile",
            "parameters": {
                "type": "object",
                "properties": {
                    "user_id": {
                        "type": "string",
                        "description": "User ID to generate recommendations for"
                    },
                    "risk_tolerance": {
                        "type": "string",
                        "enum": ["conservative", "moderate", "aggressive"],
                        "description": "User's risk tolerance level"
                    },
                    "investment_horizon": {
                        "type": "string",
                        "enum": ["short", "medium", "long"],
                        "description": "User's investment time horizon"
                    }
                },
                "required": ["risk_tolerance", "investment_horizon"]
            }
        }
    })
    @xml_schema(
        tag_name="get-ai-investment-recommendations",
        mappings=[
            {"param_name": "user_id", "node_type": "attribute", "path": "user_id"},
            {"param_name": "risk_tolerance", "node_type": "attribute", "path": "risk_tolerance"},
            {"param_name": "investment_horizon", "node_type": "attribute", "path": "investment_horizon"}
        ],
        example='''
        <!-- 
        The get-ai-investment-recommendations tool provides personalized investment advice.
        Use this tool to get AI-powered recommendations tailored to a user's profile.
        -->
        
        <!-- Example to get investment recommendations for a specific user -->
        <get-ai-investment-recommendations user_id="user_123" risk_tolerance="moderate" investment_horizon="medium">
        </get-ai-investment-recommendations>
        
        <!-- Example to get general investment recommendations -->
        <get-ai-investment-recommendations risk_tolerance="conservative" investment_horizon="long">
        </get-ai-investment-recommendations>
        '''
    )
    async def get_ai_investment_recommendations(
        self,
        risk_tolerance: str,
        investment_horizon: str,
        user_id: Optional[str] = None
    ) -> ToolResult:
        """
        Get AI-powered investment recommendations based on market conditions and user profile.
        
        Parameters:
        - user_id: User ID to generate recommendations for (optional)
        - risk_tolerance: User's risk tolerance level
        - investment_horizon: User's investment time horizon
        """
        try:
            # Validate parameters
            valid_risk_levels = ["conservative", "moderate", "aggressive"]
            valid_horizons = ["short", "medium", "long"]
            
            if risk_tolerance not in valid_risk_levels:
                return self.fail_response(f"Invalid risk_tolerance. Must be one of: {', '.join(valid_risk_levels)}")
            
            if investment_horizon not in valid_horizons:
                return self.fail_response(f"Invalid investment_horizon. Must be one of: {', '.join(valid_horizons)}")
            
            # Get user portfolio if user_id is provided
            user_portfolio = None
            if user_id:
                user_portfolio = self.user_portfolios.get(user_id)
            
            # Get current market conditions
            market_metrics = self.market_data["risk_metrics"]
            market_volatility = market_metrics["market_volatility"]
            
            # Generate recommendations based on risk tolerance, investment horizon, and market conditions
            recommendations = {
                "asset_allocation": self._generate_asset_allocation(risk_tolerance, investment_horizon, market_volatility),
                "strategies": self._generate_strategies(risk_tolerance, investment_horizon, market_volatility),
                "specific_opportunities": self._generate_opportunities(risk_tolerance, investment_horizon)
            }
            
            # Add portfolio-specific recommendations if user_id is provided
            if user_portfolio:
                recommendations["portfolio_specific"] = {
                    "rebalancing": self._generate_rebalancing_advice(user_portfolio, risk_tolerance),
                    "risk_management": self._generate_risk_management_advice(user_portfolio, market_volatility)
                }
            
            return self.success_response(recommendations)
            
        except Exception as e:
            return self.fail_response(f"Error generating investment recommendations: {str(e)}")
    
    def _generate_asset_allocation(self, risk_tolerance, investment_horizon, market_volatility):
        """Generate asset allocation recommendations based on user profile and market conditions."""
        # Default allocations based on risk tolerance
        allocations = {
            "conservative": {"stablecoins": 60, "IOTA": 30, "other_crypto": 10},
            "moderate": {"stablecoins": 40, "IOTA": 40, "other_crypto": 20},
            "aggressive": {"stablecoins": 20, "IOTA": 50, "other_crypto": 30}
        }
        
        # Adjust for investment horizon
        horizon_adjustments = {
            "short": {"stablecoins": 10, "IOTA": -5, "other_crypto": -5},
            "medium": {"stablecoins": 0, "IOTA": 0, "other_crypto": 0},
            "long": {"stablecoins": -10, "IOTA": 5, "other_crypto": 5}
        }
        
        # Adjust for market volatility
        volatility_factor = market_volatility * 10  # Scale 0-1 to 0-10
        volatility_adjustments = {"stablecoins": volatility_factor, "IOTA": -volatility_factor/2, "other_crypto": -volatility_factor/2}
        
        # Calculate final allocation
        base_allocation = allocations[risk_tolerance]
        horizon_adjustment = horizon_adjustments[investment_horizon]
        
        final_allocation = {}
        for asset, percentage in base_allocation.items():
            adjusted = percentage + horizon_adjustment[asset] + volatility_adjustments[asset]
            # Ensure percentages are between 0-100
            final_allocation[asset] = max(0, min(100, round(adjusted)))
        
        # Normalize to 100%
        total = sum(final_allocation.values())
        if total != 100:
            scale_factor = 100 / total
            final_allocation = {asset: round(percentage * scale_factor) for asset, percentage in final_allocation.items()}
            # Adjust rounding errors
            diff = 100 - sum(final_allocation.values())
            if diff != 0:
                # Add/subtract the difference from the largest allocation
                largest_asset = max(final_allocation, key=final_allocation.get)
                final_allocation[largest_asset] += diff
        
        return final_allocation
    
    def _generate_strategies(self, risk_tolerance, investment_horizon, market_volatility):
        """Generate strategy recommendations based on user profile and market conditions."""
        strategies = []
        
        # Common strategies for all profiles
        strategies.append({
            "name": "Diversification",
            "description": "Spread investments across multiple assets to reduce risk"
        })
        
        # Risk-specific strategies
        if risk_tolerance == "conservative":
            strategies.append({
                "name": "Stable Yield Farming",
                "description": "Focus on stable assets and lower-risk lending pools with consistent returns"
            })
            if investment_horizon == "medium" or investment_horizon == "long":
                strategies.append({
                    "name": "Dollar-Cost Averaging",
                    "description": "Gradually invest in IOTA over time to reduce impact of volatility"
                })
                
        elif risk_tolerance == "moderate":
            strategies.append({
                "name": "Balanced Approach",
                "description": "Combine stable yields with some higher-risk positions for growth potential"
            })
            strategies.append({
                "name": "Strategic Rebalancing",
                "description": "Periodically adjust portfolio allocations to maintain desired risk level"
            })
                
        elif risk_tolerance == "aggressive":
            strategies.append({
                "name": "Growth Focus",
                "description": "Target higher yields through more volatile assets and lending opportunities"
            })
            if market_volatility < 0.7:  # Only recommend leverage in lower volatility
                strategies.append({
                    "name": "Strategic Leverage",
                    "description": "Use carefully managed leverage positions for amplified returns"
                })
        
        # Add market condition-specific strategies
        if market_volatility > 0.6:
            strategies.append({
                "name": "Volatility Hedging",
                "description": "Increase stablecoin allocation and use hedging strategies during high volatility"
            })
        
        return strategies
    
    def _generate_opportunities(self, risk_tolerance, investment_horizon):
        """Generate specific investment opportunities based on user profile."""
        opportunities = []
        
        # Map pools to risk levels
        pool_risk_levels = {
            "pool_1": "conservative",
            "pool_2": "aggressive"
        }
        
        # Filter pools based on risk tolerance
        suitable_pools = []
        for pool_id, risk_level in pool_risk_levels.items():
            if (risk_tolerance == "conservative" and risk_level == "conservative") or \
               (risk_tolerance == "moderate") or \
               (risk_tolerance == "aggressive"):
                pool = next(p for p in self.market_data["lending_pools"] if p["id"] == pool_id)
                suitable_pools.append(pool)
        
        # Generate opportunity recommendations
        for pool in suitable_pools:
            opportunities.append({
                "type": "lending",
                "name": f"{pool['name']} Deposit",
                "description": f"Deposit assets in {pool['name']} for {pool['apy']}% APY",
                "expected_return": f"{pool['apy']}%",
                "risk_level": "Low" if pool["id"] == "pool_1" else "Medium-High"
            })
        
        # Add other opportunities based on risk tolerance
        if risk_tolerance != "conservative":
            opportunities.append({
                "type": "staking",
                "name": "IOTA Staking",
                "description": "Stake IOTA tokens to earn rewards and support network security",
                "expected_return": "5-7%",
                "risk_level": "Medium"
            })
        
        if risk_tolerance == "aggressive" and investment_horizon != "short":
            opportunities.append({
                "type": "yield_farming",
                "name": "IOTA-BTC LP Farming",
                "description": "Provide liquidity to IOTA-BTC pair for trading fees and rewards",
                "expected_return": "12-15%",
                "risk_level": "High"
            })
        
        return opportunities
    
    def _generate_rebalancing_advice(self, portfolio, risk_tolerance):
        """Generate portfolio rebalancing advice based on current holdings."""
        # This would use the actual portfolio data to make recommendations
        # For this demo, we'll provide generic rebalancing advice
        
        advice = {
            "summary": "Your portfolio may benefit from rebalancing to better align with your risk profile.",
            "actions": []
        }
        
        # Example actions based on mock portfolio
        if "IOTA" in portfolio["wallet_balance"] and portfolio["wallet_balance"]["IOTA"] > 5000:
            if risk_tolerance == "conservative":
                advice["actions"].append({
                    "action": "Reduce IOTA exposure",
                    "description": "Consider converting 20% of your IOTA holdings to stablecoins to reduce volatility risk",
                    "reasoning": "Your current IOTA allocation exceeds the recommended amount for your risk profile"
                })
        
        if len(portfolio["lending_positions"]) < 2:
            advice["actions"].append({
                "action": "Diversify lending positions",
                "description": "Spread your deposits across multiple lending pools to reduce platform-specific risk",
                "reasoning": "Diversification can help protect against pool-specific issues or smart contract vulnerabilities"
            })
        
        return advice
    
    def _generate_risk_management_advice(self, portfolio, market_volatility):
        """Generate risk management advice based on user portfolio and market conditions."""
        advice = {
            "current_health": "Good" if market_volatility < 0.5 else "Requires Attention",
            "recommendations": []
        }
        
        # Check borrowing positions for health
        for position in portfolio["borrowing_positions"]:
            if "collateral" in position and position["collateral"]["ratio"] < 180:
                advice["recommendations"].append({
                    "priority": "High",
                    "action": "Increase collateral",
                    "description": f"Add more collateral to your {position['asset']} borrowing position to reduce liquidation risk",
                    "reasoning": "Current market volatility increases the risk of liquidation for positions with lower collateral ratios"
                })
        
        # General risk management recommendations
        if market_volatility > 0.4:
            advice["recommendations"].append({
                "priority": "Medium",
                "action": "Set up stop-loss strategies",
                "description": "Configure automated protection for your more volatile assets",
                "reasoning": "Current market conditions suggest increased volatility may continue"
            })
        
        # Add a general recommendation for all portfolios
        advice["recommendations"].append({
            "priority": "Low",
            "action": "Review lending pool utilization",
            "description": "Monitor the utilization rates of pools where you have deposits",
            "reasoning": "High utilization rates may indicate increased risk of liquidity issues"
        })
        
        return advice 