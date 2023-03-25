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
        bytes32 makerSealedSeed;
    }

    struct TakerInfo {
        address taker;
        bytes32 takerSealedSeed;
    }

    error NonceRevoked(uint256 nonce);
    error SignatureAlreadyUsed(bytes signature);
    error SignatureNotSignedByTaker();
    error NonceAlreadyRevoked(uint8 nonce, address sender);
    error NonceAlreadyMatched(uint8 nonce, address sender);
    error TransferNotAllowedByMaker(address maker, address erc20, address operator);
    error TransferNotAllowedByTaker(address taker, address erc20, address operator);
    error MakerNotEnoughBalance(address maker, uint256 amount, address erc20);
    error TakerNotEnoughBalance(address taker, uint256 amount, address erc20);
    error FlipNotMatched();
    error TakerSeedNotMatched();
    error MakerSeedNotMatched();

    event RevokedNoncesUpdated(uint8[] revokedNonces, address sender);
    event FlipResult(address winner, address loser, uint256 randomness, address erc20Address, uint256 amount);
    event MatchAgreement(address maker, address taker, address erc20Address, uint256 amount);

    function matchAgreement(
        bytes calldata signature,
        FlipAgreement calldata flipAgreement,
        bytes32 takerSealedSeed
    )
        external;
    function executeAgreement(
        FlipAgreement calldata flipAgreement,
        bytes memory makerSeed,
        bytes memory takerSeed
    )
        external;
    function revokeAgreement(uint8[] calldata revokedNonce) external;

    function getRevokedNonces(address maker) external view returns (uint256[] memory revokedNonces);
    function getMatchedNonces(address maker) external view returns (uint256[] memory matchedNonces);
    function checkNonceRevoked(address maker, uint256 nonce) external view returns (bool);
    function checkNonceMatched(address maker, uint256 nonce) external view returns (bool);
}
