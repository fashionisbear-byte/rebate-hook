// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";

// 鈹€鈹€鈹€ Constants 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
address constant POOL_MANAGER = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;

// 鈹€鈹€鈹€ DeployPoolSwapTestHelper 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
//
//  Deploys the PoolSwapTest helper used for protected swaps.
//  PoolSwapTest (from v4-core) handles the full unlock -> swap -> settle/take
//  flow internally via the unlockCallback pattern.  It is a test helper,
//  NOT a production router.
//
//  This contract is a subroutine; it is called inside DeployProtectedSwap.
//  Run standalone to get the PoolSwapTest address if you already have a deployed hook.
//
//  Env vars:
//    DEPLOYER_PRIVATE_KEY
//    X_LAYER_RPC_URL
// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
contract DeployPoolSwapTestHelper is Script {
    function run() external returns (PoolSwapTest testSwapRouter) {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        console2.log("=== Deploy PoolSwapTest Helper ===");
        console2.log("PoolManager:", POOL_MANAGER);

        vm.startBroadcast(deployerKey);
        testSwapRouter = new PoolSwapTest(IPoolManager(address(POOL_MANAGER)));
        vm.stopBroadcast();

        console2.log("PoolSwapTest deployed:", address(testSwapRouter));
        return testSwapRouter;
    }
}

// 鈹€鈹€鈹€ DeployProtectedSwap 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
//
//  Full flow:
//    1. (optional) Deploy PoolSwapTest if POOL_SWAP_TEST_ADDRESS = 0
//    2. Approve input token to PoolSwapTest  (2 approvals if zeroForOne / oneForZero)
//    3. Call swap()
//
//  Env vars required:
//    DEPLOYER_PRIVATE_KEY
//    X_LAYER_RPC_URL
//
//  Parameters (set constants below):
//    HOOK_ADDRESS          - RegretRebateHook deployed address
//    POOL_SWAP_TEST       - PoolSwapTest helper address (0 = auto-deploy)
//    TOKEN0, TOKEN1       - Pool token addresses
//    FEE, TICK_SPACING    - Pool parameters
//    ZERO_FOR_ONE         - swap direction: true = sell TOKEN0, false = sell TOKEN1
//    AMOUNT_SPECIFIED     - negative = exact-input, positive = exact-output (in wei)
//    SQRT_PRICE_LIMIT     - price limit (0 = no limit); useTick price math to convert
//    OWNER                - address that receives the receipt (0 = msg.sender = deployer)
//
//  Example exact-input swap (sell 1 ETH worth of token0):
//    ZERO_FOR_ONE = true
//    AMOUNT_SPECIFIED = -1_000_000_000_000_000_000  // -1e18
//
//  Gas estimate only:
//    forge script script/ProtectedSwap.s.sol:DeployProtectedSwap
//        --rpc-url $X_LAYER_RPC_URL -vv
//
//  Real broadcast:
//    forge script script/ProtectedSwap.s.sol:DeployProtectedSwap
//        --rpc-url $X_LAYER_RPC_URL --broadcast -vv
//
//  NOTE: This script uses PoolSwapTest as a test helper to exercise the
//  PoolManager.unlock / manager.swap path.  It is NOT a production router.
//  The swap executes via:
//    PoolSwapTest.swap() -> PoolManager.unlock() -> PoolSwapTest.unlockCallback()
//      -> PoolManager.swap() -> Hook.afterSwap()
//  which is the genuine v4 swap path.
// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
contract DeployProtectedSwap is Script {
    // 鈹€鈹€ Pool / hook parameters 鈹€鈹€ fill in before running 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
    address constant HOOK_ADDRESS = 0x0000000000000000000000000000000000000000; // Note: set
    address constant POOL_SWAP_TEST = 0x0000000000000000000000000000000000000000; // Note: set (0 = auto-deploy)
    address constant TOKEN0 = 0x0000000000000000000000000000000000000000; // Note: set
    address constant TOKEN1 = 0x0000000000000000000000000000000000000000; // Note: set
    uint24  constant FEE = 3000;
    int24   constant TICK_SPACING = 60;

    // 鈹€鈹€ Swap parameters 鈹€鈹€ fill in before running 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
    bool    constant ZERO_FOR_ONE = true;                                  // Note: set
    int256  constant AMOUNT_SPECIFIED = -10_000_000_000_000_000;          // Note: -1e16 = 0.01 ETH worth
    uint160 constant SQRT_PRICE_LIMIT = 0;                                // Note: 0 = no limit
    address constant OWNER = address(0);                                   // Note: 0 = msg.sender

    function run() external returns (PoolSwapTest swapRouter, uint256 receiptId) {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // 鈹€鈹€ 1. Deploy PoolSwapTest if not provided 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        if (POOL_SWAP_TEST == address(0)) {
            console2.log("[1/3] Auto-deploying PoolSwapTest...");
            vm.startBroadcast(deployerKey);
            swapRouter = new PoolSwapTest(IPoolManager(address(POOL_MANAGER)));
            vm.stopBroadcast();
            console2.log("    PoolSwapTest:", address(swapRouter));
        } else {
            swapRouter = PoolSwapTest(POOL_SWAP_TEST);
            console2.log("[1/3] Using existing PoolSwapTest:", address(swapRouter));
        }

        // 鈹€鈹€ 2. Build PoolKey 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        address c0 = TOKEN0;
        address c1 = TOKEN1;
        if (c0 > c1) (c0, c1) = (c1, c0);

        PoolKey memory key = PoolKey({
            currency0:    Currency.wrap(c0),
            currency1:    Currency.wrap(c1),
            fee:          FEE,
            tickSpacing:  TICK_SPACING,
            hooks:        IHooks(HOOK_ADDRESS)
        });

        // 鈹€鈹€ 3. Build SwapParams (IPoolManager.SwapParams) 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne:         ZERO_FOR_ONE,
            amountSpecified:    AMOUNT_SPECIFIED,
            sqrtPriceLimitX96: SQRT_PRICE_LIMIT
        });

        // PoolSwapTest.TestSettings: takeClaims=false, settleUsingBurn=false
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({
            takeClaims:       false,
            settleUsingBurn: false
        });

        // hookData: encode OWNER so RegretRebateHook records the right receipt owner
        bytes memory hookData;
        if (OWNER != address(0)) {
            hookData = abi.encode(OWNER);
        }

        console2.log("");
        console2.log("=== ProtectedSwap on X Layer ===");
        console2.log("PoolManager:  ", POOL_MANAGER);
        console2.log("Hook:        ", HOOK_ADDRESS);
        console2.log("PoolSwapTest:", address(swapRouter));
        console2.log("Token0:      ", c0);
        console2.log("Token1:      ", c1);
        console2.log("Fee:         ", FEE, "bps");
        console2.log("Direction:   ", ZERO_FOR_ONE ? "TOKEN0->TOKEN1 (zeroForOne)" : "TOKEN1->TOKEN0 (oneForZero)");
        console2.log("Amount:      ", AMOUNT_SPECIFIED < 0 ? "exact input " : "exact output ", AMOUNT_SPECIFIED < 0 ? uint256(-AMOUNT_SPECIFIED) : uint256(AMOUNT_SPECIFIED));
        if (OWNER != address(0)) {
            console2.log("Owner:      ", OWNER);
        } else {
            console2.log("Owner:      ", "msg.sender");
        }
        console2.log("");
        console2.log("[!] Before running:");
        console2.log("   - Approve PoolSwapTest to spend your input token");
        console2.log("     IERC20(TOKEN0/TOKEN1).approve(PoolSwapTest, type(uint256).max)");
        console2.log("   - Ensure PoolSwapTest and the pool have sufficient liquidity");
        console2.log("");

        // 鈹€鈹€ 4. Execute swap 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        //  Route: PoolSwapTest.swap() -> PoolManager.unlock() -> PoolSwapTest.unlockCallback()
        //       -> PoolManager.swap() -> Hook.afterSwap()
        //  This is the genuine v4 swap path via PoolSwapTest (a v4-core test helper).
        vm.startBroadcast(deployerKey);
        swapRouter.swap(key, params, testSettings, hookData);
        vm.stopBroadcast();

        // Receipt ID is minted sequentially from hook.nextReceiptId().
        // We can't read it from the event here without the event log ABI,
        // so we note the expected ID (previous nextReceiptId before this tx).
        // In practice: query hook.nextReceiptId() before the swap, or parse
        // the ProtectedSwap(receiptId, ...) event log from the tx receipt.
        console2.log("Swap executed!");
        console2.log("");
        console2.log("=== NEXT ===");
        console2.log("1. Query hook.nextReceiptId() to find your receiptId");
        console2.log("2. Wait 5 minutes for settle window");
        console2.log("3. Run SettleReceipt.s.sol to settle and claim rebate");
    }
}

