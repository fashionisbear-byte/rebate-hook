# X Post Draft

## Final Single Post

Built RegretRebateHook for the X Layer / Uniswap Hook the Future Hackathon.

A Uniswap v4 Hook that turns protected swaps into on-chain execution quality rebate receipts.

Deployed on X Layer mainnet:
Hook: 0xF5fbcF77C79eB93f8bc7A1211f92797534488044
PoolId: 0x306406af8a828a36e9cc234e4236a6d5f026d1059b2cd5c9d0619216ae4b4711

Evidence:
Swap: 0xcd2214462f37aab02346d3086d786d42fc101439e01b4c85bc7b059e4ab49188
Settle: 0xe86f9b19cff96601dc3aa9e65a7a7756385dba794b1a4295f5eda728b1ff981f

Not insurance. A prototype for post-swap execution quality rebates using Uniswap v4 Hook accounting.

@XLayerOfficial @Uniswap @flapdotsh

#XLayer #UniswapV4 #DeFi #Hooks

## Shorter Version

RegretRebateHook is live on X Layer mainnet.

It is a Uniswap v4 Hook that charges a post-swap protection fee, records an on-chain receipt, and lets users settle execution quality rebates.

Hook:
0xF5fbcF77C79eB93f8bc7A1211f92797534488044

PoolId:
0x306406af8a828a36e9cc234e4236a6d5f026d1059b2cd5c9d0619216ae4b4711

Swap tx:
0xcd2214462f37aab02346d3086d786d42fc101439e01b4c85bc7b059e4ab49188

Settle tx:
0xe86f9b19cff96601dc3aa9e65a7a7756385dba794b1a4295f5eda728b1ff981f

@XLayerOfficial @Uniswap @flapdotsh

## Suggested Thread

### 1

RegretRebateHook is live on X Layer mainnet.

It is a Uniswap v4 Hook that turns protected swaps into on-chain execution quality rebate receipts.

@XLayerOfficial @Uniswap @flapdotsh

### 2

How it works:

1. User executes a protected swap.
2. `afterSwap` collects a 30 bps protection fee.
3. The Hook records a receipt with execution tick and fee data.
4. After 5 minutes, the user calls `settle(receiptId)`.

### 3

This is not insurance.

It is a deterministic post-swap rebate prototype:

- no oracle
- no off-chain claims
- no guaranteed payout
- receipt and settlement are verifiable on-chain

### 4

On-chain evidence:

Hook:
0xF5fbcF77C79eB93f8bc7A1211f92797534488044

PoolId:
0x306406af8a828a36e9cc234e4236a6d5f026d1059b2cd5c9d0619216ae4b4711

Swap:
0xcd2214462f37aab02346d3086d786d42fc101439e01b4c85bc7b059e4ab49188

Settle:
0xe86f9b19cff96601dc3aa9e65a7a7756385dba794b1a4295f5eda728b1ff981f
