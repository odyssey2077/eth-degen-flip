// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IEthDegenFlip } from "./IEthDegenFlip.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { ERC165 } from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import { EnumerableSet } from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "solmate/src/utils/ReentrancyGuard.sol";

contract EthDegenFlip is IEthDegenFlip, ERC165, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using ECDSA for bytes32;

    /// @notice Internal constants for EIP-712: Typed structured
    ///         data hashing and signing
    bytes32 internal constant _FLIP_AGREEMENT_PARAMS_TYPEHASH =
    // prettier-ignore
    keccak256(
        "FlipAgreement(" "address maker," "address contractAddress," "uint256 amount," "uint256 expireTime,"
        "uint256 nonce" "bytes32 makerSealedSeed;" ")"
    );
    bytes32 internal constant _EIP_712_DOMAIN_TYPEHASH =
    // prettier-ignore
     keccak256("EIP712Domain(" "string name," "string version," "uint256 chainId," "address verifyingContract" ")");
    bytes32 internal constant _NAME_HASH = keccak256("EthDegenFlip");
    bytes32 internal constant _VERSION_HASH = keccak256("1.0");
    uint256 internal immutable _CHAIN_ID = block.chainid;
    bytes32 internal immutable _DOMAIN_SEPARATOR;
    uint256 FIXED_BLOCK_NUMBER = 16_886_917;
    mapping(address => EnumerableSet.UintSet) internal _revokedNonces;
    // matched nonce can't be revoked
    mapping(address => EnumerableSet.UintSet) internal _matchedNonces;
    mapping(bytes32 => bool) private _usedDigests;
    mapping(bytes32 => TakerInfo) private _digestsToTakerInfo;

    constructor() {
        // Derive the domain separator.
        _DOMAIN_SEPARATOR = _deriveDomainSeparator();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return interfaceId == type(IEthDegenFlip).interfaceId || super.supportsInterface(interfaceId);
    }

    function matchAgreement(
        bytes calldata signature,
        FlipAgreement calldata flipAgreement,
        bytes32 takerSealedSeed
    )
        external
        nonReentrant
    {
        bytes32 digest = _validateFlipAgreement(flipAgreement, signature);
        address maker = flipAgreement.maker;
        address taker = msg.sender;
        uint256 amount = flipAgreement.amount;
        address erc20Address = flipAgreement.contractAddress;
        _validateExecution(maker, taker, erc20Address, amount);

        // transfer stake to middleman for settlement. If we don't, after revealing seeds the losing side might transfer
        // money away
        IERC20(erc20Address).transferFrom(maker, address(this), amount);
        IERC20(erc20Address).transferFrom(taker, address(this), amount);
        _digestsToTakerInfo[digest] = TakerInfo({ taker: taker, takerSealedSeed: takerSealedSeed });
        EnumerableSet.UintSet storage matchedNonce = _matchedNonces[maker];
        matchedNonce.add(flipAgreement.nonce);
        emit MatchAgreement(maker, taker, erc20Address, amount);
    }

    function revokeAgreement(uint8[] calldata revokedNonces) external {
        // to do: can't revoke if matched
        address sender = msg.sender;
        EnumerableSet.UintSet storage revokedNonceRef = _revokedNonces[sender];
        EnumerableSet.UintSet storage matchedNonce = _matchedNonces[sender];
        uint256 revokedNonceLength = revokedNonces.length;
        for (uint256 i = 0; i < revokedNonceLength;) {
            uint8 revokedNonce = revokedNonces[i];
            if (matchedNonce.contains(revokedNonce)) {
                revert NonceAlreadyMatched(revokedNonce, sender);
            }
            bool added = revokedNonceRef.add(revokedNonce);
            if (!added) {
                revert NonceAlreadyRevoked(revokedNonce, sender);
            }
            unchecked {
                ++i;
            }
        }
        emit RevokedNoncesUpdated(revokedNonces, sender);
    }

    function executeAgreement(
        FlipAgreement calldata flipAgreement,
        bytes memory makerSeed,
        bytes memory takerSeed
    )
        external
        nonReentrant
    {
        bytes32 digest = _getDigest(flipAgreement);
        if (_digestsToTakerInfo[digest].taker == address(0)) {
            revert FlipNotMatched();
        }

        address taker = _digestsToTakerInfo[digest].taker;
        address maker = flipAgreement.maker;
        if (keccak256(abi.encode(taker, takerSeed)) != _digestsToTakerInfo[digest].takerSealedSeed) {
            revert TakerSeedNotMatched();
        }
        if (keccak256(abi.encode(maker, makerSeed)) != flipAgreement.makerSealedSeed) {
            revert MakerSeedNotMatched();
        }
        if (flipAgreement.expireTime < block.timestamp) {
            revert FlipExpired();
        }

        // generate randomness
        uint256 random = uint256(keccak256(abi.encode(takerSeed, makerSeed, blockhash(FIXED_BLOCK_NUMBER))));

        // final settlement
        address winner = random % 2 == 0 ? maker : taker;
        address loser = random % 2 == 0 ? taker : maker;
        IERC20(flipAgreement.contractAddress).transfer(winner, flipAgreement.amount * 2);
        emit FlipResult(winner, loser, random, flipAgreement.contractAddress, flipAgreement.amount);
    }

    function _validateFlipAgreement(
        FlipAgreement calldata flipAgreement,
        bytes calldata signature
    )
        internal
        returns (bytes32 digest)
    {
        if (_revokedNonces[flipAgreement.maker].contains(flipAgreement.nonce)) {
            revert NonceRevoked(flipAgreement.nonce);
        }
        // Get the digest to verify the EIP-712 signature.
        digest = _getDigest(flipAgreement);
        if (_usedDigests[digest]) {
            revert SignatureAlreadyUsed(signature);
        }
        // assume match finishes
        _usedDigests[digest] = true;
        address recoveredAddress = digest.recover(signature);
        if (recoveredAddress != flipAgreement.maker) {
            revert SignatureNotSignedByTaker();
        }
    }

    function _validateExecution(address maker, address taker, address erc20Address, uint256 amount) internal view {
        IERC20 erc20Contract = IERC20(erc20Address);
        if (erc20Contract.allowance(maker, address(this)) < amount) {
            revert TransferNotAllowedByMaker(maker, address(erc20Contract), address(this));
        }
        if (erc20Contract.allowance(taker, address(this)) < amount) {
            revert TransferNotAllowedByTaker(taker, address(erc20Contract), address(this));
        }
        if (erc20Contract.balanceOf(maker) < amount) {
            revert MakerNotEnoughBalance(maker, amount, address(erc20Contract));
        }
        if (erc20Contract.balanceOf(taker) < amount) {
            revert TakerNotEnoughBalance(taker, amount, address(erc20Contract));
        }
    }

    function _generateFlipResult(address maker, address taker) internal pure returns (address winner, address loser) {
        winner = maker;
        loser = taker;
    }

    function _getDigest(FlipAgreement calldata flipAgreement) internal view returns (bytes32 digest) {
        digest = keccak256(
            bytes.concat(
                bytes2(0x1901),
                _domainSeparator(),
                keccak256(
                    abi.encode(
                        _FLIP_AGREEMENT_PARAMS_TYPEHASH,
                        flipAgreement.maker,
                        flipAgreement.contractAddress,
                        flipAgreement.amount,
                        flipAgreement.expireTime,
                        flipAgreement.nonce,
                        flipAgreement.makerSealedSeed
                    )
                )
            )
        );
    }

    function _domainSeparator() internal view returns (bytes32) {
        return block.chainid == _CHAIN_ID ? _DOMAIN_SEPARATOR : _deriveDomainSeparator();
    }

    function _deriveDomainSeparator() internal view returns (bytes32) {
        return keccak256(abi.encode(_EIP_712_DOMAIN_TYPEHASH, _NAME_HASH, _VERSION_HASH, block.chainid, address(this)));
    }

    function getRevokedNonces(address maker) external view returns (uint256[] memory revokedNonces) {
        return _revokedNonces[maker].values();
    }

    function getMatchedNonces(address maker) external view returns (uint256[] memory matchedNonces) {
        return _matchedNonces[maker].values();
    }

    function checkNonceRevoked(address maker, uint256 nonce) external view returns (bool) {
        return _revokedNonces[maker].contains(nonce);
    }

    function checkNonceMatched(address maker, uint256 nonce) external view returns (bool) {
        return _matchedNonces[maker].contains(nonce);
    }

    function checkDigestUsed(bytes32 digest) external view returns (bool) {
        return _usedDigests[digest];
    }

    function getTakerInfo(bytes32 digest) external view returns (address, bytes32) {
        return (_digestsToTakerInfo[digest].taker, _digestsToTakerInfo[digest].takerSealedSeed);
    }
}
