// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ValidateOrder.sol";
import "./ExecuteOrder.sol";

contract MarketLogic is Initializable, PausableUpgradeable, ReentrancyGuard, OwnableUpgradeable, ExecuteOrder, ValidateOrder{

    event PurchaseERC721(address indexed seller, address indexed buyer, uint256 indexed tokenId, address tokenContract, uint256 price, address paymentContract);
    event Pauser(address pauser);
    event Unpauser(address unpauser);

    address public verifier;

    /**
     * @dev Cause using upgrade proxy, initialize instead of constructor.
     * @param _foundation The address receive foundation fee when someone order NFT.
     * @param _verifier The address verify marketplace.
     */
    function initialize(address payable _foundation, address _verifier) initializer public {
        __Pausable_init();
        __Ownable_init();
        __ExecuteOrder_init(_foundation);
        verifier = _verifier;
    }

    /**
     * @dev This method used for someone order NFT.
     * @param orderData The data need to buy a NFT.
     */
    function purchaseERC721(bytes calldata orderData) whenNotPaused onlyHuman nonReentrant external payable {
        // Decode data from bytes
        (uint256 expirationTime, EIP712Domain memory domain, Detail memory orderInstance, bytes memory sellerSignature, bytes memory verifierSignature) = 
        abi.decode(orderData, (uint256, EIP712Domain, Detail, bytes, bytes));
        
        // Interact with ERC721 to find owner of token
        IERC721 erc721Instance = IERC721(orderInstance.tokenContract);
        address ownerOfToken = erc721Instance.ownerOf(orderInstance.tokenId);
        
        // Check verifier side validity.
        require(validateVerifierSignature(expirationTime, orderInstance, verifierSignature, verifier), "Market: Failed to validate verifier side");

        // Check seller side validity.
        require(validateSellerSignature(domain, orderInstance, sellerSignature, ownerOfToken), "Market: Failed to validate seller side");

        // Check order type use native coin
        if (orderInstance.paymentContract == address(0)){
            require(msg.value == orderInstance.price, "Market: Value is not equal price");
            executeOrder(
                orderInstance.tokenId,
                orderInstance.price,
                orderInstance.foundationFeePercent,
                payable(ownerOfToken),
                erc721Instance
            );
        // Else order type use ERC20 token
        } else {
            // Get decimals of payment contract
            IERC20 erc20Instance = IERC20(orderInstance.paymentContract);
            uint256 decimalsOfToken = erc20Instance.decimals();
            // Check decimals valid or not
            require(decimalsOfToken == orderInstance.decimals, "Market: Invalid decimals");
            // Check no value receive
            require(msg.value == 0, "Market: Can not receive native coin");
            executeOrder(
                orderInstance.tokenId,
                orderInstance.price,
                orderInstance.foundationFeePercent,
                ownerOfToken,
                orderInstance.paymentContract,
                erc721Instance
            );
        }

        emit PurchaseERC721(ownerOfToken, _msgSender(), orderInstance.tokenId, orderInstance.tokenContract, orderInstance.price, orderInstance.paymentContract);
    }

    /**
     * @dev This method use when owner want to change verifier.
     */
    function setVerifier(address newVerifier) external onlyOwner {
        verifier = newVerifier;
    }

    /**
     * @dev This method use when someone has been a.
     */
    function transferHelperERC721(address tokenContract, uint256 tokenId, address sender, address receiver) external onlyOwner {
        // Interact with ERC721 to find owner of token
        IERC721 erc721Instance = IERC721(tokenContract);
        address ownerOfToken = erc721Instance.ownerOf(tokenId);
        require(ownerOfToken == sender, "Market: Sender is not owner");
        erc721Instance.safeTransferFrom(sender, receiver, tokenId);
    }

    /**
     * @dev This method use when owner want to change foundation address.
     */
    function setFoundationAddress(address payable newFoundationAddress) external onlyOwner {
        foundationAddress = newFoundationAddress;
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
}
