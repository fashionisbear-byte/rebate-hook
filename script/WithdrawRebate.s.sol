// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {RegretRebateHook} from "../src/RegretRebateHook.sol";
import {Currency} from "v4-core/types/Currency.sol";

// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
//  WithdrawRebate
//
//  Withdraws accumulated vault balance (rebates) for a specific currency.
//  The hook vault holds per-user, per-currency balances.
//  Call this after SettleReceipt.s.sol when a rebate has been credited.
//
//  Env vars:
//    DEPLOYER_PRIVATE_KEY
//    X_LAYER_RPC_URL
//
//  Parameters (set constants below):
//    HOOK_ADDRESS  鈥?RegretRebateHook deployed address
//    FEE_CURRENCY 鈥?the currency to withdraw (MUST match the receipt's feeCurrency).
//                  For zeroForOne swaps: this is TOKEN1.
//                  For oneForZero swaps: this is TOKEN0.
//                  Use the value from the ProtectedSwap receipt event.
//
//  Gas estimate only:
//    forge script script/WithdrawRebate.s.sol:WithdrawRebate
//        --rpc-url $X_LAYER_RPC_URL -vv
//
//  Real broadcast:
//    forge script script/WithdrawRebate.s.sol:WithdrawRebate
//        --rpc-url $X_LAYER_RPC_URL --broadcast -vv
//
// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
contract WithdrawRebate is Script {
    // 鈹€鈹€ Parameters 鈥?fill in before running 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
    address constant HOOK_ADDRESS = 0x0000000000000000000000000000000000000000; // Note: set
    address constant FEE_CURRENCY = 0x0000000000000000000000000000000000000000; // Note: set

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address caller = vm.addr(deployerKey);

        RegretRebateHook hook = RegretRebateHook(HOOK_ADDRESS);
        Currency currency = Currency.wrap(FEE_CURRENCY);

        uint256 balance = hook.getVaultBalance(caller, currency);

        console2.log("=== WithdrawRebate on X Layer ===");
        console2.log("Hook:       ", HOOK_ADDRESS);
        console2.log("FeeCurrency:", FEE_CURRENCY);
        console2.log("Caller:    ", caller);
        console2.log("Vault bal: ", balance);
        console2.log("");

        if (balance == 0) {
            console2.log("Nothing to withdraw. Did you run SettleReceipt.s.sol first?");
            console2.log("Or is FEE_CURRENCY correct? (feeCurrency from the swap receipt event)");
            return;
        }

        console2.log("Calling hook.withdraw(currency)...");

        vm.startBroadcast(deployerKey);
        hook.withdraw(currency);
        vm.stopBroadcast();

        uint256 balanceAfter = hook.getVaultBalance(caller, currency);

        console2.log("");
        console2.log("=== Withdrawal Complete ===");
        console2.log("Balance before:", balance);
        console2.log("Balance after: ", balanceAfter);
        console2.log("Withdrawn:    ", balance - balanceAfter);
        console2.log("");
        console2.log("=== Full cycle complete! ===");
        console2.log("Hook deployed => Pool initialized => Liquidity added => Swapped => Settled => Withdrawn");
    }
}

