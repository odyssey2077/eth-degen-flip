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

    function matchAgreement(bytes calldata signature, address taker, FlipAgreement calldata flipAgreement) external;
    function revokeAgreement(uint8[] calldata revokedNonce) external;
}