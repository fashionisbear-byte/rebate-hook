# RegretRebateHook Submission Draft

## Project Name

RegretRebateHook

## One-Liner

A Uniswap v4 Hook on X Layer that turns protected swaps into on-chain execution quality rebate receipts.

## Description

RegretRebateHook is a DeFi Hook prototype for Uniswap v4. It collects a small post-swap protection fee in `afterSwap`, records a protected swap receipt, and lets the user settle that receipt after a short time window.

The receipt stores the owner, pool, direction, execution tick, gross output amount, fee amount, fee currency, and settlement time. At settlement, the Hook compares the execution tick with the current pool tick. If the movement was adverse for the user's swap direction, the Hook can credit a rebate. If not, the receipt is settled with no rebate.

This is not insurance. It is an on-chain execution quality rebate primitive using Uniswap v4 Hook accounting.

## Category

DeFi

## Network

X Layer mainnet, chain ID 196

## Contracts and Pool

| Component | Value |
| --- | --- |
| PoolManager | `0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32` |
| RegretRebateHook | `0xF5fbcF77C79eB93f8bc7A1211f92797534488044` |
| Token0 | `0x6E7740D9dbA934811FC891dD370723CDfC8c06f5` |
| Token1 | `0xca7A320788088a333Cfe93B4C6d3035D03759779` |
| PoolId | `0x306406af8a828a36e9cc234e4236a6d5f026d1059b2cd5c9d0619216ae4b4711` |
| Deployer | `0x39699c011d062dbdB058a81644e40002E88E5Ce8` |

## Required Transaction Evidence

| Action | Tx hash |
| --- | --- |
| Deploy Hook | `0xdbabcc1f65c63ba6153b8f1efa31d6b7b876698f57e214ea4ea4c25932a48b6b` |
| Initialize Pool | `0x689b1d7b620503ca06fe6c9e3addc06b33047847e0d614c09f9f622e31bf3c93` |
| Add Liquidity | `0xd94437fde4f3f7e8a8c589c6d3a04d718577e645c81c73cae27f375ba4ee420c` |
| Protected Swap | `0xcd2214462f37aab02346d3086d786d42fc101439e01b4c85bc7b059e4ab49188` |
| Settle | `0xe86f9b19cff96601dc3aa9e65a7a7756385dba794b1a4295f5eda728b1ff981f` |
| Withdraw | N/A, this run settled as no rebate with vault balance `0` |

## Receipt Evidence

Receipt ID: `0`

```text
Fee amount: 29614741031911
Fee currency: 0xca7A320788088a333Cfe93B4C6d3035D03759779
ExecutionTick: -199
SettleTick: -199
Settled: true
Vault balance: 0
```

## Innovation

Most swap protection systems are off-chain promises, fee-adjustment variants, points systems, or insurance-style narratives. RegretRebateHook keeps the mechanism inside the Uniswap v4 Hook lifecycle:

- The fee is charged through `afterSwap` and returned hook delta.
- The receipt is contract state and event evidence.
- Settlement is deterministic and on-chain.
- The flow is auditable without an oracle or off-chain adjudicator.

## Risk Boundaries

- Prototype only; not audited.
- No guaranteed payouts.
- Not insurance.
- Rebate depends on pool tick movement and available funds.
- Demo uses mock ERC20 tokens deployed on X Layer mainnet.

## Repository URL

Note: add public GitHub repository URL.

## Demo Video URL

Note: add video URL if recorded before submission.

