// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IEthDegenFlip} from "./IEthDegenFlip.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract EthDegenFlip is IEthDegenFlip, ERC165 {
    using EnumerableSet for EnumerableSet.UintSet;
    using ECDSA for bytes32;

    /// @notice Internal constants for EIP-712: Typed structured
    ///         data hashing and signing
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
    mapping(address => EnumerableSet.UintSet) internal _revokedNonces;
    mapping(bytes32 => bool) private _usedDigests;
    
    constructor() {
        // Derive the domain separator.
        _DOMAIN_SEPARATOR = _deriveDomainSeparator();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (ERC165) returns (bool) {
        return interfaceId == type(IEthDegenFlip).interfaceId || super.supportsInterface(interfaceId);
    }

    function matchAgreement(bytes calldata signature, FlipAgreement calldata flipAgreement) external {
        _validateFlipAgreement(flipAgreement, signature);
        address maker = flipAgreement.maker;
        address taker = msg.sender;
        uint256 amount = flipAgreement.amount;
        address erc20Address = flipAgreement.contractAddress;
        _validateExecution(maker, taker, erc20Address, amount);

        return;
    }

    function revokeAgreement(uint8[] calldata revokedNonces) external {
        address sender = msg.sender;
        EnumerableSet.UintSet storage revokedNonceRef = _revokedNonces[sender];
        uint256 revokedNonceLength = revokedNonces.length;
        for (uint256 i = 0; i < revokedNonceLength;) {
            uint8 revokedNonce = revokedNonces[i];
            bool added  = revokedNonceRef.add(revokedNonce);
            if (!added) {
                revert NonceAlreadyRevoked(revokedNonce, sender);
            }
            unchecked {
                ++i;
            }            
        }
        emit revokedNoncesUpdated(revokedNonces, sender);
    }

    function _validateFlipAgreement(FlipAgreement calldata flipAgreement, bytes calldata signature) internal {
        if (_revokedNonces[flipAgreement.maker].contains(flipAgreement.nonce)) {
            revert NonceRevoked(flipAgreement.nonce);
        }
        // Get the digest to verify the EIP-712 signature.
        bytes32 digest = _getDigest(
            flipAgreement
        );        
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

    function _getDigest(
        FlipAgreement calldata flipAgreement
    ) internal view returns (bytes32 digest) {

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
                        flipAgreement.nonce
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