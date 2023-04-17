// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract BoxPurchase is Initializable, PausableUpgradeable, ReentrancyGuard, OwnableUpgradeable{

    event BoxPaid(address indexed buyer, address indexed gameContract, uint256 indexed boxId, address receiver, uint256 boxType, address paymentContract, uint256 price, uint256 qty);
    event Pauser(address pauser);
    event Unpauser(address unpauser);

    struct GameBox {
        uint256 boxId;
        uint256 boxType;
        address gameContract;
        uint256 price;
        address paymentContract;
        uint256 qty;
    }

    /**
     * @dev Throws if called by any address is smart contract.
     */
    modifier onlyHuman() {
        require(tx.origin == msg.sender, "Caller is not the human");
        _;
    }

    address payable public foundationAddress;
    address public verifier;

    /**
     * @dev Cause using upgrade proxy, initialize instead of constructor.
     * @param _foundation The address receive foundation fee when someone order NFT.
     * @param _verifier The address verify marketplace.
     */
    function initialize(address payable _foundation, address _verifier) initializer public {
        __Pausable_init();
        __Ownable_init();
        foundationAddress = _foundation;
        verifier = _verifier;
    }

    /**
     * @dev This method used for someone order NFT.
     * @param orderData The data need to buy a NFT.
     */
    function purchaseBox(bytes calldata orderData) whenNotPaused onlyHuman nonReentrant external payable {
        // Decode data from bytes
        (GameBox memory box, bytes memory verifierSignature) = abi.decode(orderData, (GameBox, bytes));
        
        // Check verifier side validity.
        require(validateVerifierSignature(box, verifierSignature), "Verifier side signature is invalid");

        // Check order type use native coin
        if (box.paymentContract == address(0)){
            require(msg.value == box.price, "Value is not equal price");
            sendValue(foundationAddress, box.price);
        // Else order type use ERC20 token
        } else {
            // Check no value receive
            require(msg.value == 0, "Can not receive native coin");
            safeTransfer(box.paymentContract, _msgSender(), foundationAddress, box.price);
        }
        
        emit BoxPaid(_msgSender(), box.gameContract, box.boxId, foundationAddress, box.boxType, box.paymentContract, box.price, box.qty);
    }

    /**
     * @dev This method use when owner want to change foundation address.
     */
    function setFoundationAddress(address payable newFoundationAddress) external onlyOwner {
        foundationAddress = newFoundationAddress;
    }

    /**
     * @dev This method use when owner want to change verifier.
     */
    function setVerifier(address newVerifier) external onlyOwner {
        verifier = newVerifier;
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

   function hashEIP191Box(GameBox memory box) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(
            box.boxId,
            box.boxType,
            box.gameContract,
            box.price,
            box.paymentContract,
            box.qty,
            address(this)
        ));
    }

    function validateVerifierSignature(GameBox memory box, bytes memory verifierSignature) internal view returns (bool) {
        bytes32 ECDSAHash = ECDSA.toEthSignedMessageHash(hashEIP191Box(box));
        return (ECDSA.recover(ECDSAHash, verifierSignature) == verifier);
    }

    /**
     * @dev Send value common method.
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Unable to send value, recipient may have reverted");
    }

    function safeTransfer(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "Transfer caller is not owner nor approved");
    }
}