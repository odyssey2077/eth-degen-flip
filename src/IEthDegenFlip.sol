// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IEthDegenFlip {
    // structs
    enum FlipType {
        ERC20,
        ERC721
    }

    // parameters signed offchain following EIP-712, verified onchain
    struct FlipAgreement {
        address maker;
        address contractAddress;
        uint256 amount;
        uint256 expireTime;
        uint256 nonce;
    } 
    
    error NonceRevoked(uint256 nonce);
    error SignatureAlreadyUsed(bytes signature);
    error SignatureNotSignedByTaker();
    error NonceAlreadyRevoked(uint8 nonce, address sender);
    event revokedNoncesUpdated(uint8[] revokedNonces, address sender);

    function matchAgreement(bytes calldata signature, FlipAgreement calldata flipAgreement) external;
    function revokeAgreement(uint8[] calldata revokedNonce) external;
}