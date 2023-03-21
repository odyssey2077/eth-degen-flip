// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IEthDegenFlip} from "./IEthDegenFlip.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";


contract EthDegenFlip is IEthDegenFlip, ERC165 {
    using EnumerableSet for EnumerableSet.UintSet;
    using ECDSA for bytes32;

    /// @notice Internal constants for EIP-712: Typed structured
    ///         data hashing and signing
    bytes32 internal constant _SIGNED_FLIP_AGREEMENT_TYPEHASH =
        // prettier-ignore
        keccak256(
             "SignedFlipAgreement("
                "FlipAgreement flipAgreement,"
                "uint256 salt"
            ")"
            "FlipAgreement("
                "address maker,"
                "address contractAddress,"
                "uint256 amount,"
                "uint256 expireTime,"
                "uint256 nonce"
            ")"
        );
    bytes32 internal constant _FLIP_AGREEMENT_PARAMS_TYPEHASH =
        // prettier-ignore
        keccak256(
            "FlipAgreement("
                "address maker,"
                "address contractAddress,"
                "uint256 amount,"
                "uint256 expireTime,"
                "uint256 nonce"
            ")"
        );
    bytes32 internal constant _EIP_712_DOMAIN_TYPEHASH =
        // prettier-ignore
        keccak256(
            "EIP712Domain("
                "string name,"
                "string version,"
                "uint256 chainId,"
                "address verifyingContract"
            ")"
        );
    bytes32 internal constant _NAME_HASH = keccak256("EthDegenFlip");
    bytes32 internal constant _VERSION_HASH = keccak256("1.0");
    uint256 internal immutable _CHAIN_ID = block.chainid;
    bytes32 internal immutable _DOMAIN_SEPARATOR;        
    mapping(address => EnumerableSet.UintSet) internal revokedNonces;
    mapping(bytes32 => bool) private _usedDigests;
    
    constructor() {
        // Derive the domain separator.
        _DOMAIN_SEPARATOR = _deriveDomainSeparator();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (ERC165) returns (bool) {
        return interfaceId == type(IEthDegenFlip).interfaceId || super.supportsInterface(interfaceId);
    }

    function matchAgreement(bytes calldata signature, address taker, FlipAgreement calldata flipAgreement, uint256 salt) external {
        return;
    }

    function revokeAgreement(uint8[] calldata revokedNonce) external {
        return;
    }

    function _validateFlipAgreement(FlipAgreement calldata flipAgreement) internal view {
        if (revokedNonces[flipAgreement.maker].contains(flipAgreement.nonce)) {
            revert NonceRevoked(flipAgreement.nonce);
        }
    }

    function _getDigest(
        FlipAgreement calldata flipAgreement,
        uint256 salt
    ) internal view returns (bytes32 digest) {
        bytes32 flipAgreementHashStruct = keccak256(
            abi.encode(
                _FLIP_AGREEMENT_PARAMS_TYPEHASH,
                flipAgreement.maker,
                flipAgreement.contractAddress,
                flipAgreement.amount,
                flipAgreement.expireTime,
                flipAgreement.nonce
            )
        );
        digest = keccak256(
            bytes.concat(
                bytes2(0x1901),
                _domainSeparator(),
                keccak256(
                    abi.encode(
                        _SIGNED_FLIP_AGREEMENT_TYPEHASH,
                        flipAgreementHashStruct,
                        salt
                    )
                )
            )
        );
    }    

    function _domainSeparator() internal view returns (bytes32) {
        return block.chainid == _CHAIN_ID
            ? _DOMAIN_SEPARATOR
            : _deriveDomainSeparator();
    }

    function _deriveDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _EIP_712_DOMAIN_TYPEHASH,
                _NAME_HASH,
                _VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }    
}