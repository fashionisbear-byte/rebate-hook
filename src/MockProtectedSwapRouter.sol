// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// ⚠️  MOCK / TEST AID ONLY — NOT A REAL V4 ROUTER
//
// This router does NOT integrate with real Uniswap v4:
//   ✗  Does NOT call poolManager.unlock() with a callback
//   ✗  Does NOT handle ERC20 approvals or real token flows
//   ✗  Does NOT perform AMM math
//
// It directly calls the hook's afterSwap() with mock BalanceDelta data
// to exercise the hook's receipt/fee logic in unit tests.
//
// A real v4 router must:
//   1. User approves router for input token
//   2. Router calls poolManager.unlock(callbackData)
//   3. PoolManager invokes PoolSwapTest.swap() in the callback
//   4. PoolManager calls hook.afterSwap()
//   5. Router settles balances with user via PoolManager.settle()

import {IPoolManager}  from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey}        from "v4-core/types/PoolKey.sol";
import {BalanceDelta, toBalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {RegretRebateHook} from "./RegretRebateHook.sol";

/// @notice MOCK Router — directly calls hook.afterSwap(), bypasses PoolManager.
///         For unit tests only. See ProtectedSwapRouter.sol for the real v4 Router.
contract MockProtectedSwapRouter {
    using BalanceDeltaLibrary for BalanceDelta;

    IPoolManager     public poolManager;
    RegretRebateHook public hook;

    event SimulatedSwap(
        address indexed sender,
        bool zeroForOne,
        uint256 grossOutput,
        uint256 fee,
        uint256 hookDelta
    );

    constructor(IPoolManager _poolManager, RegretRebateHook _hook) {
        poolManager = _poolManager;
        hook        = _hook;
    }

    /// @notice Simulate a protected swap by calling hook.afterSwap() directly.
    ///         Only for local unit testing. NOT for production use.
    /// @param  key             Pool key (hook address must match deployed hook)
    /// @param  zeroForOne      Swap direction
    /// @param  amountSpecified Amount to swap (positive = exact output, negative = exact input)
    /// @return hookDelta       The delta returned by the hook
    function protectedSwap(
        PoolKey memory key,
        bool           zeroForOne,
        int256         amountSpecified,
        uint160        /* sqrtPriceLimitX96 */,
        bytes memory   /* hookData */
    ) external returns (int128 hookDelta) {
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne        : zeroForOne,
            amountSpecified   : amountSpecified,
            sqrtPriceLimitX96 : 0
        });

        // Simulate a mock BalanceDelta: pool settles gross output to the swapper.
        // For zeroForOne: amount0 = -amountSpecified (in), amount1 = +mockOutput (out)
        // For oneForZero: amount0 = +mockOutput (out), amount1 = -amountSpecified (in)
        uint256 amt = uint256(amountSpecified < 0 ? -amountSpecified : amountSpecified);
        uint256 mockOutput = amt * 998 / 1000; // ~2 bps simulated slippage

        BalanceDelta mockDelta = zeroForOne
            ? toBalanceDelta(int128(-int256(amt)), int128(int256(mockOutput)))
            : toBalanceDelta(int128(int256(mockOutput)), int128(-int256(amt)));

        // Call the hook's afterSwap directly (bypasses real PoolManager)
        (, hookDelta) = hook.afterSwap(msg.sender, key, params, mockDelta, "");

        uint256 gross = mockOutput;
        uint256 fee   = (gross * 30) / 10000;

        emit SimulatedSwap(msg.sender, zeroForOne, gross, fee, uint256(int256(hookDelta)));
    }
}
