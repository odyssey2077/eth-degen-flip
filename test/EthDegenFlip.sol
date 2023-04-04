pragma solidity >= 0.8.19;

import "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {EthDegenFlip} from "src/EthDegenFlip.sol";
import {IEthDegenFlip} from "src/IEthDegenFlip.sol";

contract EthDegenFlipTest is Test {
    EthDegenFlip flip;

    function setUp() public {
        flip = new EthDegenFlip();
    }

    function testMatchAgreement() public {
        IEthDegenFlip.FlipAgreement memory flipAgreement = IEthDegenFlip.FlipAgreement({
            maker: address(0x0), contractAddress: address(0x0), amount: 0, expireTime: 0, nonce: 0, makerSealedSeed: bytes32(0x0)
        });
    }

}
