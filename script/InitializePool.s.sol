// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Currency} from "v4-core/types/Currency.sol";

// 鈹€鈹€鈹€ Constants 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
address constant POOL_MANAGER = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;

// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
//  InitializePool
//
//  Creates a Uniswap v4 pool registered to the RegretRebateHook.
//  This is a plain PoolManager.initialize() call 鈥?no unlock needed.
//
//  Env vars required:
//    DEPLOYER_PRIVATE_KEY  鈥?deployer wallet
//    X_LAYER_RPC_URL      鈥?X Layer RPC endpoint
//
//  Script args (set constants below before running):
//    HOOK_ADDRESS         鈥?RegretRebateHook deployed address (from DeployRegretRebateHook)
//    TOKEN0, TOKEN1       鈥?ERC20 token addresses  (TOKEN0 < TOKEN1 by address)
//    FEE_TIER             鈥?fee tier in bps, e.g. 3000 = 0.30%
//    SQRT_PRICE_X96       鈥?initial sqrt price (2^96 = 1:1), use TickMath.getSqrtPriceAtTick(0)
//
//  Example:
//    forge script script/InitializePool.s.sol:InitializePool
//        --rpc-url $X_LAYER_RPC_URL --broadcast -vv
//
//  Gas estimate only (no broadcast):
//    forge script script/InitializePool.s.sol:InitializePool
//        --rpc-url $X_LAYER_RPC_URL -vv
// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
contract InitializePool is Script {
    // 鈹€鈹€ Pool parameters 鈥?fill in before running 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
    address constant HOOK_ADDRESS = 0x0000000000000000000000000000000000000000; // Note: set
    address constant TOKEN0        = 0x0000000000000000000000000000000000000000; // Note: set
    address constant TOKEN1        = 0x0000000000000000000000000000000000000000; // Note: set
    uint24  constant FEE_TIER     = 3000;                                      // Note: set (e.g. 100=0.01%, 3000=0.30%, 10000=1.00%)
    int24   constant TICK_SPACING  = 60;                                        // Note: must match FEE_TIER
    uint160 constant SQRT_PRICE_X96 = 0x1000000000000000000000000;             // Note: 1:1 price = 2^96

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // 鈹€鈹€ Sort currencies (PoolManager enforces currency0 < currency1) 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        address c0 = TOKEN0;
        address c1 = TOKEN1;
        if (c0 > c1) (c0, c1) = (c1, c0);

        PoolKey memory key = PoolKey({
            currency0:    Currency.wrap(c0),
            currency1:    Currency.wrap(c1),
            fee:          FEE_TIER,
            tickSpacing:  TICK_SPACING,
            hooks:        IHooks(HOOK_ADDRESS)
        });

        console2.log("=== InitializePool on X Layer ===");
        console2.log("PoolManager:  ", POOL_MANAGER);
        console2.log("Hook:        ", HOOK_ADDRESS);
        console2.log("Token0:      ", c0);
        console2.log("Token1:      ", c1);
        console2.log("Fee:         ", FEE_TIER, "bps");
        console2.log("TickSpacing: ", TICK_SPACING);
        console2.log("sqrtPriceX96:", SQRT_PRICE_X96);
        console2.log("");

        vm.startBroadcast(deployerKey);
        int24 tick = IPoolManager(POOL_MANAGER).initialize(key, SQRT_PRICE_X96);
        vm.stopBroadcast();

        console2.log("Pool initialized! Tick:", tick);
        console2.log("");
        console2.log("=== NEXT ===");
        console2.log("1. Add liquidity with AddLiquidity.s.sol");
        console2.log("2. Or directly swap with ProtectedSwap.s.sol");
    }
}

