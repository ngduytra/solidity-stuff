// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

// interface IERC721TransferProxy {
//     function erc721safeTransferFrom(IERC721 NFT, address from, address to, uint256 tokenId) external;
// }

library ERC20TransferHelper {
    function safeTransfer(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "ERC20TransferHelper: Transfer caller is not owner nor approved");
    }
}

abstract contract ExecuteOrder is Initializable {
    using SafeMath for uint256;

    uint256 private constant TOTAL_PERCENTAGE = 100000;

    // IERC721TransferProxy ERC721TransferProxy;
    address payable public foundationAddress;

    function __ExecuteOrder_init(address payable addressFoundation) internal initializer {
        foundationAddress = addressFoundation;
        // ERC721TransferProxy = addressERC721TransferProxy;
    }

    /**
     * @dev executeOrder for ERC20 token payment.
     */
    function executeOrder(
        uint256 tokenId, 
        uint256 amount, 
        uint256 foundationFeePercent,
        address seller,
        address paymentContract,
        IERC721 erc721Instance
    ) internal {
        // Calculate foundation fee
        uint256 foundationFee = (amount.mul(foundationFeePercent)).div(TOTAL_PERCENTAGE);
        // Calculate amout to send seller
        uint256 cost = amount.sub(foundationFee);
        if(foundationFee > 0) {
            // Send foundation fee
            ERC20TransferHelper.safeTransfer(paymentContract, msg.sender, foundationAddress, foundationFee);
        }
        if(cost > 0) {
            // Send value to seller
            ERC20TransferHelper.safeTransfer(paymentContract, msg.sender, seller, cost);
        }
        // Send NFT to buyer
        erc721Instance.safeTransferFrom(seller, msg.sender, tokenId);
    }

    /**
     * @dev executeOrder for native coin payment.
     */
    function executeOrder(
        uint256 tokenId, 
        uint256 amount, 
        uint256 foundationFeePercent,
        address payable seller, 
        IERC721 erc721Instance) internal {
        // Calculate foundation fee
        uint256 foundationFee = (amount.mul(foundationFeePercent)).div(TOTAL_PERCENTAGE);
        // Calculate amout to send seller
        uint256 cost = amount.sub(foundationFee);
        if(foundationFee > 0 && foundationFee < amount) {
            // Send foundation fee
            sendValue(foundationAddress, foundationFee);
        }
        if(cost > 0 && cost <= amount) {
            // Send value to owner
            sendValue(seller, cost);
        }
        // Send NFT to buyer
        erc721Instance.safeTransferFrom(seller, msg.sender, tokenId);
    }

    /**
     * @dev Send value common method.
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Execute: Insufficient balance");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Execute: Unable to send value, recipient may have reverted");
    }
}