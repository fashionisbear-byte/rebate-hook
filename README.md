# RegretRebateHook

Execution quality rebates for protected swaps on Uniswap v4, deployed on X Layer.

This project was built for the X Layer / Uniswap Hook the Future Hackathon.

## Summary

RegretRebateHook is a Uniswap v4 Hook that turns a protected swap into an on-chain settlement receipt.

On each protected swap:

1. `afterSwap` charges a 30 bps protection fee using Uniswap v4 hook delta accounting.
2. The Hook records a receipt with owner, pool, swap direction, execution tick, output amount, fee amount, fee currency, and settlement window.
3. After 5 minutes, the user calls `settle(receiptId, maxTickDelta)`.
4. If the pool tick moved against the swap direction, the receipt can credit a rebate. If not, the receipt is still settled on-chain with no rebate.

This is not insurance. It is a prototype for post-swap execution quality rebates using verifiable Uniswap v4 Hook state.

## On-Chain Deployment

Network: X Layer mainnet  
Chain ID: 196  
Explorer: https://www.oklink.com/xlayer  
PoolManager: `0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32`

| Component | Address / ID |
| --- | --- |
| Deployer | `0x39699c011d062dbdB058a81644e40002E88E5Ce8` |
| Token0 | `0x6E7740D9dbA934811FC891dD370723CDfC8c06f5` |
| Token1 | `0xca7A320788088a333Cfe93B4C6d3035D03759779` |
| RegretRebateHook | `0xF5fbcF77C79eB93f8bc7A1211f92797534488044` |
| PoolId | `0x306406af8a828a36e9cc234e4236a6d5f026d1059b2cd5c9d0619216ae4b4711` |
| Liquidity helper | `0xFFE73a1e0fb90FE554871d086A731dD3C5a22A88` |
| Swap helper | `0xE7041D28153597DDc8Aac3A89Fb98C6D5e52144E` |

## Transaction Evidence

| Action | Tx hash |
| --- | --- |
| Deploy Token0 | `0x63ce2628b3dff0eed8e77754408111f9155dcd8b5751bcae5ec35e368276935b` |
| Deploy Token1 | `0x62c744bd379fd9117896dde348812c2b72e5e10f38c33851598dd565a4472e05` |
| Deploy RegretRebateHook | `0xdbabcc1f65c63ba6153b8f1efa31d6b7b876698f57e214ea4ea4c25932a48b6b` |
| Initialize pool | `0x689b1d7b620503ca06fe6c9e3addc06b33047847e0d614c09f9f622e31bf3c93` |
| Deploy liquidity helper | `0x10483010db143bc67a3b029b26b457372c0c37d3007d345a1512290e4ca15e00` |
| Deploy swap helper | `0x35ed746ecbe607461cfa11b2692b69ff77bf9147f0079c11868ad33c9cfffb5d` |
| Approve liquidity helper, token0 | `0xdff313338f2867f5bf1e0fcca89005d361d5c3ad265a95287a7c536e6478e785` |
| Approve liquidity helper, token1 | `0x1d4ba7d2309428ceb50a91d85b1da2c31be25132eebbb9211e52bd6aaea8eaa3` |
| Add liquidity | `0xd94437fde4f3f7e8a8c589c6d3a04d718577e645c81c73cae27f375ba4ee420c` |
| Approve swap helper, token0 | `0x07eee1b5320bb8d9b17aa0ee89fe7d30a2315dffec978f14d226560db33fb7ef` |
| Approve swap helper, token1 | `0x4a40ceefacb41524fa9ca7f1fbeb59ed18687cf47499f301d51ae705dabe2065` |
| Protected swap | `0xcd2214462f37aab02346d3086d786d42fc101439e01b4c85bc7b059e4ab49188` |
| Settle receipt | `0xe86f9b19cff96601dc3aa9e65a7a7756385dba794b1a4295f5eda728b1ff981f` |
| Withdraw | N/A, settlement produced no rebate and vault balance stayed `0` |

## Verified Receipt

Receipt ID: `0`

Settlement output:

```text
Owner: 0x39699c011d062dbdB058a81644e40002E88E5Ce8
Fee amount: 29614741031911
Fee currency: 0xca7A320788088a333Cfe93B4C6d3035D03759779
ExecutionTick: -199
SettleTick: -199
Settled: true
Vault balance: 0
```

This run demonstrates the full on-chain flow: Hook deployment, v4 Pool initialization, liquidity provision, protected swap, receipt creation, and receipt settlement. The settle path was a no-rebate case because the execution tick and settlement tick were equal.

## Hook Permissions

The deployed Hook address was mined with CREATE2 so the full Uniswap v4 Hook permission bitmap is exactly:

```text
0x44 = AFTER_SWAP_FLAG | AFTER_SWAP_RETURNS_DELTA_FLAG
```

Only `afterSwap` and `afterSwapReturnDelta` are enabled. A previous candidate address was discarded because it had extra permission bits.

## Core Contracts

| File | Purpose |
| --- | --- |
| `src/RegretRebateHook.sol` | Main Uniswap v4 Hook. Collects fee, records receipt, settles rebate, supports withdraw. |
| `src/MockERC20.sol` | Demo ERC20 token used for the deployed X Layer pool. |
| `src/ProtectedSwapRouter.sol` | Development scaffold, not used as the final submitted swap path. |
| `script/SubmitFlowEnv.s.sol` | Environment-driven deployment and demo scripts for the submission flow. |
| `script/DeployRegretRebateHook.s.sol` | CREATE2 deployment script with exact hook bitmap validation. |

## Reproduce Locally

Install Foundry, then:

```bash
forge build
forge test -vv
```

Expected result:

```text
25 passed, 0 failed, 6 skipped
```

## Reproduce On X Layer

Set these environment variables in PowerShell:

```powershell
$env:X_LAYER_RPC_URL="https://rpc.xlayer.tech"
$env:DEPLOYER_PRIVATE_KEY="YOUR_PRIVATE_KEY"
$env:TOKEN0="0x6E7740D9dbA934811FC891dD370723CDfC8c06f5"
$env:TOKEN1="0xca7A320788088a333Cfe93B4C6d3035D03759779"
$env:HOOK_ADDRESS="0xF5fbcF77C79eB93f8bc7A1211f92797534488044"
$env:LIQUIDITY_HELPER="0xFFE73a1e0fb90FE554871d086A731dD3C5a22A88"
$env:SWAP_HELPER="0xE7041D28153597DDc8Aac3A89Fb98C6D5e52144E"
```

Key scripts:

```powershell
forge script script/SubmitFlowEnv.s.sol:ProtectedDemoSwap --rpc-url $env:X_LAYER_RPC_URL --broadcast -vv

$env:RECEIPT_ID="0"
forge script script/SubmitFlowEnv.s.sol:SettleDemoReceipt --rpc-url $env:X_LAYER_RPC_URL --broadcast -vv
```

For a fresh deployment, use the scripts in this order:

1. `DeployDemoTokens`
2. `DeployRegretRebateHook`
3. `InitializeDemoPool`
4. `DeployDemoHelpers`
5. `ApproveDemoSpender`
6. `AddDemoLiquidity`
7. `ApproveDemoSpender`
8. `ProtectedDemoSwap`
9. `SettleDemoReceipt`

## Risk Boundaries

- Prototype only; not audited.
- Not insurance and not a guaranteed payout product.
- No oracle is used; settlement is based on pool tick comparison.
- Rebate availability is bounded by collected fees and contract balance.
- The submitted demo uses mock ERC20 tokens on X Layer mainnet to avoid dependency on external token liquidity.
- The final submitted swap uses the v4 PoolManager path through helper contracts, not a front-end simulation.

## License

MIT
