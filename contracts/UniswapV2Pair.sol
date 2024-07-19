// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.5.16;

import './libraries/Math.sol';
import './libraries/UQ112*112.sol';  // library for handling fix numbers heaving 112 integer bits and 112 fractional bits
import './interfaces/IUniswapV2Callee.sol';
import './interfaces/IUniswapV2Pair.sol';
import './interfaces/IUniswapV2Factory.sol';
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import './interfaces/IERC20.sol';
import './UniswapV2ERC20.sol';

contract UniswapV2Pair is IUniswapV2Pair, UniswapV2ERC20{
    // using SafeMath for uint;
    using UQ112x112 for uint224;
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('trasfer(address, uint256)')));

    address public factory;
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32  private blockTimestampLast;

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint public kLast;  // reserve0 * reserve1 immediately after the most recent liquidity event (like minitng or burinig the liquidity tokens)

    uint private unlocked = 1;
    modifier lock(){
        require(unlocked == 1, 'UniswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;

    }

    constructor () public{
       factory = msg.sender;   
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'UniswapV2: FORBIDDEN'); // sufficient checkes
        token0 = _token0;
        token1 = _token1;


    } 

    function _safeTransfer(address token, address to, uint value) private{
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))),'UNISWAP V2: TRASFER_FALIED');
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast){
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }


    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );

    event Sync(uint112 reserve0, uint112 reserve1);
    /*
       maintaining accurate reserves and syncing the reserves with the current token balance
       update the stored reserves of the pair and handle the calcualtion of reserve price

    */

    function _update(uint _balance0, uint _balance1, uint112 _reserve0, uint112 _reserve1) private{
         require(_balance0 <= uint112(-1) && _balance1 <= uint112(-1), 'UNISWAPV2: OVERFLOW');
         uint32 blockTimestamp = uint32(block.timestamp % 2**32);
         uint32 timeElapsed = blockTimestamp - blockTimestampLast;
         if(timeElapsed > 0 && reserve0 !=0 && reserve1  !=0){
            price0CumulativeLast +=  UQ112x112.encode(_reserve1).uqdiv(_reserve0);      // cumulative price are use to calcuate time weighted avg price(TWAP) that can be used by any orcale,defi  
            price1CumulativeLast += UQ112x112.encode(_reserve0).uqdiv(_reserve1);     // these veriable stores sum of prices of token1 in ter of token0 and token0 in term of token1 
         } 
         reserve0 = uint112(_balance0);
         reserve1 = uint112(_balance1);
         blockTimestampLast = blockTimestamp;
         emit Sync(reserve0, reserve1);
    }  
    /*
    this should be called by an contract that perform saftly checkes
    this mechanism maintin the constant product formula whille ensuring LP providers 
    are fairly compensated for the participation in the pool
    */

    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns(bool feeOn){
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings

        if(feeOn){
            if(_kLast !=0){
                uint rootK = Math.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = Math.sqrt(_kLast);
                if(rootK > rootKLast){
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast)); // totalSupply is the supply of LP tokens
                    uint denominator = rootK.mul(5).add(rootKLast); //  mult 5 determine the rate at which the additional liquidity shold grow

                    uint liquidity = numerator / denominator;
                    if(liquidity > 0) _mint(feeTo, liquidity);
                }

            }
        }else if(_kLast !=0){
            kLast = 0;
        }
    }

    // adding liquidity

    function mint(address to) external lock returns (uint liquidity){
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
   
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);
        
        bool feeOn = _mintFee(_reserve0, _reserve1); // if reserves increases , it will mint liquidity as LP tokens
        uint _totalSupply = totalSupply; 
        if(_totalSupply == 0){
            liquidity = Math.sqrt((amount0).mul(amount1)).sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY); //setup intial liquitity supply.it helpt to set baseline to mantain propotial distribution of lp tokens
        } else{
            liquidity = Math.min(amount0.mul(_totalSupply)/ _reserve0, amount1.mul(_totalSupply)/ _reserve1);

        }
        require(liquidity > 0, 'UNISWAPV2: INSUFFICENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if(feeOn) kLast = uint(reserve0).mul(reserve1); 
        emit Mint(msg.sender, amount0, amount1);
    }

    // remove liquidity  and sent back the amount0, amount1 from underlaying token token0 , token1 addresses
    function burn(address to) external lock returns (uint amount0, uint amount1){
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply;
        amount0 = liquidity.mul(balance0) / _totalSupply;
        amount1 = liquidity.mul(balance1) / _totalSupply;
        require(amount0 > 0 && amount1 > 0, 'UNISWAP V2: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1);
        emit Burn(msg.sender, amount0, amount1, to); 

    }

    // this low-level function should be called from a contract which performs important safety checks

    function swap(uint amount0out, uint amount1out, address to, bytes calldata data) external lock{
        require(amount0out > 0 || amount1out > 0, 'UNISWAPV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0out < _reserve0 && amount1out < _reserve1, 'UNISWAPV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        {
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, 'UNISWAPV2: INVALID_TO');
            if(amount0out > 0) _safeTransfer(_token0, to, amount0out);  // optimistically token transfer
            if(amount1out > 0) _safeTransfer(_token1, to, amount1out); // optimistically token transfer

            if (data.length > 0) IUniswapV2Callee(to).uniswapV2Call(msg.sender, amount0out, amount1out, data);

            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));

        }
        uint amount0In = balance0 > _reserve0 - amount0out ? balance0 - (_reserve0 - amount0out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1out ? balance1 - (_reserve1 - amount1out) : 0;
        require(amount0In > 0 || amount1In > 0 , 'UNISWAPV2: INSUFFICIENT_INPUT_AMOUNT');
        {
            //use to maintain the inveriant of the liqudutuy pool after applying the small fee to each trade
            //  balance0 * 1000 - amount0In * 3 / 1000 =   balance0 * 1000 - amount0In * 3
            uint balance0Adjusted = balance0.mul(1000).sub(amount0In.mul(3));   
            uint balance1Adjusted = balance1.mul(1000).sub(amount1In.mul(3));
            /*
                By calculating balance0Adjusted and balance1Adjusted, the contract 
                can enforce that the product of the reserves after fees is equal to or greater 
                than the product before the trade, upholding the integrity of the pool.
            */
            require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(1000**2), 'UNISWAPV2: k');

        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0out, amount1out, to);

    } 

    /*
    used to transfer any excess tokens in the liquidity pool contract to a specified address. This function
    helps ensure that the reserves reported by the contract match the actual token balances held by the contract.
    */
    /*
    The skim function is designed to handle cases where the actual token balances in the contract are greater than the reported reserves. 
    This can happen due to rounding errors, direct token transfers to the contract address, or other anomalies.
    */

    function skim(address to) external lock{
        address _token0 = token0; 
        address _token1 = token1;
        _safeTransfer(_token0, to, IERC20(token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IERC20(token1).balanceOf(address(this)).sub(reserve1));
    } 

    // force reserve to match balance

    function sync() external lock{
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

}




