//// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Kombat, DisputeParams, Bet} from "src/Kombat.sol";
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

    function test_dispute_solve_and_slashed() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);
        uint256 id = kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5000 * 1e18, false);

        vm.startPrank(alice);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id, true);
        vm.stopPrank();

        vm.startPrank(bob);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id, true);
        vm.stopPrank();

        ///both parties claiming they won would open dispute automatically
        skip(2 days);
        vm.startPrank(alice);
        kombat.enterWin(id, true);
        vm.stopPrank();

        vm.startPrank(bob);
        kombat.enterWin(id, true);
        vm.stopPrank();

        vm.expectRevert(Kombat.Disputed.selector);
        vm.prank(alice);
        kombat.claim(id);

        uint256 aliceBalBefore = usdt.balanceOf(alice);
        uint256 bobBalBefore = usdt.balanceOf(bob);

        vm.startPrank(owner);
        DisputeParams memory _disputeParams = DisputeParams({
            betId: id,
            winner: address(0), //dispute not resolved
            toggleDispute: true,
            slashRewards: true
        });
        kombat.solveDispute(_disputeParams);

        uint256 aliceBalAfter = usdt.balanceOf(alice);
        uint256 bobBalAfter = usdt.balanceOf(bob);

        assertEq(aliceBalAfter - aliceBalBefore, 2500 * 1e18);
        assertEq(bobBalAfter - bobBalBefore, 2500 * 1e18);
    }

    function test_create_bet_token() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);

        // vm.expectEmit();
        kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5000 * 1e18, false);
    }

    function test_create_bet_eth() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);

        // vm.expectEmit();
        kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5000 * 1e18, true);
    }

    function test_enter_bet_token() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);
        uint256 id = kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5000 * 1e18, false);
        vm.startPrank(alice);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id, true);
        vm.stopPrank();

        assertEq(usdt.balanceOf(address(kombat)), 5000 * 1e18);
    }

    function test_enter_bet_eth() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);
        uint256 id = kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5 * 1e18, true);
        vm.startPrank(alice);
        kombat.enterBet{value: 5 * 1e18}(id, true);
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
        kombat.enterBet(id, true);
        vm.stopPrank();

        vm.startPrank(bob);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id, true);
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
        kombat.enterBet(id, true);
        vm.stopPrank();

        vm.startPrank(bob);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id, true);
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

    function test_dispute_claim_fail() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);
        uint256 id = kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5000 * 1e18, false);

        vm.startPrank(alice);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id, true);
        vm.stopPrank();

        vm.startPrank(bob);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id, true);
        vm.stopPrank();

        ///both parties claiming they won would open dispute automatically
        skip(2 days);
        vm.startPrank(alice);
        kombat.enterWin(id, true);
        vm.stopPrank();

        vm.startPrank(bob);
        kombat.enterWin(id, true);
        vm.stopPrank();

        vm.expectRevert(Kombat.Disputed.selector);
        vm.prank(alice);
        kombat.claim(id);
    }

    function test_dispute_solved_wim() external {
        address[] memory _actors = new address[](2);
        (_actors[0], _actors[1]) = (alice, bob);
        uint256 id = kombat.createBet(_actors, "test bet", 2 days, owner, address(usdt), 5000 * 1e18, false);

        vm.startPrank(alice);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id, true);
        vm.stopPrank();

        vm.startPrank(bob);
        usdt.approve(address(kombat), type(uint128).max);
        kombat.enterBet(id, true);
        vm.stopPrank();

        ///both parties claiming they won would open dispute automatically
        skip(2 days);
        vm.startPrank(alice);
        kombat.enterWin(id, true);
        vm.stopPrank();

        vm.startPrank(bob);
        kombat.enterWin(id, true);
        vm.stopPrank();

        vm.expectRevert(Kombat.Disputed.selector);
        vm.prank(alice);
        kombat.claim(id);

        vm.startPrank(owner);
        DisputeParams memory _disputeParams = DisputeParams({
            betId: id,
            winner: address(alice), //dispute resolved
            toggleDispute: true,
            slashRewards: false
        });
        kombat.solveDispute(_disputeParams);
    }
}
