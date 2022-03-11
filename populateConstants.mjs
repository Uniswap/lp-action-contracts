import SwapRouter02 from '@uniswap/swap-router-contracts/artifacts/contracts/SwapRouter02.sol/SwapRouter02.json' assert { type: 'json' }
import UniswapV3Factory from '@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json' assert { type: 'json' }
import NonfungiblePositionManager from '@uniswap/v3-periphery/artifacts/contracts/NonfungiblePositionManager.sol/NonfungiblePositionManager.json' assert { type: 'json' }
import { readFileSync, writeFileSync } from 'fs'

const PATH = './src/test/utils/Constants.sol'

let file = readFileSync(PATH, { encoding: 'utf8' })

file = file.replace(/UniswapV3Factory = hex'(.*)'/g, `UniswapV3Factory = hex'${UniswapV3Factory.bytecode.slice(2)}'`)
file = file.replace(
  /NonfungiblePositionManager = hex'(.*)'/g,
  `NonfungiblePositionManager = hex'${NonfungiblePositionManager.bytecode.slice(2)}'`
)
file = file.replace(/SwapRouter02 = hex'(.*)'/g, `SwapRouter02 = hex'${SwapRouter02.bytecode.slice(2)}'`)

writeFileSync(PATH, file)
