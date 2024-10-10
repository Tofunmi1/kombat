//// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {USDC} from "src/mocks/USDC.sol";
import {Script} from "forge-std/Script.sol";
import {console2} from "lib/forge-std/src/console2.sol";

contract DeployUSDcPermit2 is Script {
    USDC internal usdc;

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        usdc = new USDC();
        vm.stopBroadcast();
        console2.log("usdc address deplyed to : ", address(usdc));
    }
}

contract MintUSDT is Script {
    USDC internal usdc;

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        usdc = USDC(0xaf6264B2cc418d17F1067ac8aC8687aae979D5e5);
        usdc.mintTo(address(0x509536FB08B977aF9Ff7726692Cc449885F7F93b), 100_000 * 1e18);
        vm.stopBroadcast();
    }
}
