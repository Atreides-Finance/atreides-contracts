// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.7.5;

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        assert(a == b * c + (a % b)); // There is no case in which this doesn't hold

        return c;
    }
}

interface IERC20 {
    function decimals() external view returns (uint8);

    function balanceOf(address owner) external view returns (uint256);
}

interface IPair is IERC20 {
    function getReserves()
        external
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        );

    function token0() external view returns (address);

    function token1() external view returns (address);
}

interface ISpiceCirculation {
    function SPICECirculatingSupply() external view returns (uint256);
}

interface Investment {
    function totalValueDeployed() external view returns (uint256);
}

interface IBackingCalculator {
    //decimals for backing is 4
    function backing()
        external
        view
        returns (uint256 _lpBacking, uint256 _treasuryBacking);

    //decimals for backing is 4
    function lpBacking() external view returns (uint256 _lpBacking);

    //decimals for backing is 4
    function treasuryBacking() external view returns (uint256 _treasuryBacking);

    //decimals for backing is 4
    function backing_full()
        external
        view
        returns (
            uint256 _lpBacking,
            uint256 _treasuryBacking,
            uint256 _totalStableReserve,
            uint256 _totalSpiceReserve,
            uint256 _totalStableBal,
            uint256 _cirulatingSpice
        );
}

contract BackingCalculator is IBackingCalculator {
    using SafeMath for uint256;

    IPair public usdtlp;
    IERC20 public usdt;
    address public SPICE;
    address public treasury;
    ISpiceCirculation public spiceCirculation;

    /* ======== INITIALIZATION ======== */
    constructor(
        address _SPICE,
        address _treasury,
        address _SPICECirculatingSupply,
        address _USDT,
        address _USDTLP
    ) {
        require(_SPICE != address(0));
        SPICE = _SPICE;
        require(_treasury != address(0));
        treasury = _treasury;
        require(_SPICECirculatingSupply != address(0));
        spiceCirculation = ISpiceCirculation(_SPICECirculatingSupply);
        require(_USDT != address(0));
        usdt = IERC20(_USDT);
        require(_USDTLP != address(0));
        usdtlp = IPair(_USDTLP);
    }

    function backing()
        external
        view
        override
        returns (uint256 _lpBacking, uint256 _treasuryBacking)
    {
        (_lpBacking, _treasuryBacking, , , , ) = backing_full();
    }

    function lpBacking() external view override returns (uint256 _lpBacking) {
        (_lpBacking, , , , , ) = backing_full();
    }

    function treasuryBacking()
        external
        view
        override
        returns (uint256 _treasuryBacking)
    {
        (, _treasuryBacking, , , , ) = backing_full();
    }

    //decimals for backing is 4
    function backing_full()
        public
        view
        override
        returns (
            uint256 _lpBacking,
            uint256 _treasuryBacking,
            uint256 _totalStableReserve,
            uint256 _totalSpiceReserve,
            uint256 _totalStableBal,
            uint256 _cirulatingSpice
        )
    {
        // lp
        uint256 stableReserve;
        uint256 spiceReserve;
        //usdtlp
        (spiceReserve, stableReserve) = spiceStableAmount(usdtlp);
        _totalStableReserve = _totalStableReserve.add(stableReserve);
        _totalSpiceReserve = _totalSpiceReserve.add(spiceReserve);

        _lpBacking = _totalStableReserve.div(_totalSpiceReserve).div(1e5);

        //treasury
        _totalStableBal = _totalStableBal.add(
            toE18(usdt.balanceOf(treasury), usdt.decimals())
        );
        _cirulatingSpice = spiceCirculation.SPICECirculatingSupply().sub(
            _totalSpiceReserve
        );
        _treasuryBacking = _totalStableBal.div(_cirulatingSpice).div(1e5);
    }

    function spiceStableAmount(IPair _pair)
        public
        view
        returns (uint256 spiceReserve, uint256 stableReserve)
    {
        (uint256 reserve0, uint256 reserve1, ) = _pair.getReserves();
        uint8 stableDecimals;
        if (_pair.token0() == SPICE) {
            spiceReserve = reserve0;
            stableReserve = reserve1;
            stableDecimals = IERC20(_pair.token1()).decimals();
        } else {
            spiceReserve = reserve1;
            stableReserve = reserve0;
            stableDecimals = IERC20(_pair.token0()).decimals();
        }
        stableReserve = toE18(stableReserve, stableDecimals);
    }

    function toE18(uint256 amount, uint8 decimals)
        public
        pure
        returns (uint256)
    {
        if (decimals == 18) return amount;
        else if (decimals > 18) return amount.div(10**(decimals - 18));
        else return amount.mul(10**(18 - decimals));
    }
}
