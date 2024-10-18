//// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {USDT} from "src/mocks/ERC20.sol";

contract DeployUSDT is Script {
    USDT internal usdt;

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        usdt = new USDT();
        vm.stopBroadcast();
    }
}

contract MintUSDT is Script {
    USDT internal usdt;

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        usdt = USDT(0xdED49a85D3463102355E22562c40414505702efa);
        usdt.mint(address(0xa75aC8aeE6654E32d9C61FFD629a97b46E2Ed442), 100_000 * 1e18);
        vm.stopPrank();
    }
}
