// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

abstract contract ValidateOrder {

    /**
     * @dev Throws if called by any address is smart contract.
     */
    modifier onlyHuman() {
        require(tx.origin == msg.sender, "Market: Caller is not the human");
        _;
    }

    struct EIP712Domain {
        string  name;
        string  version;
        uint256 chainId;
        address verifyingContract;
    }

    struct Detail {
        uint256 tokenId;
        address tokenContract;
        uint256 price;
        uint256 decimals;
        address paymentContract;
        uint256 foundationFeePercent;
    }

    uint256 private constant MAX_FEE_PERCENTAGE = 10000;

    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 constant DETAIL_TYPEHASH = keccak256(
        "Detail(uint256 tokenId,address tokenContract,uint256 price,uint256 decimals,address paymentContract,uint256 foundationFeePercent)"
    );

    function hashEIP712(EIP712Domain memory eip712Domain) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712DOMAIN_TYPEHASH,
            keccak256(bytes(eip712Domain.name)),
            keccak256(bytes(eip712Domain.version)),
            eip712Domain.chainId,
            eip712Domain.verifyingContract
        ));
    }

    function hashEIP712(Detail memory more) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            DETAIL_TYPEHASH,
            more.tokenId,
            more.tokenContract,
            more.price,
            more.decimals,
            more.paymentContract,
            more.foundationFeePercent
        ));
    }

   function hashEIP191(Detail memory more, uint256 expirationTime) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(
            more.tokenId,
            more.tokenContract,
            more.price,
            more.decimals,
            more.paymentContract,
            more.foundationFeePercent,
            expirationTime,
            address(this)
        ));
    }

    function validateSellerSignature(EIP712Domain memory domain, Detail memory orderInstance, bytes memory sellerSignature, address ownerOfToken) internal view returns (bool) {
        bytes32 ECDSAHash = ECDSA.toTypedDataHash(hashEIP712(domain), hashEIP712(orderInstance));
        return (
            domain.chainId == block.chainid &&
            domain.verifyingContract == address(this) &&
            ECDSA.recover(ECDSAHash, sellerSignature) == ownerOfToken &&
            msg.sender != ownerOfToken
            );
    }
    function validateVerifierSignature(uint256 expirationTime, Detail memory orderInstance, bytes memory verifierSignature, address verifier) internal view returns (bool) {
        bytes32 ECDSAHash = ECDSA.toEthSignedMessageHash(hashEIP191(orderInstance, expirationTime));
        return (orderInstance.foundationFeePercent < MAX_FEE_PERCENTAGE && ECDSA.recover(ECDSAHash, verifierSignature) == verifier && expirationTime > block.timestamp);
    }
}