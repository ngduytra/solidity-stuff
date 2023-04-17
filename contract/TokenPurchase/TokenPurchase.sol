// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract TokenPurchase is Initializable, PausableUpgradeable, ReentrancyGuard, OwnableUpgradeable{

    using SafeMath for uint256;

    mapping(address => uint256) public ListedToken;

    event TokenPaid(address indexed buyer, address indexed tokenAddress, uint256 indexed amount, uint256 value, uint256 price);
    event Pauser(address pauser);
    event Unpauser(address unpauser);

    /**
     * @dev Throws if called by any address is smart contract.
     */
    modifier onlyHuman() {
        require(tx.origin == msg.sender, "Caller is not the human");
        _;
    }

    function initialize() initializer public {
        __Pausable_init();
        __Ownable_init();
        __Context_init();
    }

    function purchaseToken(address tokenAddress) whenNotPaused onlyHuman nonReentrant external payable {
        uint256 pricePerNative = ListedToken[tokenAddress];
        require(pricePerNative > 0 && msg.value >= pricePerNative, "Token is not listing");
        IERC20 erc20Instance = IERC20(tokenAddress);
        uint256 decimalsOfToken = erc20Instance.decimals();
        uint256 balance = erc20Instance.balanceOf(address(this));
        uint256 amount = msg.value.mul(10**decimalsOfToken).div(pricePerNative);
        require(amount > 0 && amount <= balance, "Amount token is invalid");
        safeTransfer(tokenAddress, _msgSender(), amount);
        emit TokenPaid(_msgSender(), tokenAddress, amount, msg.value, pricePerNative);
    }

    function setListedToken(address tokenAddress, uint256 pricePerNative) external onlyOwner {
        ListedToken[tokenAddress] = pricePerNative;
    }

    function withdraw(address payable recipient, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Unable to send value, recipient may have reverted");
    }

    /**
     * @dev This method use when owner want to pause contract.
     */
    function pause() external onlyOwner {
        _pause();
        emit Pauser(_msgSender());
    }

    /**
     * @dev This method use when owner want to unpause contract.
     */
    function unpause() external onlyOwner {
        _unpause();
        emit Unpauser(_msgSender());
    }

    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer caller is not owner nor approved");
    }
}
