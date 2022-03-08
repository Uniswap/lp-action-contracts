// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import 'ds-test/test.sol';

import '../interfaces/external/ISwapRouter.sol';
import '../interfaces/external/INonfungiblePositionManager.sol';
import '../RemoveAndSwap.sol';

interface Cheats {
    function expectRevert(bytes calldata msg) external;

    function prank(address sender) external;

    function mockCall(
        address where,
        bytes calldata data,
        bytes calldata retdata
    ) external;

    function expectCall(address where, bytes calldata data) external;
}

contract RemoveAndSwapTest is DSTest {
    ISwapRouter constant swapRouter = ISwapRouter(0x1111111111111111111111111111111111111111);
    INonfungiblePositionManager constant nonfungiblePositionManager =
        INonfungiblePositionManager(0x2222222222222222222222222222222222222222);
    IERC20 constant token0 = IERC20(0x3333333333333333333333333333333333333333);
    IERC20 constant token1 = IERC20(0x4444444444444444444444444444444444444444);
    address constant recipient = 0x5555555555555555555555555555555555555555;
    uint256 constant tokenId = 1;
    uint256 constant amount0 = 2;
    uint256 constant amount1 = 3;

    Cheats constant cheats = Cheats(HEVM_ADDRESS);

    RemoveAndSwapDecoder.Params params;
    bytes removeAndSwapData;

    RemoveAndSwap removeAndSwap;

    function setUp() public {
        params.recipient = recipient;
        removeAndSwapData = abi.encode(params);

        removeAndSwap = new RemoveAndSwap(swapRouter, nonfungiblePositionManager);
    }

    function testThrowsUnsupportedNFT() public {
        cheats.expectRevert(abi.encodeWithSelector(RemoveAndSwap.UnsupportedNFT.selector, address(this)));

        removeAndSwap.onERC721Received(address(0), address(0), tokenId, hex'');
    }

    function mockPositionsCall(uint256 liquidity) private {
        cheats.mockCall(
            address(nonfungiblePositionManager),
            abi.encodeCall(INonfungiblePositionManager.positions, (tokenId)),
            abi.encode(0, address(0), address(token0), address(token1), 0, 0, 0, liquidity, 0, 0, 0, 0)
        );
        cheats.expectCall(
            address(nonfungiblePositionManager),
            abi.encodeCall(INonfungiblePositionManager.positions, (tokenId))
        );
    }

    function testThrowsNoLiquidity() public {
        cheats.expectRevert(abi.encodeWithSelector(RemoveAndSwap.NoLiquidity.selector));

        cheats.prank(address(nonfungiblePositionManager));
        mockPositionsCall(0);
        removeAndSwap.onERC721Received(address(0), address(0), tokenId, hex'');
    }

    function testFailDecode() public {
        cheats.prank(address(nonfungiblePositionManager));
        mockPositionsCall(1);
        removeAndSwap.onERC721Received(address(0), address(0), tokenId, hex'');
    }

    function testFailNonfungiblePositionManagerMulticall() public {
        cheats.prank(address(nonfungiblePositionManager));
        mockPositionsCall(1);
        removeAndSwap.onERC721Received(address(0), address(0), tokenId, removeAndSwapData);
    }

    function mockNonfungiblePositionManagerMulticallCall() private {
        bytes[] memory results = new bytes[](2);
        results[1] = abi.encode(amount0, amount1);

        cheats.mockCall(
            address(nonfungiblePositionManager),
            abi.encodeWithSelector(INonfungiblePositionManager.multicall.selector),
            abi.encode(results)
        );
        cheats.expectCall(
            address(nonfungiblePositionManager),
            abi.encodeWithSelector(INonfungiblePositionManager.multicall.selector)
        );
    }

    function testFailSwapRouterMulticall() public {
        cheats.prank(address(nonfungiblePositionManager));
        mockPositionsCall(1);
        mockNonfungiblePositionManagerMulticallCall();
        removeAndSwap.onERC721Received(address(0), address(0), tokenId, removeAndSwapData);
    }

    function mockSwapRouterMulticallCall() private {
        // convenient place to ensure tokens are being called correctly
        cheats.expectCall(address(token0), abi.encodeCall(IERC20.transfer, (recipient, amount0)));
        cheats.expectCall(address(token1), abi.encodeCall(IERC20.approve, (address(swapRouter), amount1)));

        cheats.mockCall(
            address(swapRouter),
            abi.encodeWithSelector(ISwapRouter.multicall.selector),
            abi.encode(new bytes[](0))
        );
        cheats.expectCall(address(swapRouter), abi.encodeWithSelector(ISwapRouter.multicall.selector));
    }

    function testWorks() public {
        cheats.prank(address(nonfungiblePositionManager));
        mockPositionsCall(1);
        mockNonfungiblePositionManagerMulticallCall();
        mockSwapRouterMulticallCall();
        bytes4 selector = removeAndSwap.onERC721Received(address(0), address(0), tokenId, removeAndSwapData);
        assertEq(selector, IERC721Receiver.onERC721Received.selector);
    }
}
