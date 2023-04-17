// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

library Math {
    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

/**
 * @dev A token holder contract that will allow a beneficiary to extract the
 * tokens after a given release time.
 */
contract TokenTimelock is Initializable {
    using SafeERC20 for IERC20;
    using Strings for uint256;
    using Math for uint256;

    Vesting[] public arrVesting;

    uint256 constant private TOTAL_PERCENTAGE = 100;

    // ERC20 basic token contract being held
    IERC20 public token;

    // Beneficiary of tokens after they are released
    address public beneficiary;

    // TGE time
    uint256 public TGETime;

    // Token amount unlock at TGE
    uint256 public TGEUnlockPercent;

    // Number of unlock months
    uint256 public cliffMonths;

    // Linearly vesting percent per month
    uint256 public linearVestingPercentPerMonth;

    // Vesting period
    struct Vesting {
        string periodName;
        uint256 releaseTime;
        uint256 percentage;
        uint256 amountUnlock;
        bool isWithdrawal;
    }

    /**
     * @dev Throws if called by any account other than the beneficiary.
     */
    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary, "TokenTimelock: caller is not the beneficiary");
        _;
    }

    event Withdraw(address indexed beneficiary, uint256 indexed amount, uint256 indexed stage);

    function initialize(
        IERC20 token_,
        address beneficiary_,
        uint256 totalLockAmount,
        uint256 TGETime_,
        uint256 TGEUnlockPercent_,
        uint256 cliffMonths_,
        uint256 linearVestingPercentPerMonth_
    ) initializer external {
        require(TGETime_ > block.timestamp, "TokenTimelock: TGE time is before current time");
        token = token_;
        beneficiary = beneficiary_;
        TGETime = TGETime_;
        TGEUnlockPercent = TGEUnlockPercent_;
        cliffMonths = cliffMonths_;
        linearVestingPercentPerMonth = linearVestingPercentPerMonth_;

        uint256 amountUnlockAtTGE = totalLockAmount * TGEUnlockPercent_ / TOTAL_PERCENTAGE;
        arrVesting.push(Vesting("Unlock at TGE", TGETime_, TGEUnlockPercent_, amountUnlockAtTGE, false));

        uint256 numberOfMonthsVestingDown = TOTAL_PERCENTAGE / linearVestingPercentPerMonth_;
        uint256 numberOfMonthsVestingUp = TOTAL_PERCENTAGE.ceilDiv(linearVestingPercentPerMonth_);
        
        uint256 amountLinearVesting = ((totalLockAmount - amountUnlockAtTGE) * linearVestingPercentPerMonth_) / TOTAL_PERCENTAGE;
        for (uint256 month = 1; month <= numberOfMonthsVestingUp; month++) {
            if (numberOfMonthsVestingDown != numberOfMonthsVestingUp && month == numberOfMonthsVestingUp) {
                amountLinearVesting = totalLockAmount - amountUnlockAtTGE - numberOfMonthsVestingDown * amountLinearVesting;
            }
            arrVesting.push(
                Vesting(
                    string(abi.encodePacked("Linear vesting at ", month.toString(), "(st,nd,rd,th) month")),
                    TGETime_ + (cliffMonths_ + month) * 30 days,
                    linearVestingPercentPerMonth_,
                    amountLinearVesting,
                    false
                )
            );
        }
    }

    /**
     * @dev Return amount token can be withdraw by beneficiary and the stage status base on current blocktime.
     */
    function withdrawableBalance() public view returns (uint256 amount, uint256 stage) {
        amount = 0;
        stage = 0;
        for (uint256 i = 0; i < arrVesting.length; i++) {
            if (block.timestamp >= arrVesting[i].releaseTime) {
                stage = i;
                if (arrVesting[i].isWithdrawal == false) {
                    amount += arrVesting[i].amountUnlock;
                }
            }
        }
    }

    /**
     * @dev Transfers tokens held by the timelock to the beneficiary. Will only succeed if invoked after the release
     * time.
     */
    function withdraw() external onlyBeneficiary {
        (uint256 amount, uint256 stage) = withdrawableBalance();
        require(amount > 0, "TokenTimelock: current time is before release time or no tokens to release");
        for (uint256 i = 0; i <= stage; i++) {
            arrVesting[i].isWithdrawal = true;
        }
        token.safeTransfer(beneficiary, amount);
        emit Withdraw(beneficiary, amount, stage);
    }

}