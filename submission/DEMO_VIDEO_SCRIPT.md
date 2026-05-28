# Demo Video Script

Target length: 60 to 90 seconds.

## Scene 1: Problem

Narration:

When a DEX swap gets poor short-term execution, users usually have no on-chain recourse. RegretRebateHook explores a small, verifiable rebate primitive directly inside Uniswap v4.

Show:

- Project README
- Contract name: RegretRebateHook

## Scene 2: Mechanism

Narration:

The Hook runs in `afterSwap`. It collects a 30 bps protection fee, records a protected swap receipt, and stores execution tick, fee currency, fee amount, user, and settlement time.

Show:

- `src/RegretRebateHook.sol`
- `afterSwap`
- `ProtectedSwap` event

## Scene 3: On-Chain Deployment

Narration:

The Hook is deployed on X Layer mainnet and attached to a Uniswap v4 pool.

Show:

```text
Network: X Layer mainnet
Hook: 0xF5fbcF77C79eB93f8bc7A1211f92797534488044
PoolId: 0x306406af8a828a36e9cc234e4236a6d5f026d1059b2cd5c9d0619216ae4b4711
```

## Scene 4: Protected Swap

Narration:

This transaction executes a protected swap through the v4 PoolManager path and creates receipt ID 0.

Show:

```text
Protected Swap Tx:
0xcd2214462f37aab02346d3086d786d42fc101439e01b4c85bc7b059e4ab49188

ReceiptId: 0
```

## Scene 5: Settlement

Narration:

After the 5-minute window, the user settles the receipt. In this demo, the execution tick and settlement tick were both `-199`, so the receipt settles as a no-rebate case. The important part is that receipt creation and settlement are both on-chain and verifiable.

Show:

```text
Settle Tx:
0xe86f9b19cff96601dc3aa9e65a7a7756385dba794b1a4295f5eda728b1ff981f

ExecutionTick: -199
SettleTick: -199
Vault balance: 0
Settled: true
```

## Scene 6: Closing

Narration:

This is a hackathon prototype, not insurance and not audited. It demonstrates a new Hook-native settlement receipt for execution quality rebates on X Layer.

Show:

```text
@XLayerOfficial @Uniswap @flapdotsh
```
