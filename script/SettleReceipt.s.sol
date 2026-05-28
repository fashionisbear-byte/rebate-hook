// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {RegretRebateHook} from "../src/RegretRebateHook.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
//  SettleReceipt
//
//  Settles a protected-swap receipt and claims the rebate (if price moved against you).
//  The receipt must have passed its 5-minute settle window.
//
//  Rebate logic (tick comparison, no oracle required):
//    ZeroForOne (sold token0): bad if settleTick > execTick (price went up 鈫?bought worse)
//    OneForZero (sold token1): bad if settleTick < execTick (price went down 鈫?sold worse)
//
//  Env vars:
//    DEPLOYER_PRIVATE_KEY
//    X_LAYER_RPC_URL
//
//  Parameters (set constants below):
//    HOOK_ADDRESS        鈥?RegretRebateHook deployed address
//    RECEIPT_ID          鈥?receipt ID from the ProtectedSwap transaction
//    MAX_TICK_DELTA      鈥?slippage in ticks. If actual tick delta > this, revert.
//                          Set to a value that won't revert for your expected price range.
//                          Example: 50 = allow 卤50 tick movement at settlement
//    TOKEN0, TOKEN1     鈥?pool token addresses (used only for event display)
//
//  Gas estimate only:
//    forge script script/SettleReceipt.s.sol:SettleReceipt
//        --rpc-url $X_LAYER_RPC_URL -vv
//
//  Real broadcast:
//    forge script script/SettleReceipt.s.sol:SettleReceipt
//        --rpc-url $X_LAYER_RPC_URL --broadcast -vv
//
// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
contract SettleReceipt is Script {
    // 鈹€鈹€ Parameters 鈥?fill in before running 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
    address constant HOOK_ADDRESS = 0x0000000000000000000000000000000000000000; // Note: set
    uint256 constant RECEIPT_ID = 0;                                             // Note: set
    uint256 constant MAX_TICK_DELTA = 100;                                       // Note: adjust to expected range

    // Pool tokens for display only (used to show feeCurrency)
    address constant TOKEN0 = 0x0000000000000000000000000000000000000000; // Note: set
    address constant TOKEN1 = 0x0000000000000000000000000000000000000000; // Note: set

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        RegretRebateHook hook = RegretRebateHook(HOOK_ADDRESS);
        address POOL_MANAGER = hook.POOL_MANAGER();

        // 鈹€鈹€ Read receipt 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        RegretRebateHook.Receipt memory r = hook.getReceipt(RECEIPT_ID);

        console2.log("=== Settle Receipt on X Layer ===");
        console2.log("Hook:       ", HOOK_ADDRESS);
        console2.log("Receipt ID:", RECEIPT_ID);
        console2.log("");
        console2.log("Receipt:");
        console2.log("  owner:         ", r.owner);
        console2.log("  executionTick: ", r.executionTick);
        console2.log("  grossAmount:   ", r.grossAmount);
        console2.log("  feeAmount:     ", r.feeAmount);
        console2.log("  feeCurrency:   ", Currency.unwrap(r.feeCurrency));
        bool windowOpen = block.timestamp >= r.settleAfter;
        console2.log("  settleAfter:   ", r.settleAfter, windowOpen ? "[OPEN]" : "[NOT YET OPEN]");
        console2.log("  settled:       ", r.settled);
        console2.log("");

        // 鈹€鈹€ Guard: already settled 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        if (r.settled) {
            console2.log("Receipt already settled. Nothing to do.");
            return;
        }

        // 鈹€鈹€ Guard: window not open 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        if (block.timestamp < r.settleAfter) {
            uint256 remaining = r.settleAfter - block.timestamp;
            console2.log("Settle window not yet open.");
            console2.log("  Current time:", block.timestamp);
            console2.log("  Opens at:   ", r.settleAfter);
            console2.log("  Remaining:  ", remaining, "seconds");
            console2.log("");
            console2.log("Wait and re-run after the window opens.");
            return;
        }

        // 鈹€鈹€ Preview: read current tick 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        PoolId poolId = PoolId.wrap(r.poolId);
        (, int24 currentTick,,) = StateLibrary.getSlot0(IPoolManager(POOL_MANAGER), poolId);
        uint256 tickDelta = r.executionTick > currentTick
            ? uint256(int256(r.executionTick) - int256(currentTick))
            : uint256(int256(currentTick) - int256(r.executionTick));

        bool badExecution = r.direction == RegretRebateHook.Direction.ZeroForOne
            ? (currentTick > r.executionTick)
            : (currentTick < r.executionTick);

        console2.log("Pre-settlement check:");
        console2.log("  Current tick:  ", currentTick);
        console2.log("  Tick delta:    ", tickDelta);
        console2.log("  Max allowed:  ", MAX_TICK_DELTA);
        console2.log("  Bad execution: ", badExecution ? "YES -> rebate will be credited" : "NO -> no rebate");
        console2.log("");

        if (tickDelta > MAX_TICK_DELTA) {
            console2.log("[!] Tick delta exceeds MAX_TICK_DELTA. Increase MAX_TICK_DELTA or re-run after price stabilizes.");
        }

        // 鈹€鈹€ Settle 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        console2.log("Calling hook.settle(...)...");

        vm.startBroadcast(deployerKey);
        hook.settle(RECEIPT_ID, MAX_TICK_DELTA);
        vm.stopBroadcast();

        // 鈹€鈹€ Verify 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        RegretRebateHook.Receipt memory settled = hook.getReceipt(RECEIPT_ID);
        uint256 vaultBal = hook.getVaultBalance(r.owner, r.feeCurrency);

        console2.log("");
        console2.log("=== Settlement Result ===");
        console2.log("Receipt settled:", settled.settled);
        console2.log("settledAt:    ", settled.settledAt);
        console2.log("Vault balance: ", vaultBal, Currency.unwrap(r.feeCurrency));
        console2.log("");
        console2.log(vaultBal > 0
            ? "=== Rebate credited! Run WithdrawRebate.s.sol to claim tokens. ==="
            : "=== No rebate (price moved in your favor). ===");
    }
}

