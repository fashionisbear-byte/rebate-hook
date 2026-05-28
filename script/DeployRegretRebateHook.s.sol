// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {RegretRebateHook} from "../src/RegretRebateHook.sol";

// 鈹€鈹€鈹€ Constants 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
// CREATE2_FACTORY is declared in forge-std/StdConfig.sol and accessible globally.
// It is the address of the CREATE2 factory used by forge-std for deterministic
// deployments. On mainnets that support EIP-1014, this factory is pre-deployed at
// 0x4e59b44847b379578588920cA78FbF26c0B4956C on Ethereum.
// For X Layer, verify this address is correct for the target chain before deploying.

// 鈹€鈹€鈹€ Shared 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
address constant POOL_MANAGER = 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
uint160 constant PERMISSIONS = 0x0044; // afterSwap(0x40) | afterSwapReturnDelta(0x04)
uint160 constant ALL_HOOK_MASK = uint160((1 << 14) - 1);

// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
//  Salt-finding: pure local computation, NO broadcast, NO RPC writes.
//  Run:  forge script script/DeployRegretRebateHook.s.sol:FindRegretRebateHookSalt
//        --rpc-url http://localhost:8545
//  (On Anvil the broadcast does nothing; on mainnet it would cost gas.)
// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
contract FindRegretRebateHookSalt is Script {
    function run() external {
        console2.log("=== Find Valid Salt for RegretRebateHook ===");
        console2.log("Searching for address bits = 0x44 (afterSwap + afterSwapReturnDelta)...");
        console2.log("CREATE2_FACTORY:", CREATE2_FACTORY);
        console2.log("");

        bytes memory initCode = abi.encodePacked(
            type(RegretRebateHook).creationCode,
            abi.encode(IPoolManager(POOL_MANAGER))
        );

        // NOTE: vm.broadcast() is called so forge script can run on Anvil.
        // On mainnet FORK, this does NOT send a transaction 鈥?it only affects
        // the RPC simulation context. To use on a real chain, remove --broadcast.
        vm.startBroadcast(vm.envUint("FIND_PRIVATE_KEY"));

        uint256 found = 0;
        for (uint256 i = 0; i <= 100_000; i++) {
            bytes32 salt = keccak256(abi.encode(PERMISSIONS, address(0), i));
            address predicted = _create2Address(CREATE2_FACTORY, salt, initCode);

            if ((uint160(predicted) & ALL_HOOK_MASK) == PERMISSIONS) {
                console2.log("FOUND at index", i);
                console2.log("  EXTRA_SALT:       ", i);
                console2.log("  Salt:             "); console2.logBytes32(salt);
                console2.log("  Predicted addr:  ", predicted);
                console2.log("  afterSwap bit:   ", (uint160(predicted) & 0x40) != 0 ? "SET" : "NOT SET");
                console2.log("  returnDelta bit: ", (uint160(predicted) & 0x04) != 0 ? "SET" : "NOT SET");
                console2.log("");
                found++;
                if (found >= 3) break;
            }
        }

        if (found == 0) {
            console2.log("No matching salt in 0-100000. Increase the loop range.");
        } else {
            console2.log("Set EXTRA_SALT to the desired index, then run DeployRegretRebateHook.");
        }

        vm.stopBroadcast();
    }

    function _create2Address(address factory, bytes32 salt, bytes memory initCode)
        internal
        pure
        returns (address)
    {
        return address(
            uint160(
                uint256(keccak256(abi.encodePacked(
                    bytes1(0xff),
                    factory,
                    salt,
                    keccak256(initCode)
                ))) & 0x0000ffffffffffffffffffffffffffffffffffffffff
            )
        );
    }
}

// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
//  PredictHookAddress: print predicted CREATE2 address WITHOUT any transaction.
//  Run dry-run (no --broadcast):
//    forge script script/DeployRegretRebateHook.s.sol:PredictHookAddress
//        --rpc-url $X_LAYER_RPC_URL
// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
contract PredictHookAddress is Script {
    // Note: Set this before running
    uint256 constant EXTRA_SALT = 25996;

    function run() external view {
        bytes memory initCode = abi.encodePacked(
            type(RegretRebateHook).creationCode,
            abi.encode(IPoolManager(POOL_MANAGER))
        );

        bytes32 salt = keccak256(abi.encode(PERMISSIONS, address(0), EXTRA_SALT));
        address predicted = _create2Address(CREATE2_FACTORY, salt, initCode);

        console2.log("=== Predict RegretRebateHook CREATE2 Address ===");
        console2.log("PoolManager:      ", POOL_MANAGER);
        console2.log("CREATE2_FACTORY: ", CREATE2_FACTORY);
        console2.log("Permissions:      ", "0x44");
        console2.log("EXTRA_SALT:      ", EXTRA_SALT);
        console2.log("Salt:            "); console2.logBytes32(salt);
        console2.log("Predicted addr: ", predicted);
        console2.log("afterSwap bit:  ", (uint160(predicted) & 0x40) != 0 ? "SET [OK]" : "MISSING [FAIL]");
        console2.log("returnDelta bit:", (uint160(predicted) & 0x04) != 0 ? "SET [OK]" : "MISSING [FAIL]");
        console2.log("");
        console2.log("Is full hook bitmap exactly 0x44?", (uint160(predicted) & ALL_HOOK_MASK) == PERMISSIONS ? "YES [OK]" : "NO [FAIL]");

        require(
            (uint160(predicted) & ALL_HOOK_MASK) == PERMISSIONS,
            "Permission bits mismatch. Run FindRegretRebateHookSalt to find a valid EXTRA_SALT."
        );
    }

    function _create2Address(address factory, bytes32 salt, bytes memory initCode)
        internal
        pure
        returns (address)
    {
        return address(
            uint160(
                uint256(keccak256(abi.encodePacked(
                    bytes1(0xff),
                    factory,
                    salt,
                    keccak256(initCode)
                ))) & 0x0000ffffffffffffffffffffffffffffffffffffffff
            )
        );
    }
}

// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
//  DeployRegretRebateHook
//
//  Prerequisites (MUST be done before this step):
//    1. Run FindRegretRebateHookSalt 鈫?note EXTRA_SALT value
//       (forge script script/DeployRegretRebateHook.s.sol:FindRegretRebateHookSalt
//        --rpc-url http://localhost:8545)
//    2. Set EXTRA_SALT constant below to the found value
//    3. Set env vars:
//         export DEPLOYER_PRIVATE_KEY=0x...
//         export X_LAYER_RPC_URL=https://...
//    4. Verify wallet has XLAYER native token for gas
//
//  Dry-run (estimates gas, no broadcast):
//    forge script script/DeployRegretRebateHook.s.sol:DeployRegretRebateHook
//        --rpc-url $X_LAYER_RPC_URL -vv
//
//  Real broadcast:
//    forge script script/DeployRegretRebateHook.s.sol:DeployRegretRebateHook
//        --rpc-url $X_LAYER_RPC_URL --broadcast -vv
// 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
contract DeployRegretRebateHook is Script {
    // Note: Set this to the extraSalt found by FindRegretRebateHookSalt
    uint256 constant EXTRA_SALT = 25996;

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        string memory rpcUrl = vm.envString("X_LAYER_RPC_URL");

        console2.log("=== Deploy RegretRebateHook on X Layer ===");
        console2.log("PoolManager:      ", POOL_MANAGER);
        console2.log("CREATE2_FACTORY: ", CREATE2_FACTORY);
        console2.log("Permissions:      0x44 (afterSwap + afterSwapReturnDelta)");
        console2.log("EXTRA_SALT:      ", EXTRA_SALT);

        // 鈹€鈹€ Build initCode 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        bytes memory initCode = abi.encodePacked(
            type(RegretRebateHook).creationCode,   // creationCode, NOT runtimeCode
            abi.encode(IPoolManager(POOL_MANAGER)) // constructor arg
        );

        // 鈹€鈹€ Compute salt 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        bytes32 salt = keccak256(abi.encode(PERMISSIONS, address(0), EXTRA_SALT));
        console2.log("Salt:            "); console2.logBytes32(salt);

        // 鈹€鈹€ Predict address (offline, no RPC needed) 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        address predicted = _create2Address(CREATE2_FACTORY, salt, initCode);
        console2.log("Predicted addr: ", predicted);
        console2.log("afterSwap bit:  ", (uint160(predicted) & 0x40) != 0 ? "SET [OK]" : "MISSING [FAIL]");
        console2.log("returnDelta bit:", (uint160(predicted) & 0x04) != 0 ? "SET [OK]" : "MISSING [FAIL]");

        // 鈹€鈹€ Guard: permission bits must match 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        require(
            (uint160(predicted) & ALL_HOOK_MASK) == PERMISSIONS,
            "Permission bits mismatch. EXTRA_SALT may be wrong. Re-run FindRegretRebateHookSalt."
        );
        console2.log("Permission bitmap verified: exactly 0x44 [OK]");
        console2.log("");

        // 鈹€鈹€ Deploy 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
        vm.startBroadcast(deployerKey);
        RegretRebateHook hook = new RegretRebateHook{salt: salt}(IPoolManager(POOL_MANAGER));
        vm.stopBroadcast();

        console2.log("Deployed! Address:", address(hook));
        require(address(hook) == predicted, "CREATE2 address mismatch - check factory address");
        console2.log("");
        console2.log("=== Deployment Successful ===");
        console2.log("NEXT: Record HOOK_ADDRESS =", address(hook));
        console2.log("Run InitializePool.s.sol to create the first protected pool.");
    }

    /// @dev CREATE2 address: last 20 bytes of keccak256(0xff + factory + salt + keccak256(initCode))
    function _create2Address(address factory, bytes32 salt, bytes memory initCode)
        internal
        pure
        returns (address)
    {
        return address(
            uint160(
                uint256(keccak256(abi.encodePacked(
                    bytes1(0xff),
                    factory,
                    salt,
                    keccak256(initCode)
                ))) & 0x0000ffffffffffffffffffffffffffffffffffffffff
            )
        );
    }
}

