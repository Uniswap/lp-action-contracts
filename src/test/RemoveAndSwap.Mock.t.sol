// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';

import {ISwapRouter02} from '../interfaces/external/ISwapRouter02.sol';
import {INonfungiblePositionManager} from '../interfaces/external/INonfungiblePositionManager.sol';
import {RemoveAndSwapDecoder} from '../libraries/RemoveAndSwapDecoder.sol';
import {RemoveAndSwap} from '../RemoveAndSwap.sol';

import {Test} from './utils/Test.sol';

contract RemoveAndSwapMock is Test {
    ISwapRouter02 constant swapRouter = ISwapRouter02(0x1111111111111111111111111111111111111111);
    INonfungiblePositionManager constant nonfungiblePositionManager =
        INonfungiblePositionManager(0x2222222222222222222222222222222222222222);

    IERC20 constant token0 = IERC20(0x3333333333333333333333333333333333333333);
    IERC20 constant token1 = IERC20(0x4444444444444444444444444444444444444444);
    address constant recipient = 0x5555555555555555555555555555555555555555;
    uint256 constant tokenId = 1;
    uint256 constant amount0 = 2;
    uint256 constant amount1 = 3;

    RemoveAndSwapDecoder.Params params;
    bytes removeAndSwapData;

    RemoveAndSwap removeAndSwap;

    function setUp() public override {
        params.recipient = recipient;
        // this is so the whole amount gets swapped
        params.swapEntireAmount = true;
        // this is so there's no arithmetic underflow when calculating lastSwapIndex
        RemoveAndSwapDecoder.V2ExactInput memory v2ExactInput;
        params.v2ExactInputs.push(v2ExactInput);
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
            abi.encodeWithSelector(ISwapRouter02.multicall.selector),
            abi.encode(new bytes[](0))
        );
        cheats.expectCall(address(swapRouter), abi.encodeWithSelector(ISwapRouter02.multicall.selector));
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
