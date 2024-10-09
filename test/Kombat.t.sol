//// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Kombat} from "src/Kombat.sol";
import {USDT} from "src/mocks/ERC20.sol";
// import {Permit2} from "lib/permit2/src/Permit2.sol";

contract KombatTest is Test {
    Kombat internal kombat;
    USDT internal usdt;
    address internal owner = makeAddr("owner");

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() external {
        kombat = new Kombat(address(owner));
        usdt = new USDT();
        vm.prank(owner);
        kombat.registerToken(address(usdt), true);
        usdt.mint(alice, 120_000 * 1e18);
        usdt.mint(bob, 120_000 * 1e18);
        vm.deal(alice, 200 ether);
        vm.deal(bob, 200 ether);
    }

    function _createBet(
        address[] memory _actors,
        string memory _betName,
        uint256 _betDuration,
        address _betCreator,
        address _betToken,
        uint256 _amount,
        bool useEth
    ) internal {
        kombat.createBet(_actors, _betName, _betDuration, _betCreator, _betToken, _amount, useEth);
    }

    function test_create_bet_token() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);

        vm.expectEmit();
        kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5000 * 1e18, false);
    }

    function test_create_bet_eth() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);

        vm.expectEmit();
        kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5000 * 1e18, true);
    }

    function test_enter_bet_token() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);
        uint256 id = kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5000 * 1e18, false);
        vm.startPrank(alice);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id);
        vm.stopPrank();

        assertEq(usdt.balanceOf(address(kombat)), 5000 * 1e18);
    }

    function test_enter_bet_eth() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);
        uint256 id = kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5 * 1e18, true);
        vm.startPrank(alice);
        kombat.enterBet{value: 5 * 1e18}(id);
        vm.stopPrank();

        assertEq(address(kombat).balance, 5 * 1e18);
    }

    //assertions
    function test_enter_win_no_dispute() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);
        uint256 id = kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5000 * 1e18, false);

        vm.startPrank(alice);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id);
        vm.stopPrank();

        vm.startPrank(bob);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id);
        vm.stopPrank();

        skip(2 days);
        vm.startPrank(alice);

        // vm.expectEmit();
        kombat.enterWin(id, true);
        vm.stopPrank();

        vm.startPrank(bob);

        // vm.expectEmit();
        kombat.enterWin(id, false);
        vm.stopPrank();
    }

    function test_enter_win_and_claim() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);
        uint256 id = kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5000 * 1e18, false);

        vm.startPrank(alice);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id);
        vm.stopPrank();

        vm.startPrank(bob);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id);
        vm.stopPrank();

        skip(2 days);
        vm.startPrank(alice);
        kombat.enterWin(id, true);
        vm.stopPrank();

        vm.startPrank(bob);
        kombat.enterWin(id, false);
        vm.stopPrank();

        vm.startPrank(alice);
        kombat.claim(id);
        vm.stopPrank();
    }

    function test_dispute() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);
        uint256 id = kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5000 * 1e18, false);

        vm.startPrank(alice);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id);
        vm.stopPrank();

        vm.startPrank(bob);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id);
        vm.stopPrank();

        skip(2 days);
        vm.startPrank(alice);
        kombat.enterWin(id, true);
        vm.stopPrank();

        vm.startPrank(bob);
        kombat.enterWin(id, false);
        vm.stopPrank();
    }

    function test_dispute_solve_and_slashed() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);
        uint256 id = kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5000 * 1e18, false);

        vm.startPrank(alice);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id);
        vm.stopPrank();

        vm.startPrank(bob);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id);
        vm.stopPrank();

        skip(2 days);
        vm.startPrank(alice);
        kombat.enterWin(id, true);
        vm.stopPrank();

        vm.startPrank(bob);
        kombat.enterWin(id, false);
        vm.stopPrank();
    }

    function test_dispute_solved_wim() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);
        uint256 id = kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5000 * 1e18, false);

        vm.startPrank(alice);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id);
        vm.stopPrank();

        vm.startPrank(bob);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id);
        vm.stopPrank();

        skip(2 days);
        vm.startPrank(alice);
        kombat.enterWin(id, true);
        vm.stopPrank();

        vm.startPrank(bob);
        kombat.enterWin(id, false);
        vm.stopPrank();
    }
}
