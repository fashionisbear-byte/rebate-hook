// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";

address constant POOL_MANAGER = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;

/// @notice Deploys the v4-core helper used to add liquidity through the real PoolManager unlock path.
contract DeployPoolModifyLiquidityTestHelper is Script {
    function run() external returns (PoolModifyLiquidityTest liquidityRouter) {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        console2.log("=== Deploy PoolModifyLiquidityTest Helper ===");
        console2.log("PoolManager:", POOL_MANAGER);

        vm.startBroadcast(deployerKey);
        liquidityRouter = new PoolModifyLiquidityTest(IPoolManager(POOL_MANAGER));
        vm.stopBroadcast();

        console2.log("PoolModifyLiquidityTest deployed:", address(liquidityRouter));
        console2.log("Approve both pool tokens to this helper before running AddLiquidity.");
    }
}

/// @notice Adds demo liquidity to the initialized RegretRebateHook pool.
///
/// Flow:
///   PoolModifyLiquidityTest.modifyLiquidity()
///     -> PoolManager.unlock()
///     -> PoolModifyLiquidityTest.unlockCallback()
///     -> PoolManager.modifyLiquidity()
///     -> token settle/take until all deltas are zero
///
/// This uses a v4-core test helper, not a production position manager. It is enough
/// for the hackathon demo because it exercises the genuine PoolManager liquidity path.
contract AddLiquidity is Script {
    // Fill these before running against X Layer.
    address constant HOOK_ADDRESS = 0x0000000000000000000000000000000000000000; // Note: set
    address constant MODIFY_LIQUIDITY_HELPER = 0x0000000000000000000000000000000000000000; // Note: set after deploying helper
    address constant TOKEN0 = 0x0000000000000000000000000000000000000000; // Note: set
    address constant TOKEN1 = 0x0000000000000000000000000000000000000000; // Note: set

    uint24 constant FEE = 3000;
    int24 constant TICK_SPACING = 60;

    // Wide demo range around the 1:1 initialization tick. Must be multiples of TICK_SPACING.
    int24 constant TICK_LOWER = -600;
    int24 constant TICK_UPPER = 600;
    int256 constant LIQUIDITY_DELTA = 1e18;
    bytes32 constant POSITION_SALT = bytes32(0);

    function run() external returns (PoolModifyLiquidityTest liquidityRouter) {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        if (MODIFY_LIQUIDITY_HELPER == address(0)) {
            console2.log("=== Deploy helper only ===");
            console2.log("MODIFY_LIQUIDITY_HELPER is zero, so this run only deploys the helper.");
            console2.log("After deployment:");
            console2.log("1. Approve TOKEN0 and TOKEN1 to the helper address.");
            console2.log("2. Set MODIFY_LIQUIDITY_HELPER in this script.");
            console2.log("3. Re-run AddLiquidity to add liquidity.");

            vm.startBroadcast(deployerKey);
            liquidityRouter = new PoolModifyLiquidityTest(IPoolManager(POOL_MANAGER));
            vm.stopBroadcast();

            console2.log("PoolModifyLiquidityTest deployed:", address(liquidityRouter));
            return liquidityRouter;
        }

        liquidityRouter = PoolModifyLiquidityTest(MODIFY_LIQUIDITY_HELPER);

        address c0 = TOKEN0;
        address c1 = TOKEN1;
        if (c0 > c1) (c0, c1) = (c1, c0);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(HOOK_ADDRESS)
        });

        IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: LIQUIDITY_DELTA,
            salt: POSITION_SALT
        });

        console2.log("=== Add Liquidity on X Layer ===");
        console2.log("PoolManager: ", POOL_MANAGER);
        console2.log("Hook:       ", HOOK_ADDRESS);
        console2.log("Helper:     ", address(liquidityRouter));
        console2.log("Token0:     ", c0);
        console2.log("Token1:     ", c1);
        console2.log("Fee:        ", FEE);
        console2.log("Tick lower: ", TICK_LOWER);
        console2.log("Tick upper: ", TICK_UPPER);
        console2.log("");
        console2.log("Before broadcast, approve both ERC20 tokens to the helper:");
        console2.log("  approve(helper, max) for TOKEN0");
        console2.log("  approve(helper, max) for TOKEN1");
        console2.log("");

        vm.startBroadcast(deployerKey);
        liquidityRouter.modifyLiquidity(key, params, "");
        vm.stopBroadcast();

        console2.log("Liquidity added.");
        console2.log("Next: run ProtectedSwap.s.sol to trigger afterSwap and mint a receipt.");
    }
}

