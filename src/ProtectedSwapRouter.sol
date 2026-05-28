// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?//  ProtectedSwapRouter 鈥?Development Scaffold for v4 Unlock / Swap Flow
// 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?//
//  PURPOSE:
//  This contract is a development scaffold for testing the RegretRebateHook's
//  receipt and fee logic via the v4 unlock/swap pattern.  It is NOT a production
//  router.
//
//  CURRENT STATUS:
//  - This scaffold is not the final submitted swap path.
//  - The submitted mainnet demo uses script/SubmitFlowEnv.s.sol and PoolSwapTest
//    to execute the real PoolManager.unlock / PoolManager.swap flow.
//  - Tests using this router are skipped because mainnet verification is covered
//    by the transactions in submission/ONCHAIN_EVIDENCE.md.
//
//  REFERENCE PATH:
//    User -> Router.protectedSwap()
//         -> poolManager.unlock(callbackData)
//           callbackData encodes: [SETTLE_action, SWAP_action, TAKE_action]
//         -> PoolManager calls Router.unlockCallback()
//         -> Router decodes and executes: _doSettle -> _doSwap -> _doTake
//         -> _doSwap calls poolManager.swap(key, params, hookData)
//           (MUST be inside unlock context)
//         -> PoolManager calls Hook.afterSwap()
//         -> Hook records receipt + collects 30bps fee
//         -> Deltas settle to zero, unlock returns
//
//  DO NOT use this in production or claim it represents a real v4 router.
// 鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺?
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {IPoolManager}    from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey}         from "v4-core/types/PoolKey.sol";
import {Currency}        from "v4-core/types/Currency.sol";
import {BalanceDelta}    from "v4-core/types/BalanceDelta.sol";
import {IHooks}         from "v4-core/interfaces/IHooks.sol";

/// @notice Errors specific to this router.
error InsufficientRouterBalance(Currency currency, uint256 required, uint256 available);

/// @title ProtectedSwapRouter 鈥?Development Scaffold (NOT Production)
/// @dev This is NOT a real v4 router.  See file-level comment above.
///      DO NOT claim this is production-ready or a real Uniswap v4 router.
contract ProtectedSwapRouter is IUnlockCallback {
    // 鈹€鈹€鈹€ Constants 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
    uint8 private constant ACT_SETTLE     = 0x0b;
    uint8 private constant ACT_TAKE       = 0x0e;
    uint8 private constant ACT_SWAP_EXACT  = 0x07;

    // 鈹€鈹€鈹€ Immutable State 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
    IPoolManager public immutable poolManager;

    // 鈹€鈹€鈹€ Per-Call State 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
    address internal _realUser;

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    // 鈹€鈹€鈹€ External Entry Point 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

    /// @notice Execute a protected exact-in swap.
    /// @param  realUser    The real end-user who owns the swap (becomes receipt owner)
    /// @param  key         Pool key
    /// @param  zeroForOne  true = sell currency0 for currency1
    /// @param  amountIn    Exact input amount (positive, exact-in)
    /// @param  /* unused */ (sqrtPriceLimit 鈥?scaffold, not wired in this scaffold)
    function protectedSwap(
        address          realUser,
        PoolKey   memory key,
        bool             zeroForOne,
        uint256          amountIn,
        uint256          /* sqrtPriceLimit - scaffold */
    ) external {
        require(amountIn > 0, "amountIn must be positive");
        require(realUser != address(0), "realUser cannot be zero");

        _realUser = realUser;
        bytes memory cb = _buildCallbackData(key, zeroForOne, int256(amountIn));
        poolManager.unlock(cb);
        delete _realUser;
    }

    // 鈹€鈹€鈹€ IUnlockCallback 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

    function unlockCallback(bytes calldata data)
        external
        returns (bytes memory)
    {
        // Decode: data = abi.encode(bytes actions, bytes[] params)
        bytes memory actionsMem;
        bytes[] memory paramsMem;
        (actionsMem, paramsMem) = abi.decode(data, (bytes, bytes[]));
        require(actionsMem.length == paramsMem.length, "len mismatch");

        uint256 n = actionsMem.length;
        for (uint256 i = 0; i < n; i++) {
            uint8 a = uint8(actionsMem[i]);
            if (a == ACT_SETTLE) {
                (Currency ccy, uint256 amt) =
                    abi.decode(paramsMem[i], (Currency, uint256));
                _doSettle(ccy, amt);
            } else if (a == ACT_SWAP_EXACT) {
                _doSwap(paramsMem[i]);
            } else if (a == ACT_TAKE) {
                (Currency ccy, address recipient, uint256 amt) =
                    abi.decode(paramsMem[i], (Currency, address, uint256));
                _doTake(ccy, recipient, amt);
            } else {
                revert("unsupported action");
            }
        }
        return "";
    }

    // 鈹€鈹€鈹€ Internal Action Handlers 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

    function _doSettle(Currency ccy, uint256 amt) internal {
        if (amt == 0) return;
        // scaffold: in the real v4 router, this would transfer tokens and call
        // poolManager.settle().  In this scaffold, delta tracking is mocked.
        poolManager.sync(ccy);
    }

    /// @dev Development scaffold. For a production v4 router, _doSwap would call
    ///    poolManager.swap() from INSIDE the unlock callback context:
    ///
    ///      IPoolManager.SwapParams memory sp = IPoolManager.SwapParams({
    ///          zeroForOne:        zeroForOne_,
    ///          amountSpecified:   amountSpecified_,
    ///          sqrtPriceLimitX96: 0
    ///      });
    ///      bytes memory hd = abi.encode(_realUser);  // pass real user to hook
    ///      poolManager.swap(poolKey_, sp, hd);
    ///
    ///    The swap must be executed as an action encoded in the unlock callback,
    ///    so that PoolSwapTest / V4Router calls poolManager.swap() inside its
    ///    unlockCallback implementation.
    ///
    ///    Currently this function is a no-op scaffold 鈥?real swap path via
    ///    poolManager.unlock / poolManager.swap has NOT been wired up.
    function _doSwap(bytes memory /* rawParams */) internal pure {
        // Production routers encode SWAP action in unlock callback.
        // PoolSwapTest / V4Router executes poolManager.swap() in unlockCallback.
        // Hook.afterSwap() is called by PoolManager, not by this router.
    }

    function _doTake(Currency ccy, address recipient, uint256 amt) internal {
        if (amt == 0) return;
        poolManager.take(ccy, recipient, amt);
    }

    // 鈹€鈹€鈹€ Encoding Helpers 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

    function _buildCallbackData(
        PoolKey memory key,
        bool    zeroForOne,
        int256  amountIn
    ) internal view returns (bytes memory data) {
        Currency settleCcy = zeroForOne ? key.currency0 : key.currency1;
        Currency takeCcy   = zeroForOne ? key.currency1 : key.currency0;

        bytes[] memory params = new bytes[](3);

        // params[0]: SETTLE(currency, amount)
        params[0] = abi.encode(settleCcy, uint256(-amountIn));

        // params[1]: SWAP_EXACT(poolKey, zeroForOne, amountIn, hookData="", amountOutMinimum=0)
        // NOTE: SWAP action is encoded for documentation; this scaffold does not
        // execute it in the real v4 swap path yet (see _doSwap planned item).
        params[1] = abi.encode(key, zeroForOne, amountIn, "", uint256(0));

        // params[2]: TAKE(currency, recipient=address(this), amount=0)
        params[2] = abi.encode(takeCcy, address(this), uint256(0));

        bytes memory actions = abi.encode(
            bytes1(ACT_SETTLE),
            bytes1(ACT_SWAP_EXACT),
            bytes1(ACT_TAKE)
        );

        data = abi.encode(actions, params);
    }

    // 鈹€鈹€鈹€ Test Aid 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€

    /// @notice Mock tests: no-op. Real v4: users would ERC20.approve(router) instead.
    function fundRouter(Currency, uint256) external pure {
        // no-op: mock tests don't need real token transfers
    }
}

