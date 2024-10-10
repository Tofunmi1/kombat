//// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20Permit} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20Permit {
    address internal owner;

    constructor() ERC20("", "") ERC20Permit("") {}

    function mintTo(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
