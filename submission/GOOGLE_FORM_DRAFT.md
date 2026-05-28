# Google Form Draft

## Project Name

RegretRebateHook

## Tagline

Execution quality rebates for protected swaps on Uniswap v4.

## Short Description

RegretRebateHook is a Uniswap v4 Hook deployed on X Layer mainnet. It collects a protection fee in `afterSwap`, records a protected swap receipt, and lets users settle the receipt after a short time window. If pool tick movement shows adverse short-term execution, the Hook can credit a rebate; otherwise the receipt settles with no rebate.

## Long Description

RegretRebateHook explores a new DeFi primitive: post-swap execution quality rebates. Instead of building an insurance product or an off-chain claims flow, the mechanism lives inside the Uniswap v4 Hook lifecycle.

When a protected swap executes, `afterSwap` identifies the output currency, calculates a 30 bps protection fee, takes the fee through PoolManager accounting, returns hook delta, and records a receipt. The receipt stores the user, pool, direction, execution tick, fee amount, fee currency, and settlement window.

After the settlement window, the user calls `settle(receiptId, maxTickDelta)`. The Hook reads the current pool tick and compares it with the recorded execution tick. If the movement was adverse for the swap direction, a rebate can be credited to the user's per-currency vault balance. If not, the receipt is still settled on-chain with no rebate.

The submitted deployment demonstrates the complete on-chain path on X Layer mainnet: Hook deployment, v4 Pool initialization, liquidity provision, protected swap, receipt creation, and settlement.

## Category

DeFi

## Network

X Layer mainnet, chain ID 196

## Deployed Contracts

PoolManager:
`0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32`

RegretRebateHook:
`0xF5fbcF77C79eB93f8bc7A1211f92797534488044`

PoolId:
`0x306406af8a828a36e9cc234e4236a6d5f026d1059b2cd5c9d0619216ae4b4711`

Token0:
`0x6E7740D9dbA934811FC891dD370723CDfC8c06f5`

Token1:
`0xca7A320788088a333Cfe93B4C6d3035D03759779`

## Transaction Hashes

Deploy Hook:
`0xdbabcc1f65c63ba6153b8f1efa31d6b7b876698f57e214ea4ea4c25932a48b6b`

Initialize Pool:
`0x689b1d7b620503ca06fe6c9e3addc06b33047847e0d614c09f9f622e31bf3c93`

Add Liquidity:
`0xd94437fde4f3f7e8a8c589c6d3a04d718577e645c81c73cae27f375ba4ee420c`

Protected Swap:
`0xcd2214462f37aab02346d3086d786d42fc101439e01b4c85bc7b059e4ab49188`

Settle:
`0xe86f9b19cff96601dc3aa9e65a7a7756385dba794b1a4295f5eda728b1ff981f`

ReceiptId:
`0`

Settlement result:
No rebate in this run. `ExecutionTick = -199`, `SettleTick = -199`, vault balance `0`. The receipt was settled on-chain.

## Repository URL

https://github.com/fashionisbear-byte/rebate-hook

## Demo Video URL

TODO: paste video URL if available.

## X Post URL

TODO: paste final X post URL after posting.

## Team

TODO: fill team name, member names, and contact.

## Risk Statement

This is a hackathon prototype, not audited and not production insurance. It does not guarantee payouts. Rebate behavior depends on pool state, tick movement, and available funds.
