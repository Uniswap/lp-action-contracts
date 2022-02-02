// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

library RemoveAndSwapDecoder {
  error InvalidDataLength(uint256 length);

  struct Params {
    // things relevant to the call as a whole
    uint256 deadline;
    // things relevant to remove
    uint256 amount0Min;
    uint256 amount1Min;
    // things relevant to swap
    bool swapToken0;
  }

  uint256 constant DEADLINE = type(uint256).max;
  uint256 constant AMOUNT_0_MIN = 0;
  uint256 constant AMOUNT_1_MIN = 0;

  function decode(bytes calldata data) internal pure returns (Params memory) {
    if (data.length == 1) {
      // [0]
      // swapToken0
      return
        Params({
          deadline: DEADLINE,
          amount0Min: AMOUNT_0_MIN,
          amount1Min: AMOUNT_1_MIN,
          swapToken0: bytes1(data[:1]) == 0x00
        });
    } else if (data.length == 9) {
      // [0]        - [1-8]
      // swapToken0 - deadline
      return
        Params({
          deadline: uint64(bytes8(data[1:])),
          amount0Min: AMOUNT_0_MIN,
          amount1Min: AMOUNT_1_MIN,
          swapToken0: bytes1(data[:1]) == 0x00
        });
    } else if (data.length == 65) {
      // [0]        - [1-32]     - [33-64]
      // swapToken0 - amount0Min - amount1Min
      return
        Params({
          deadline: DEADLINE,
          amount0Min: abi.decode(data[1:33], (uint256)),
          amount1Min: abi.decode(data[33:], (uint256)),
          swapToken0: bytes1(data[:1]) == 0x00
        });
    } else if (data.length == 73) {
      // [0]        - [1-8]    - [9-40]     - [41-72]
      // swapToken0 - deadline - amount0Min - amount1Min
      return
        Params({
          deadline: uint64(bytes8(data[1:9])),
          amount0Min: abi.decode(data[9:41], (uint256)),
          amount1Min: abi.decode(data[41:], (uint256)),
          swapToken0: bytes1(data[:1]) == 0x00
        });
    }

    revert InvalidDataLength(data.length);
  }
}
