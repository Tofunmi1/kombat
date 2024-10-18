//// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "src/lib/Reentrancy.sol";
import {KombatStorage} from "src/KombatStorage.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IPermit2} from "src/interfaces/IPermit2.sol";

struct Bet {
    address[] actors;
    uint256 startTimeStamp;
    uint256 endTimeStamp;
    address betCreator;
    string betName;
    uint256 betId;
    IERC20 betToken;
    uint256 amount;
    address winner;
    bool betDisputed;
    bool betClaimed;
    bool rejected;
}

struct DisputeParams {
    uint256 betId;
    address winner;
    bool toggleDispute;
    bool slashRewards;
}

///@dev Kombat smart contract , the Owner address take the signed transactions on the frontEnd and executes it on the behalf of the user, helps for Gasless transactions
///@dev Also uses Permit2 for gasLess token transfers
contract Kombat is KombatStorage, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IPermit2 constant permit2 = IPermit2(address(0xdeadbeef123456789)); //permit2 base sepolia
    mapping(uint256 => Bet) public bets;
    mapping(address => bool) internal isRegisteredToken;
    uint256 internal betId = 1; //increment betId
    address internal eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    ///mapping for storing is cheaper than storing it in Bet struct
    mapping(uint256 => mapping(address => bool)) public isActor;
    mapping(uint256 => mapping(address => bool)) public deposited;
    mapping(uint256 => mapping(address => bool)) public entered;
    mapping(uint256 => mapping(address => bool)) public status;

    mapping(address => uint256) public totalDepositedUser;
    mapping(address => uint256) public totalWonUser;

    uint256 public totalEthDeposited;
    mapping(address => uint256) internal totalTokenDepsoited;

    constructor(address _owner) Ownable(_owner) {}

    error NotRegistered();
    error InValidArrayLength();
    error Auth(address);
    error BetNotCreated();
    error InvalidAmount();
    error BetNotEnded(uint256);
    error BetEnded(uint256);
    error NotBetWinner(address);
    error InvalidDispute();
    error BetClaimed();
    error AlreadyEntered();
    error Disputed();
    error TransferFailed();
    error CantDispute(uint256);
    error WinningStatusUpdated();
    error NoTokenTransfer(uint256);
    error BetNotRejectedYet();

    event RegisterToken(address token, bool register);
    event BetCreated(
        uint256 indexed _betId,
        address indexed actor1,
        address indexed actor2,
        string betName,
        uint256 duration,
        uint256 startTimeStamp,
        address creator,
        address betToken,
        uint256 betAmount
    );
    event EnterBet(address indexed actor, uint256 indexed _betId, uint256 indexed amount);
    event EnterWin(uint256 _betId, bool win, address actor);
    event Claimed(uint256 indexed _betId, uint256 indexed amount, address indexed actor);
    event OpenDispute(uint256 indexed _betId);
    event DisputeResolved(uint256 _betId, bool rewardSlashed);
    event EthRecoverd(uint256 _amount);
    event TokenRecovered(address token, uint256 amount);
    event BetRefunded(uint256 _betId);

    function registerToken(address token, bool register) external onlyOwner {
        if (register) isRegisteredToken[token] = true;
        emit RegisterToken(token, register);
    }

    /**
     * @param _actors , array of actors participating in the bet
     * @param _betName , short name for the bet
     * @param _betDuration , duration for the
     * @param _betToken , address of the registered token for bet collateral
     */
    function createBet(
        address[] memory _actors,
        string memory _betName,
        uint256 _betDuration,
        address _betCreator,
        address _betToken,
        uint256 _amount,
        bool useNativeEth
    ) external payable nonReentrant returns (uint256 _betId) {
        if (!isRegisteredToken[_betToken]) revert NotRegistered();
        if (_actors.length > 2) revert InValidArrayLength();
        Bet storage betRef = bets[betId];
        ///optimize sstores
        betRef.actors = _actors;
        betRef.startTimeStamp = block.timestamp;
        betRef.endTimeStamp = block.timestamp + _betDuration;
        betRef.betCreator = _betCreator;
        betRef.betName = _betName;
        betRef.betId = betId;
        betRef.amount = _amount;
        if (useNativeEth) {
            betRef.betToken = IERC20(address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE));
        } else {
            betRef.betToken = IERC20(_betToken);
            IERC20(_betToken).safeTransferFrom(msg.sender, address(this), _amount);
            totalDepositedUser[msg.sender] += _amount;
        }
        entered[betId][msg.sender] = true;
        ///@dev save directly individually instead of using a loop
        ///this make sense since kombat is single pvp for now
        isActor[betId][_actors[0]] = true;
        isActor[betId][_actors[1]] = true;
        _betId = betId;
        betId++;

        emit BetCreated(
            betRef.betId,
            _actors[0],
            _actors[1],
            _betName,
            _betDuration,
            block.timestamp,
            _betCreator,
            _betToken,
            _amount
        );
    }

    /**
     * @dev get the details smart contract
     */
    function getBetDetails(uint256 _betId) external view returns (Bet memory _bet) {
        _bet = bets[_betId];
    }

    /**
     * @dev enter a bet for registered users of a bet
     */
    function enterBet(uint256 _betId, bool enter) external payable nonReentrant {
        Bet storage bet = bets[_betId];
        if (!isActor[_betId][msg.sender]) revert Auth(msg.sender);
        if (enter) {
            if (bet.startTimeStamp == 0) revert BetNotCreated();
            if (entered[_betId][msg.sender] == true) revert AlreadyEntered();
            if (address(bet.betToken) == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE) {
                if (msg.value < bet.amount) revert InvalidAmount();
                totalEthDeposited += bet.amount;
                totalDepositedUser[msg.sender] += bet.amount;
            } else {
                // _depositERC20Permit2(bet.betToken, bet.amount);
                bet.betToken.safeTransferFrom(msg.sender, address(this), bet.amount);
                totalTokenDepsoited[address(bet.betToken)] += bet.amount;
                totalDepositedUser[msg.sender] += bet.amount;
            }
            deposited[_betId][msg.sender] = true;
            entered[_betId][msg.sender] = true;
        } else {
            bet.rejected = false;
        }

        emit EnterBet(msg.sender, _betId, bet.amount);
    }

    function refundUnacceptedBet(uint256 _betId) external nonReentrant {
        Bet storage _bet = bets[_betId];
        if (msg.sender != _bet.betCreator) revert Auth(msg.sender);
        if (_bet.betClaimed) revert BetClaimed();
        if (!_bet.rejected) revert BetNotRejectedYet();
        entered[_betId][_bet.actors[0]] = true;
        entered[_betId][_bet.actors[1]] = true;
        _bet.betToken.safeTransfer(_bet.betCreator, _bet.amount);
        _bet.betClaimed = true;

        emit BetRefunded(_betId);
    }

    /**
     * @dev (pvp) enter winnings after bet timestamp has ended
     */
    function enterWin(uint256 _betId, bool _win) external nonReentrant {
        Bet storage _bet = bets[_betId];
        if (block.timestamp < _bet.endTimeStamp) revert BetNotEnded(block.timestamp);
        if (!isActor[_betId][msg.sender]) revert Auth(msg.sender);
        if (status[_betId][msg.sender]) revert WinningStatusUpdated();
        if (_win) {
            if (_bet.winner != address(0)) _dispute(_bet.betId);
            _bet.winner = msg.sender;
        }
        status[_betId][msg.sender] = true;

        emit EnterWin(_betId, _win, msg.sender);
    }

    /**
     * @dev (pvp) claim winnings after bet timestamp has ended
     */
    function claim(uint256 _betId) external nonReentrant {
        Bet storage _bet = bets[_betId];
        if (_bet.betDisputed) revert Disputed();
        if (_bet.winner != msg.sender) revert NotBetWinner(msg.sender);
        if (block.timestamp < _bet.endTimeStamp) revert BetNotEnded(block.timestamp);
        if (_bet.betClaimed) revert BetClaimed();
        uint256 fee = uint256(_bet.amount * 2 * 200) / 10_000;
        uint256 _amountWon = _bet.amount * 2;
        if (address(_bet.betToken) == eth) {
            (bool success,) = address(_bet.winner).call{value: (_bet.amount * 2) - fee}("");
            if (!success) revert TransferFailed();
            //send the fee to the owner
            (success,) = address(owner()).call{value: fee}("");
            if (!success) revert TransferFailed();
            totalWonUser[_bet.winner] += (_bet.amount * 2) - fee;
        } else {
            IERC20(_bet.betToken).safeTransfer(address(_bet.winner), (_bet.amount * 2) - fee);
            //send the fee to the owner
            IERC20(_bet.betToken).safeTransfer(address(owner()), fee);
            totalWonUser[_bet.winner] += (_bet.amount * 2) - fee;
            emit Claimed(_betId, _amountWon, msg.sender);
        }
        _bet.betClaimed = true;

        emit Claimed(_betId, _amountWon, msg.sender);
    }

    ///@dev opening a dispute directly
    function openDispute(uint256 _betId) external {
        Bet storage _bet = bets[_betId];
        if (!isActor[_betId][msg.sender]) revert Auth(msg.sender);
        address[] memory actors = _bet.actors;
        if (!entered[_betId][actors[0]] || !entered[betId][actors[1]]) revert CantDispute(_betId);
        if (_bet.betClaimed == false) revert BetClaimed();
        _bet.betDisputed = true;

        emit OpenDispute(_betId);
    }

    /// @dev if the winner has been verfied through a form submitted as proof offchain
    /// owner now has the option of slashing the rewards if the winner hasn't been verified , or choosing the winner
    function solveDispute(DisputeParams memory _disputeParams) external onlyOwner nonReentrant {
        Bet memory _bet = bets[_disputeParams.betId];
        ///if dispute is not resolved
        if (_disputeParams.slashRewards) {
            _slashBetRewards(_bet, address(_bet.betToken));
        } else {
            uint256 fee = uint256(_bet.amount * 2 * 200) / 10_000;
            uint256 _amountWon = (_bet.amount * 2) - fee;
            if (address(_bet.betToken) == eth) {
                (bool success,) = address(_disputeParams.winner).call{value: (_bet.amount * 2) - fee}("");
                if (!success) revert TransferFailed();
                //send the fee to the owner
                (success,) = address(owner()).call{value: fee}("");
                if (!success) revert TransferFailed();

                emit Claimed(_bet.betId, _amountWon, msg.sender);
            } else {
                IERC20(_bet.betToken).safeTransfer(address(_disputeParams.winner), (_bet.amount * 2) - fee);
                //send the fee to the owner
                IERC20(_bet.betToken).safeTransfer(address(owner()), fee);
                totalWonUser[_bet.winner] += (_bet.amount * 2) - fee;
                emit Claimed(_bet.betId, _amountWon, msg.sender);
            }
        }

        emit DisputeResolved(_disputeParams.betId, _disputeParams.slashRewards);
    }

    /// slash 50% of each actors (amount of one)
    function _slashBetRewards(Bet memory bet, address token) internal {
        if (token == eth) {
            (bool success,) = address(bet.actors[0]).call{value: bet.amount / 2}("");
            if (!success) revert TransferFailed();
            (success,) = address(bet.actors[1]).call{value: bet.amount / 2}("");
            if (!success) revert TransferFailed();
        } else {
            IERC20(token).safeTransfer(bet.actors[0], bet.amount / 2);
            IERC20(token).safeTransfer(bet.actors[1], bet.amount / 2);
        }
    }

    function _depositERC20Permit2(
        IERC20 token,
        uint256 amount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) internal {
        token.safeTransferFrom(msg.sender, address(this), amount);
        permit2.permitTransferFrom(
            // The permit message. Spender will be inferred as the caller (us).
            IPermit2.PermitTransferFrom({
                permitted: IPermit2.TokenPermissions({token: token, amount: amount}),
                nonce: nonce,
                deadline: deadline
            }),
            // The transfer recipient and amount.
            IPermit2.SignatureTransferDetails({to: address(this), requestedAmount: amount}),
            // The owner of the tokens, which must also be
            // the signer of the message, otherwise this call
            // will fail.
            msg.sender,
            // The packed signature that was the result of signing
            // the EIP712 hash of `permit`.
            signature
        );
    }

    //enter dispute if all parties dont decide on a definite winner
    function _dispute(uint256 _betId) internal {
        Bet storage _bet = bets[_betId];
        _bet.betDisputed = true;
    }

    function recoverEth() external onlyOwner nonReentrant {
        /// if trully theres eth to recover this would pass and not revert
        /// with underflow/overflow error
        uint256 _amountToRecover = address(this).balance - totalEthDeposited;
        (bool success,) = address(msg.sender).call{value: _amountToRecover}("");
        if (!success) revert();

        emit EthRecoverd(_amountToRecover);
    }

    function recoverERC20(address token) external onlyOwner {
        /// if trully theres eth to recover this would pass and not revert with underflow/overflow error
        uint256 _amountToRecover = IERC20(token).balanceOf(address(this)) - totalTokenDepsoited[token];
        IERC20(token).safeTransfer(msg.sender, _amountToRecover);

        emit TokenRecovered(token, _amountToRecover);
    }

    receive() external payable {
        if (msg.value > 0) revert NoTokenTransfer(msg.value);
    }
}
