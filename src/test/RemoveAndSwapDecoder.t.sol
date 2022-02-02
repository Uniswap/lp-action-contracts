// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import 'ds-test/test.sol';

import '../libraries/RemoveAndSwapDecoder.sol';

interface Cheats {
  function expectRevert(bytes calldata) external;
}

contract Decoder {
  function decode(bytes calldata data)
    external
    pure
    returns (RemoveAndSwapDecoder.Params memory)
  {
    return RemoveAndSwapDecoder.decode(data);
  }
}

contract RemoveAndSwapDecoderTest is DSTest {
  Cheats cheats = Cheats(HEVM_ADDRESS);

  Decoder decoder;

  function setUp() public {
    decoder = new Decoder();
  }

  bytes data;

  // the expected defaults
  uint256 constant DEADLINE = type(uint256).max;
  uint256 constant AMOUNT_0_MIN = 0;
  uint256 constant AMOUNT_1_MIN = 0;

  // test-supplied non-default
  bool constant swapToken0 = false;
  bool constant swapToken1 = true;
  uint64 constant deadline = 999;
  uint256 constant amount0Min = 123;
  uint256 constant amount1Min = 456;

  function testLength0() public {
    data = new bytes(0);

    cheats.expectRevert(
      abi.encodeWithSelector(RemoveAndSwapDecoder.InvalidDataLength.selector, 0)
    );
    decoder.decode(data);
  }

  function testLength1() public {
    data = new bytes(1);

    data = abi.encodePacked(swapToken0);
    RemoveAndSwapDecoder.Params memory params = decoder.decode(data);
    assertEq(params.deadline, DEADLINE);
    assertEq(params.amount0Min, AMOUNT_0_MIN);
    assertEq(params.amount0Min, AMOUNT_1_MIN);
    assertTrue(params.swapToken0);

    data = abi.encodePacked(swapToken1);
    params = decoder.decode(data);
    assertEq(params.deadline, DEADLINE);
    assertEq(params.amount0Min, AMOUNT_0_MIN);
    assertEq(params.amount0Min, AMOUNT_1_MIN);
    assertTrue(params.swapToken0 == false);
  }

  function testLength9() public {
    data = new bytes(9);

    data = abi.encodePacked(swapToken0, deadline);
    RemoveAndSwapDecoder.Params memory params = decoder.decode(data);
    assertEq(params.deadline, deadline);
    assertEq(params.amount0Min, AMOUNT_0_MIN);
    assertEq(params.amount0Min, AMOUNT_1_MIN);
    assertTrue(params.swapToken0);
  }
}
