// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {
    event Mint(address to, uint256 amount);

    constructor() ERC20("usd tether", "usdt") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
        emit Mint(to, amount);
    }
}
