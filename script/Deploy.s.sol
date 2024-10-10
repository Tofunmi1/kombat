//// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Kombat} from "src/Kombat.sol";
import {Script} from "forge-std/Script.sol";
import {console2} from "lib/forge-std/src/console2.sol";

contract Deploy is Script {
    Kombat internal kombat;
    address internal owner = address(0x509536FB08B977aF9Ff7726692Cc449885F7F93b);
    address internal usdc = address(0xaf6264B2cc418d17F1067ac8aC8687aae979D5e5);

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        kombat = new Kombat(owner);
        kombat.registerToken(usdc, true);
        vm.stopBroadcast();
        console2.log("kombat address deplyoed to : ", address(kombat));
    }
}
