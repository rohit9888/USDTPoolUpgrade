// SPDX-License-Identifier:OPEN
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/Initializable.sol";

library SafeMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }
}

contract Liquidity is Initializable, OwnableUpgradeSafe {
    uint256 public reserve1;
    uint256 public reserve2;
    IERC20 public PBMC;
    IERC20 public USDT;
    uint256 public totalLiquidity;
    mapping(address => uint256) public userLiquidity;
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event LiquidityAdded(
        address indexed provider,
        uint256 amountPBMC,
        uint256 amountUSDT,
        uint256 liquidity
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 amountPBMC,
        uint256 amountUSDT,
        uint256 liquidity
    );

    event PBMCForUSDTSwapped(
        address indexed from,
        address indexed to,
        uint256 amountIn,
        uint256 amountOut
    );

    event USDTForPBMCSwapped(
        address indexed from,
        address indexed to,
        uint256 amountIn,
        uint256 amountOut
    );

    function initialize() public initializer {
        __Ownable_init();
    }

    function setAddresses(address _pbmc, address _usdt) public onlyOwner {
        PBMC = IERC20(_pbmc);
        USDT = IERC20(_usdt);
    }

    function getReserves()
        public
        view
        returns (uint256 _reserve1, uint256 _reserve2)
    {
        _reserve1 = reserve1;
        _reserve2 = reserve2;
    }

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256) {
        require(amountA > 0, "UniswapV2Library: INSUFFICIENT_AMOUNT");
        require(
            reserveA > 0 && reserveB > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountB = amountA.mul(reserveB) / reserveA;
        return amountB;
    }

    function _addLiquidity(
        uint256 _PBMCQuantity,
        uint256 _USDTQuantity
    ) internal view returns (uint256 amountA, uint256 amountB) {
        require(
            _PBMCQuantity != 0 && _USDTQuantity != 0,
            "token quantity could not be zero"
        );
        (uint256 reserveA, uint256 reserveB) = getReserves();
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (_PBMCQuantity, _USDTQuantity);
        } else {
            uint256 amount2Optimal = quote(_PBMCQuantity, reserveA, reserveB);
            if (amount2Optimal <= _USDTQuantity) {
                (amountA, amountB) = (_PBMCQuantity, amount2Optimal);
            } else {
                uint256 amountAOptimal = quote(
                    _USDTQuantity,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= _PBMCQuantity);
                (amountA, amountB) = (amountAOptimal, _USDTQuantity);
            }
        }
    }

    function addLiquidity(
        uint256 amountPBMC,
        uint256 amountUSDT,
        address to
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(amountPBMC, amountUSDT);
        PBMC.safeTransferFrom(msg.sender, address(this), amountA);
        USDT.safeTransferFrom(msg.sender, address(this), amountB);
        liquidity = mintLPToken(to);

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function mintLPToken(address to) internal returns (uint256 liquidity) {
        (uint256 _reserve0, uint256 _reserve1) = getReserves(); // gas savings
        uint256 balance0 = PBMC.balanceOf(address(this));
        uint256 balance1 = USDT.balanceOf(address(this));
        uint256 amount0 = balance0.sub(_reserve0);
        uint256 amount1 = balance1.sub(_reserve1);

        uint256 _totalLiquidity = totalLiquidity;
        if (_totalLiquidity == 0) {
            liquidity = Math.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
            userLiquidity[address(0)] = MINIMUM_LIQUIDITY;
        } else {
            liquidity = Math.min(
                amount0.mul(_totalLiquidity) / _reserve0,
                amount1.mul(_totalLiquidity) / _reserve1
            );
        }
        require(liquidity > 0, "INSUFFICIENT_LIQUIDITY_MINTED");
        userLiquidity[to] += liquidity;
        totalLiquidity += liquidity;
        reserve1 = PBMC.balanceOf(address(this));
        reserve2 = USDT.balanceOf(address(this));
    }

    function burn(
        uint256 liquidity
    ) internal returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = PBMC.balanceOf(address(this));
        uint256 balance1 = USDT.balanceOf(address(this));
        uint256 _totalLiquidity = totalLiquidity;
        amount0 = liquidity.mul(balance0) / _totalLiquidity;
        amount1 = liquidity.mul(balance1) / _totalLiquidity; // using balances ensures pro-rata distribution
        require(
            amount0 > 0 && amount1 > 0,
            "INSUFFICIENT_LIQUIDITY_BURNED: Increase Liquidity amount"
        );
        totalLiquidity -= liquidity;
    }

    function removeLiquidity(
        uint256 liquidity,
        address to
    ) public returns (uint256 amountA, uint256 amountB) {
        require(
            userLiquidity[msg.sender] >= liquidity,
            "INSUFFICIENT_LIQUIDITY"
        );
        (amountA, amountB) = burn(liquidity);
        PBMC.safeTransfer(to, amountA);
        USDT.safeTransfer(to, amountB);
        userLiquidity[msg.sender] -= liquidity;
        reserve1 = PBMC.balanceOf(address(this));
        reserve2 = USDT.balanceOf(address(this));

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swapPBMCForUSDT(uint256 amountIn, address _to) external {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        (uint256 reserveIn, uint256 reserveOut) = getReserves();

        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        uint256 amountOut = numerator / denominator;
        require(amountOut <= reserveOut, "UniswapV2: INSUFFICIENT_LIQUIDITY");
        PBMC.safeTransferFrom(_to, address(this), amountIn);
        USDT.safeTransfer(_to, amountOut);
        reserve1 = PBMC.balanceOf(address(this));
        reserve2 = USDT.balanceOf(address(this));

        emit PBMCForUSDTSwapped(_to, _to, amountIn, amountOut);
    }

    function swapUSDTForPBMC(uint256 amountIn, address _to) external {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        (uint256 reserveOut, uint256 reserveIn) = getReserves();
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn.mul(997);
        uint256 numerator = amountInWithFee.mul(reserveOut);
        uint256 denominator = reserveIn.mul(1000).add(amountInWithFee);
        uint256 amountOut = numerator / denominator;
        require(amountOut <= reserveOut, "UniswapV2: INSUFFICIENT_LIQUIDITY");
        USDT.safeTransferFrom(_to, address(this), amountIn);
        PBMC.safeTransfer(_to, amountOut);
        reserve1 = PBMC.balanceOf(address(this));
        reserve2 = USDT.balanceOf(address(this));

        emit USDTForPBMCSwapped(_to, _to, amountIn, amountOut);
    }
}

//0x308554192063F5e8cA28c5E0144Ccd8E5C2C381f LIQUIDITY
// 0x254B731206cD554528a106fF257902C69723A777 PMBC
// 0x45b481cEf0a1eA8700fa728bc03002e3Af91e7b7 USDT
