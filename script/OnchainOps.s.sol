//// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {Kombat} from "src/Kombat.sol";
import {USDC} from "src/mocks/USDC.sol";

contract CreateBet is Script {
    Kombat internal kombat = Kombat(payable(0x4432fCE60bbC8dB0a34F722c7e5F89FB7F74a944));
    USDC internal usdc = USDC(0xaf6264B2cc418d17F1067ac8aC8687aae979D5e5);

    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) =
            (0xeb3d24fc850ab358616e29C7B89AB630629E1a37, 0xFA2ebA13c9E42f1dC3F7dE513dE5F95160dd2371);
        kombat.createBet(
            _actors, "test bet", 2 days, 0xeb3d24fc850ab358616e29C7B89AB630629E1a37, address(usdc), 5000 * 1e18, false
        );

        vm.stopBroadcast();
    }
}

///populate data for frontEnd
contract CreateMultipleBets is Script {
    Kombat internal kombat = Kombat(payable(0x4432fCE60bbC8dB0a34F722c7e5F89FB7F74a944));
    USDC internal usdc = USDC(0xaf6264B2cc418d17F1067ac8aC8687aae979D5e5);

    function run() external {
        uint256 noOfBetsToCreate = 10;
        address[] memory _actors = new address[](2);
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        (_actors[0], _actors[1]) =
            (0xeb3d24fc850ab358616e29C7B89AB630629E1a37, 0xFA2ebA13c9E42f1dC3F7dE513dE5F95160dd2371);

        for (uint256 i; i < noOfBetsToCreate; ++i) {
            (_actors[0], _actors[1]) = (
                makeAddr(string(abi.encode(i * 12_000_000 << 12))),
                makeAddr(string((abi.encode(2 * i * 12_000_000 << 160))))
            );
            kombat.createBet(
                _actors,
                "testing",
                2 days,
                0xeb3d24fc850ab358616e29C7B89AB630629E1a37,
                address(usdc),
                5000 * 1e18,
                false
            );
        }
        vm.stopBroadcast();
    }
}
