// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {PoolModifyLiquidityTest} from "v4-core/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {MockERC20} from "../src/MockERC20.sol";
import {RegretRebateHook} from "../src/RegretRebateHook.sol";

address constant X_LAYER_POOL_MANAGER = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
uint24 constant DEMO_FEE = 3000;
int24 constant DEMO_TICK_SPACING = 60;
uint160 constant SQRT_PRICE_1_1 = 0x1000000000000000000000000;
uint256 constant DEMO_TOKEN_SUPPLY = 1_000_000 ether;

library SubmitFlowKeys {
    function poolKey(address hook, address tokenA, address tokenB) internal pure returns (PoolKey memory key) {
        address c0 = tokenA;
        address c1 = tokenB;
        if (c0 > c1) (c0, c1) = (c1, c0);
        key = PoolKey({
            currency0: Currency.wrap(c0),
            currency1: Currency.wrap(c1),
            fee: DEMO_FEE,
            tickSpacing: DEMO_TICK_SPACING,
            hooks: IHooks(hook)
        });
    }

    function logPool(PoolKey memory key) internal pure {
        console2.log("Token0:", Currency.unwrap(key.currency0));
        console2.log("Token1:", Currency.unwrap(key.currency1));
        console2.log("Hook:  ", address(key.hooks));
        console2.log("PoolId:");
        console2.logBytes32(PoolId.unwrap(key.toId()));
    }
}

contract DeployDemoTokens is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);
        MockERC20 tokenA = new MockERC20("Regret Rebate Demo Token A", "RRDA", deployer, DEMO_TOKEN_SUPPLY);
        MockERC20 tokenB = new MockERC20("Regret Rebate Demo Token B", "RRDB", deployer, DEMO_TOKEN_SUPPLY);
        vm.stopBroadcast();

        address t0 = address(tokenA);
        address t1 = address(tokenB);
        if (t0 > t1) (t0, t1) = (t1, t0);

        console2.log("=== Demo tokens deployed ===");
        console2.log("TokenA:", address(tokenA));
        console2.log("TokenB:", address(tokenB));
        console2.log("Token0:", t0);
        console2.log("Token1:", t1);
        console2.log("Owner: ", deployer);
        console2.log("Minted each:", DEMO_TOKEN_SUPPLY);
    }
}

contract InitializeDemoPool is Script {
    using PoolIdLibrary for PoolKey;

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address hook = vm.envAddress("HOOK_ADDRESS");
        address token0 = vm.envAddress("TOKEN0");
        address token1 = vm.envAddress("TOKEN1");

        PoolKey memory key = SubmitFlowKeys.poolKey(hook, token0, token1);

        console2.log("=== Initialize demo pool ===");
        SubmitFlowKeys.logPool(key);

        vm.startBroadcast(deployerKey);
        int24 tick = IPoolManager(X_LAYER_POOL_MANAGER).initialize(key, SQRT_PRICE_1_1);
        vm.stopBroadcast();

        console2.log("Initialize tick:", tick);
    }
}

contract DeployDemoHelpers is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerKey);
        PoolModifyLiquidityTest liquidityHelper = new PoolModifyLiquidityTest(IPoolManager(X_LAYER_POOL_MANAGER));
        PoolSwapTest swapHelper = new PoolSwapTest(IPoolManager(X_LAYER_POOL_MANAGER));
        vm.stopBroadcast();

        console2.log("=== Demo helpers deployed ===");
        console2.log("LIQUIDITY_HELPER:", address(liquidityHelper));
        console2.log("SWAP_HELPER:     ", address(swapHelper));
    }
}

contract ApproveDemoSpender is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address spender = vm.envAddress("SPENDER");
        address token0 = vm.envAddress("TOKEN0");
        address token1 = vm.envAddress("TOKEN1");

        vm.startBroadcast(deployerKey);
        IERC20Minimal(token0).approve(spender, type(uint256).max);
        IERC20Minimal(token1).approve(spender, type(uint256).max);
        vm.stopBroadcast();

        console2.log("=== Approved spender ===");
        console2.log("Spender:", spender);
        console2.log("Token0: ", token0);
        console2.log("Token1: ", token1);
    }
}

contract AddDemoLiquidity is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address hook = vm.envAddress("HOOK_ADDRESS");
        address token0 = vm.envAddress("TOKEN0");
        address token1 = vm.envAddress("TOKEN1");
        address helper = vm.envAddress("LIQUIDITY_HELPER");

        PoolKey memory key = SubmitFlowKeys.poolKey(hook, token0, token1);
        IPoolManager.ModifyLiquidityParams memory params = IPoolManager.ModifyLiquidityParams({
            tickLower: -600,
            tickUpper: 600,
            liquidityDelta: 1e18,
            salt: bytes32(0)
        });

        console2.log("=== Add demo liquidity ===");
        SubmitFlowKeys.logPool(key);
        console2.log("LIQUIDITY_HELPER:", helper);

        vm.startBroadcast(deployerKey);
        PoolModifyLiquidityTest(helper).modifyLiquidity(key, params, "");
        vm.stopBroadcast();

        console2.log("Liquidity added.");
    }
}

contract ProtectedDemoSwap is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address hook = vm.envAddress("HOOK_ADDRESS");
        address token0 = vm.envAddress("TOKEN0");
        address token1 = vm.envAddress("TOKEN1");
        address helper = vm.envAddress("SWAP_HELPER");

        PoolKey memory key = SubmitFlowKeys.poolKey(hook, token0, token1);
        bool zeroForOne = true;
        int256 amountSpecified = -0.01 ether;
        uint160 sqrtPriceLimitX96 = TickMath.MIN_SQRT_PRICE + 1;
        uint256 receiptId = RegretRebateHook(hook).nextReceiptId();

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });
        PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        console2.log("=== Protected demo swap ===");
        SubmitFlowKeys.logPool(key);
        console2.log("SWAP_HELPER:", helper);
        console2.log("Expected ReceiptId:", receiptId);

        vm.startBroadcast(deployerKey);
        PoolSwapTest(helper).swap(key, params, settings, abi.encode(deployer));
        vm.stopBroadcast();

        console2.log("Protected swap executed.");
        console2.log("ReceiptId:", receiptId);
    }
}

contract SettleDemoReceipt is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address hook = vm.envAddress("HOOK_ADDRESS");
        uint256 receiptId = vm.envUint("RECEIPT_ID");
        uint256 maxTickDelta = 1_000_000;

        RegretRebateHook h = RegretRebateHook(hook);
        RegretRebateHook.Receipt memory receipt = h.getReceipt(receiptId);

        console2.log("=== Settle demo receipt ===");
        console2.log("Hook:", hook);
        console2.log("ReceiptId:", receiptId);
        console2.log("Owner:", receipt.owner);
        console2.log("Fee amount:", receipt.feeAmount);
        console2.log("Fee currency:", Currency.unwrap(receipt.feeCurrency));
        console2.log("SettleAfter:", receipt.settleAfter);
        console2.log("Current time:", block.timestamp);

        if (block.timestamp < receipt.settleAfter) {
            console2.log("Settle window not open yet. Wait seconds:", receipt.settleAfter - block.timestamp);
            return;
        }

        vm.startBroadcast(deployerKey);
        h.settle(receiptId, maxTickDelta);
        vm.stopBroadcast();

        RegretRebateHook.Receipt memory settled = h.getReceipt(receiptId);
        uint256 vaultBalance = h.getVaultBalance(settled.owner, settled.feeCurrency);

        (, int24 settleTick,,) = StateLibrary.getSlot0(
            IPoolManager(X_LAYER_POOL_MANAGER),
            PoolId.wrap(settled.poolId)
        );

        console2.log("Settled:", settled.settled);
        console2.log("SettledAt:", settled.settledAt);
        console2.log("ExecutionTick:", settled.executionTick);
        console2.log("SettleTick:", settleTick);
        console2.log("Vault balance:", vaultBalance);
    }
}
