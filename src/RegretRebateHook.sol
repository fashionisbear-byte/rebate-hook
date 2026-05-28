// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IHooks}             from "v4-core/interfaces/IHooks.sol";
import {IPoolManager}       from "v4-core/interfaces/IPoolManager.sol";
import {Hooks}              from "v4-core/libraries/Hooks.sol";
import {PoolKey}            from "v4-core/types/PoolKey.sol";
import {PoolId}             from "v4-core/types/PoolId.sol";
import {PoolIdLibrary}      from "v4-core/types/PoolId.sol";
import {BalanceDelta}       from "v4-core/types/BalanceDelta.sol";
import {BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta}    from "v4-core/types/BeforeSwapDelta.sol";
import {Currency}           from "v4-core/types/Currency.sol";
import {CurrencyLibrary}    from "v4-core/types/Currency.sol";
import {StateLibrary}       from "v4-core/libraries/StateLibrary.sol";

/// @title RegretRebateHook
/// @notice Uniswap v4 hook: collects 30 bps protection fee via v4 accounting,
///         records a receipt, and allows settlement after 5 minutes.
///         Rebate is paid if price moved against the user (tick comparison).
/// @dev Hook permissions: afterSwap(0x40) + afterSwapReturnDelta(0x04) = 0x44
contract RegretRebateHook is IHooks {
    using BalanceDeltaLibrary for BalanceDelta;
    using PoolIdLibrary for PoolKey;

    // ─── Constants ─────────────────────────────────────────────────────────────

    uint24  public constant PROTECTION_FEE_BPS = 30;
    uint256 public constant BPS                 = 10_000;
    uint256 public constant SETTLE_WINDOW       = 5 minutes;

    // Hook address bitmap targets:
    //   AFTER_SWAP_FLAG               = 1 << 6 = 0x40
    //   AFTER_SWAP_RETURNS_DELTA_FLAG = 1 << 2 = 0x04
    //   target = 0x40 | 0x04 = 0x44
    uint160 public constant HOOK_MASK_TARGET = 0x44;

    // ─── Custom Errors ─────────────────────────────────────────────────────────

    error AlreadySettled();
    error SettleWindowNotOpen();
    error ZeroReceipt();
    error TickDeltaExceeded(uint256 maxTickDelta, uint256 actualTickDelta);
    error HookNotAuthorized();
    error InvalidPoolManager();
    error InvalidHookData();
    error ZeroOutput();
    error NothingToWithdraw();

    // ─── Types ────────────────────────────────────────────────────────────────

    enum Direction { ZeroForOne, OneForZero }

    struct Receipt {
        address   owner;
        bytes32   poolId;
        Direction direction;
        int24     executionTick;
        uint256   grossAmount;
        uint256   feeAmount;
        Currency  feeCurrency;   // NEW: which currency the fee was charged in
        uint256   settleAfter;
        bool      settled;
        uint256   settledAt;
    }

    // ─── State ───────────────────────────────────────────────────────────────

    address public immutable POOL_MANAGER;
    uint256 public nextReceiptId;

    mapping(uint256 => Receipt)                  public receipts;
    mapping(address => mapping(Currency => uint256)) public vault;  // NEW: per-currency vault

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(IPoolManager _poolManager) {
        if (address(_poolManager) == address(0)) revert InvalidPoolManager();
        POOL_MANAGER = address(_poolManager);
    }

    // ─── IHooks implementation ────────────────────────────────────────────────
    // Only afterSwap is implemented. Other hooks revert if ever called
    // (PoolManager only calls hooks enabled in the address bitmap = bits 0x44).

    function beforeInitialize(address, PoolKey calldata, uint160)
        external pure returns (bytes4) { revert(); }

    function afterInitialize(address, PoolKey calldata, uint160, int24)
        external pure returns (bytes4) { revert(); }

    function beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        external pure returns (bytes4) { revert(); }

    function afterAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta, BalanceDelta, bytes calldata)
        external pure returns (bytes4, BalanceDelta) { revert(); }

    function beforeRemoveLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        external pure returns (bytes4) { revert(); }

    function afterRemoveLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta, BalanceDelta, bytes calldata)
        external pure returns (bytes4, BalanceDelta) { revert(); }

    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
        external pure returns (bytes4, BeforeSwapDelta, uint24) { revert(); }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external pure returns (bytes4) { revert(); }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external pure returns (bytes4) { revert(); }

    // ─── Core Hook Callback ─────────────────────────────────────────────────────

    /// @notice afterSwap — called after every swap in a protected pool.
    ///         Uses v4 accounting to collect 30 bps fee:
    ///         1. Identifies the unspecified output currency.
    ///         2. Calculates fee = BPS of output amount.
    ///         3. Calls manager.take(currency, address(this), fee) to collect fee.
    ///         4. Returns hookDelta = fee so swapper pays the fee via v4 accounting.
    ///         5. Creates a receipt for potential rebate settlement.
    ///
    /// @param  sender   Original swap initiator
    /// @param  key      Pool key
    /// @param  params   Swap parameters (zeroForOne, amountSpecified, etc.)
    /// @param  delta    Pool's net settled delta to the swapper
    /// @return          IHooks.afterSwap.selector
    /// @return hookDelta Fee amount in unspecified currency; PoolManager bills this to the swapper
    function afterSwap(
        address                          sender,
        PoolKey          calldata         key,
        IPoolManager.SwapParams calldata   params,
        BalanceDelta                     delta,
        bytes           calldata          hookData
    ) external onlyFromPoolManager returns (bytes4, int128 hookDelta) {
        // ── Step 1: Identify unspecified output amount ──────────────────────────
        // For exact-in swaps (amountSpecified < 0): output is unspecified currency
        //   zeroForOne → amount1 is output (unspecified)
        //   oneForZero → amount0 is output (unspecified)
        // For exact-out swaps (amountSpecified > 0): the output IS the specified currency
        //   (Pool settled the delta; hook reads amount in unspecified currency)
        int128 unspecifiedAmt = params.zeroForOne ? delta.amount1() : delta.amount0();

        if (unspecifiedAmt <= 0) revert ZeroOutput();

        // ── Step 2: Calculate fee ──────────────────────────────────────────────
        uint256 outputAmt = uint256(int256(unspecifiedAmt));
        uint256 fee       = (outputAmt * PROTECTION_FEE_BPS) / BPS;

        // ── Step 3: Determine fee currency ────────────────────────────────────
        bool specifiedTokenIs0 = (params.amountSpecified < 0) == params.zeroForOne;
        Currency feeCurrency = specifiedTokenIs0 ? key.currency1 : key.currency0;

        // ── Step 4: Collect fee via v4 manager.take() ─────────────────────────
        // manager.take(currency, recipient, amount) moves tokens from PoolManager's
        // internal settlement balance into the hook's internal balance.
        // No try/catch — let底层 errors bubble up.
        if (fee > 0) {
            IPoolManager(POOL_MANAGER).take(feeCurrency, address(this), fee);
        }

        // ── Step 5: Record execution tick and create receipt ───────────────────
        address owner = _receiptOwner(sender, hookData);
        PoolId poolId = key.toId();
        int24  execTick = _currentTick(poolId);

        uint256 rid = nextReceiptId++;
        Receipt storage r = receipts[rid];
        r.owner         = owner;
        r.poolId        = PoolId.unwrap(poolId);
        r.direction     = params.zeroForOne ? Direction.ZeroForOne : Direction.OneForZero;
        r.executionTick = execTick;
        r.grossAmount   = outputAmt;
        r.feeAmount     = fee;
        r.feeCurrency   = feeCurrency;
        r.settleAfter   = block.timestamp + SETTLE_WINDOW;
        r.settled       = false;

        emit ProtectedSwap(rid, owner, r.poolId, execTick, outputAmt, fee, feeCurrency);

        // ── Step 6: Return hookDelta = fee so swapper pays via v4 accounting ──
        return (IHooks.afterSwap.selector, int128(int256(fee)));
    }

    // ─── Settlement ────────────────────────────────────────────────────────────

    /// @notice Settle a receipt after the 5-minute window; claim rebate if price moved against you.
    ///         Rebate (if any) is credited to the user's vault for the receipt's feeCurrency.
    ///         User must call withdraw(feeCurrency) to extract tokens.
    ///
    /// Rebate logic (tick comparison, no oracle):
    ///   ZeroForOne (sold token0): bad if settleTick > execTick (price went up = bought worse)
    ///   OneForZero (sold token1): bad if settleTick < execTick (price went down = sold worse)
    ///
    /// @param receiptId      Receipt to settle
    /// @param maxTickDelta Maximum allowed absolute tick movement at settlement.
    function settle(uint256 receiptId, uint256 maxTickDelta) external {
        Receipt storage r = receipts[receiptId];
        if (r.settleAfter == 0) revert ZeroReceipt();
        if (r.settled)           revert AlreadySettled();
        if (block.timestamp < r.settleAfter) revert SettleWindowNotOpen();

        (, int24 settleTick,,) = StateLibrary.getSlot0(
            IPoolManager(POOL_MANAGER),
            PoolId.wrap(r.poolId)
        );

        // Tick delta: |settleTick - executionTick| as unsigned
        uint256 tickDelta;
        unchecked {
            if (settleTick >= r.executionTick) {
                tickDelta = uint256(int256(settleTick) - int256(r.executionTick));
            } else {
                tickDelta = uint256(int256(r.executionTick) - int256(settleTick));
            }
        }
        if (tickDelta > maxTickDelta) {
            revert TickDeltaExceeded(maxTickDelta, tickDelta);
        }

        // Determine if user got bad execution
        bool badExecution = (r.direction == Direction.ZeroForOne)
            ? (settleTick > r.executionTick)
            : (settleTick < r.executionTick);

        uint256 rebate = badExecution ? r.feeAmount : 0;

        r.settled   = true;
        r.settledAt = block.timestamp;

        if (rebate > 0) {
            // Credit rebate to vault in the feeCurrency recorded in the receipt
            vault[r.owner][r.feeCurrency] += rebate;
            emit RebateClaimed(receiptId, r.owner, rebate, badExecution, settleTick, r.executionTick, r.feeCurrency);
        } else {
            emit NoRebate(receiptId, badExecution, settleTick, r.executionTick);
        }
    }

    // ─── Withdrawal ───────────────────────────────────────────────────────────

    /// @notice Withdraw accumulated vault balance for a specific currency.
    ///         Tokens are transferred directly from the hook contract to the caller.
    /// @param currency The currency to withdraw
    function withdraw(Currency currency) external {
        uint256 amount = vault[msg.sender][currency];
        if (amount == 0) revert NothingToWithdraw();
        vault[msg.sender][currency] = 0;
        CurrencyLibrary.transfer(currency, msg.sender, amount);
        emit Withdrawn(msg.sender, currency, amount);
    }

    // ─── Permission Helper ─────────────────────────────────────────────────────

    /// @notice Returns the hook's permission bitmap fields for documentation.
    function getHookPermissions() external pure returns (Hooks.Permissions memory p) {
        p.beforeInitialize              = false;
        p.afterInitialize               = false;
        p.beforeAddLiquidity            = false;
        p.afterAddLiquidity             = false;
        p.beforeRemoveLiquidity         = false;
        p.afterRemoveLiquidity          = false;
        p.beforeSwap                    = false;
        p.afterSwap                     = true;   // bit 6 = 0x40
        p.beforeDonate                  = false;
        p.afterDonate                   = false;
        p.beforeSwapReturnDelta         = false;
        p.afterSwapReturnDelta          = true;   // bit 2 = 0x04
        p.afterAddLiquidityReturnDelta = false;
        p.afterRemoveLiquidityReturnDelta = false;
    }

    // ─── View Functions ───────────────────────────────────────────────────────

    function getReceipt(uint256 id) external view returns (Receipt memory) { return receipts[id]; }

    /// @param user  Wallet address
    /// @param currency The currency to query
    function getVaultBalance(address user, Currency currency) external view returns (uint256) {
        return vault[user][currency];
    }

    // ─── Internal Helpers ─────────────────────────────────────────────────────

    /// @notice Read current tick from PoolManager via StateLibrary.
    function _currentTick(PoolId poolId) internal view returns (int24 tick) {
        (, tick,,) = StateLibrary.getSlot0(IPoolManager(POOL_MANAGER), poolId);
    }

    /// @notice Decode the real protected-swap owner from hookData when a router calls PoolManager.
    ///         Empty hookData keeps direct test/helper calls usable.
    function _receiptOwner(address sender, bytes calldata hookData) internal pure returns (address) {
        if (hookData.length == 0) return sender;
        if (hookData.length != 32) revert InvalidHookData();
        address owner = abi.decode(hookData, (address));
        if (owner == address(0)) revert InvalidHookData();
        return owner;
    }

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyFromPoolManager() {
        if (msg.sender != POOL_MANAGER) revert HookNotAuthorized();
        _;
    }

    // ─── Events ───────────────────────────────────────────────────────────────

    event ProtectedSwap(
        uint256 indexed receiptId,
        address indexed owner,
        bytes32 indexed poolId,
        int24  executionTick,
        uint256 grossOutput,
        uint256 feeCollected,
        Currency feeCurrency
    );

    event RebateClaimed(
        uint256 indexed receiptId,
        address indexed owner,
        uint256 rebateAmount,
        bool badExecution,
        int24 settleTick,
        int24 executionTick,
        Currency feeCurrency
    );

    event NoRebate(
        uint256 indexed receiptId,
        bool badExecution,
        int24 settleTick,
        int24 executionTick
    );

    event Withdrawn(
        address indexed user,
        Currency indexed currency,
        uint256 amount
    );
}
