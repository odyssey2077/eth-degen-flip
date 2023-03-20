// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IEthDegenFlip} from "./IEthDegenFlip.sol";
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";


contract EthDegenFlip is IEthDegenFlip, ERC165 {
    using EnumerableSet for EnumerableSet.UintSet;

    mapping(address => EnumerableSet.UintSet) internal revokedNonces;
    
    function supportsInterface(bytes4 interfaceId) public view virtual override (ERC165) returns (bool) {
        return interfaceId == type(IEthDegenFlip).interfaceId || super.supportsInterface(interfaceId);
    }

    function matchAgreement(bytes calldata signature, address taker, FlipAgreement calldata flipAgreement) external {
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
}