//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "hardhat/console.sol";

// ----------------------INTERFACE------------------------------

// Aave
// https://docs.aave.com/developers/the-core-protocol/lendingpool/ilendingpool

//ILendingPool คือ address ของ Aave Lending Pool
interface ILendingPool {
    /**
     * Function to liquidate a non-healthy position collateral-wise, with Health Factor below 1
     * - The caller (liquidator) covers `debtToCover` amount of debt of the user getting liquidated, and receives
     *   a proportionally amount of the `collateralAsset` plus a bonus to cover market risk
     * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of theliquidation
     * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation
     * @param user The address of the borrower getting liquidated
     * @param debtToCover The debt amount of borrowed `asset` the liquidator wants to cover
     * @param receiveAToken `true` if the liquidators wants to receive the collateral aTokens, `false` if he wants
     * to receive the underlying collateral asset directly
     **/

    //เรียกใช้งานเมื่อเจอ account ที่ health factor ต่ำกว่า 1 และต้องการทำ liquidation 
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken //ปกติจะเป็น flase
    ) external;

    /**
     * Returns the user account data across all the reserves
     * @param user The address of the user
     * @return totalCollateralETH the total collateral in ETH of the user
     * @return totalDebtETH the total debt in ETH of the user
     * @return availableBorrowsETH the borrowing power left of the user
     * @return currentLiquidationThreshold the liquidation threshold of the user
     * @return ltv the loan to value of the user
     * @return healthFactor the current health factor of the user
     **/

    // เช็คว่า account ของ User มี health factor < 1 จริงรึเปล่า (ถ้าไม่เราจะไม่สามารถทำ liquidation account นี้ได้)
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

// UniswapV2

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IERC20.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/Pair-ERC-20

//IERC20 คือ type of token/asset ที่ใช้เป็น collateralAsset หรือ deptAsset
interface IERC20 {
    // Returns the account balance of another account with address _owner.
    //get number of token (USDT, WBTC) remaining
    function balanceOf(address owner) external view returns (uint256);

    /**
     * Allows _spender to withdraw from your account multiple times, up to the _value amount.
     * If this function is called again it overwrites the current allowance with _value.
     * Lets msg.sender set their allowance for a spender.
     **/
    //อนุมัติให้ Aave pool ที่เป็น spender เป็นคนทำการ liquidate
    function approve(address spender, uint256 value) external; // return type is deleted to be compatible with USDT

    /**
     * Transfers _value amount of tokens to address _to, and MUST fire the Transfer event.
     * The function SHOULD throw if the message caller’s account balance does not have enough tokens to spend.
     * Lets msg.sender send pool tokens to an address.
     **/
    function transfer(address to, uint256 value) external returns (bool);
}

// https://github.com/Uniswap/v2-periphery/blob/master/contracts/interfaces/IWETH.sol
//IWETH เป็น token ของ ETH blockchain
interface IWETH is IERC20 {
    // Convert the wrapped token back to Ether.
    function withdraw(uint256) external;
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Callee.sol
// The flash loan liquidator we plan to implement this time should be a UniswapV2 Callee

interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Factory.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/factory
interface IUniswapV2Factory {
    // Returns the address of the pair for tokenA and tokenB, if it has been created, else address(0).
    //get address ของ pool ที่ต้องการใช้ในการแลกเปลี่ยน Asset
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);
}

// https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Pair.sol
// https://docs.uniswap.org/protocol/V2/reference/smart-contracts/pair
interface IUniswapV2Pair {
    /**
     * Swaps tokens. For regular swaps, data.length must be 0.
     * Also see [Flash Swaps](https://docs.uniswap.org/contracts/v2/concepts/core-concepts/flash-swaps).
     **/
    //ใช้ทำ flash loan, ใส่ Asset หนึ่งเข้าไปเพื่อดึงอีก Asset หนึ่งออกมาตามอัตราส่วนของทั้ง 2 Asset ที่มีอยู่ใน pool นั้น (หลักการของ AMMDEX)
    //การ Swaps tokens. ถ้าเป็นการ swap ปกติ data.lenght จะเท่ากับ 0
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    /**
     * Returns the reserves of token0 and token1 used to price trades and distribute liquidity.
     * See Pricing[https://docs.uniswap.org/contracts/V2/concepts/advanced-topics/pricing].
     * Also returns the block.timestamp (mod 2**32) of the last block during which an interaction occured for the pair.
     **/
    //ดู จน. asset ทั้ง 2 ใน pool
    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );
}

// ----------------------IMPLEMENTATION------------------------------
//contract ในการทำ liquidation ที่สมบูรณ์แล้ว
contract LiquidationOperator2_2 is IUniswapV2Callee {
    // Solidity ไม่มี float ดังนั้น health_factor_decimals = 18 หมายถึง 1.00000000000000000(1 = 10^(18)) - 0.00000000000000000;
    uint8 public constant health_factor_decimals = 18;

    // TODO: define constants used in the contract including ERC-20 tokens, Uniswap Pairs, Aave lending pools, etc. */
    
    // ETH: basic type คือ address แต่ถ้ามีแต่ address จะทำให้ code ดูยาก จึงต้องมีการกำหนด type ให้แต่ล่ะ address ตาม code ด้านล่าง

    //ประกาศ token ที่ต้องใช้ในการทำ liquidation
    //IERC20 = อยู่ใน ETH blockchain
    IERC20 constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599); //IERC20($address ของ smart contract ที่เกี่ยวข้องกับเหรียญนั้นๆวึ่งหาได้เองใน internet)
    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); //IWETH($address ของ smart contract ที่เกี่ยวข้องกับเหรียญนั้นๆวึ่งหาได้เองใน internet)
    IERC20 constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    /**uniswapV2Factory(contract) ใช้ในการสร้าง pool หรือ get ข้อมูลต่างๆจาก pool เช่น มี pool นี้อยู่รึเปล่า,
     มี liquidity ของ asset ที่ 1 กับ 2 เป็นอย่างไร**/ 
    //IUniswapV2Factory($addresss of Uniswap contract)
    IUniswapV2Factory constant uniswapV2Factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);                                                                                               
    //IUniswapV2Pair immutable uniswapV2Pair_WETH_USDT; // Pool1 WETH/USDT
    IUniswapV2Pair immutable uniswapV2Pair_WBTC_USDT; // change Pool1 from WETH/USDT to WBTC/USDT*********************************************************
    IUniswapV2Pair immutable uniswapV2Pair_WBTC_WETH; // Pool2 WBTC/WETH

    //0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9 = address ของ Aave Lending pool ที่จะไป liquidate
    ILendingPool constant lendingPool = ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);

    //liquidationTarget = address ของ account ที่ต้องการไป liquidate
    address constant liquidationTarget = 0x59CE4a2AC5bC3f5F225439B2993b86B42f6d3e9F;
    //debt_USDT หนี้จากการกู้(USDT)
    uint debt_USDT;

    // END TODO

    // some helper function, it is totally fine if you can finish the lab without using these function
    // https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2Library.sol
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    // safe mul is not necessary since https://docs.soliditylang.org/en/v0.8.9/080-breaking-changes.html
    //getAmountIn() บอกจำนวน asset หนึ่ง ที่ต้องใส่เข้าไปใน pool เพื่อจะให้ได้อีก asset หนึ่งในจำนวนที่ต้องการ
    /**ให้ว่าค่าธรรมเนียม (fee) ในการ swap อยู่ที่ 0.3% พิสูจน์ว่าฟังก์ชั่น getAmountOut และ 
    getAmountIn return ค่าที่ถูกต้องตามหลักการของ constant product AMM**/
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // some helper function, it is totally fine if you can finish the lab without using these function
    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    // safe mul is not necessary since https://docs.soliditylang.org/en/v0.8.9/080-breaking-changes.html
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    constructor() {
        // TODO: (optional) initialize your contract
        //getPair() return address ของ pool ที่ต้องการ
        //uniswapV2Pair_WETH_USDT = IUniswapV2Pair(uniswapV2Factory.getPair(address(WETH), address(USDT))); // Pool1
        uniswapV2Pair_WBTC_USDT = IUniswapV2Pair(uniswapV2Factory.getPair(address(WBTC), address(USDT))); // change Pool1 from WETH/USDT to WBTC/USDT*********************************************************
        
        uniswapV2Pair_WBTC_WETH = IUniswapV2Pair(uniswapV2Factory.getPair(address(WBTC), address(WETH))); // Pool2
        //debt_USDT = จำนวน USDT ที่ไปกู้มา
        //debt_USDT = 2000000000; // 2000 USDT
        debt_USDT = 5000000000; // 5000 USDT
        //debt_USDT = 10000000000; // 10000 USDT
        
        // END TODO
    }

    // TODO: add a `receive` function so that you can withdraw your WETH
    //payable: ทำให้ account ที่รัน contract นี้สามารถรับทรัพย์สิน ETH เข้ามาได้
    receive() external payable {}

    // END TODO

    // required by the testing script, entry for your liquidation call
    function operate() external {
        // TODO: implement your liquidation logic

        // 0. security checks and initializing variables
        //    *** Your code here ***

        // 1. get the target user account data & make sure it is liquidatable
        
        uint256 totalCollateralETH;
        uint256 totalDebtETH;
        uint256 availableBorrowsETH;
        uint256 currentLiquidationThreshold;
        uint256 ltv;
        uint256 healthFactor;
        (
            totalCollateralETH,
            totalDebtETH,
            availableBorrowsETH,
            currentLiquidationThreshold,
            ltv,
            healthFactor
        ) = lendingPool.getUserAccountData(liquidationTarget); 
        //เช็คว่า health factor < 1 (ในที่นี้คือต้อง health factor < 10^(18))
        require(healthFactor < (10 ** health_factor_decimals), "Cannot liquidate; health factor must be below 1" );
        // 2. call flash swap to liquidate the target user
        // based on https://etherscan.io/tx/0xac7df37a43fab1b130318bbb761861b8357650db2e2c6493b73d6da3d9581077
        // we know that the target user borrowed USDT with WBTC as collateral
        // we should borrow USDT, liquidate the target user and get the WBTC, then swap WBTC to repay uniswap
        // (please feel free to develop other workflows as long as they liquidate the target user successfully)
        //ถ้า health factor < 1 เราจะ flash loan USDT ขนาดเท่ากับ debt ที่มี แต่ตอนนี้ยังไม่ได้ใส่ ETH ไปสักเหรียญ และจะจ่ายคืนเป็น ETH ภายหลัง 
        //ทำการ swap บน WETH/USDT pool, แต่การ swap นี้ data.lenght = 1 byte เพื่อระบุว่าเราจะไม่ใช้การ swap ปกติ แต่เป็นแบบ flash loan

        //uniswapV2Pair_WETH_USDT.swap(0, debt_USDT, address(this), "$");
        //uniswapV2Pair_WBTC_USDT.swap(amount0Out, amount1Out, to, data);
        uniswapV2Pair_WBTC_USDT.swap(0, debt_USDT, address(this), "$");//change Pool1 from WETH/USDT to WBTC/USDT*********************************************************

        // 3. Convert the profit into ETH and send back to sender

        uint balance = WETH.balanceOf(address(this));
        WETH.withdraw(balance);
        payable(msg.sender).transfer(address(this).balance);

        // END TODO
    }

    // required by the swap
    function uniswapV2Call(
        address,
        uint256,
        uint256 amount1,
        bytes calldata
    ) external override {
        // TODO: implement your liquidation logic

        // 2.0. security checks and initializing variables
        
        //เช็คว่าเป็น pool ที่เราไป flash loan มารึเปล่า (WETH/USDT) 
        //assert(msg.sender == address(uniswapV2Pair_WETH_USDT));
        assert(msg.sender == address(uniswapV2Pair_WBTC_USDT));//change Pool1 from WETH/USDT to WBTC/USDT*********************************************************
        
        //เช็คจำนวน WETH กับ USDT ของ pool1 และ เช็คจำนวน WBTC กับ WETH ของ pool2
        //(uint256 reserve_WETH_Pool1, uint256 reserve_USDT_Pool1, ) = uniswapV2Pair_WETH_USDT.getReserves(); // Pool1
        (uint256 reserve_WBTC_Pool1, uint256 reserve_USDT_Pool1, ) = uniswapV2Pair_WBTC_USDT.getReserves(); //change Pool1 from WETH/USDT to WBTC/USDT*********************************************************
        (uint256 reserve_WBTC_Pool2, uint256 reserve_WETH_Pool2, ) = uniswapV2Pair_WBTC_WETH.getReserves(); // Pool2
        console.log("uniswapV2Pair(%s): WBTC <> USDT", address(uniswapV2Pair_WBTC_USDT));
        console.log("reserve WBTC: %s", reserve_WBTC_Pool1);
        console.log("reserve USDT: %s", reserve_USDT_Pool1);

        console.log("uniswapV2Pair(%s): WBTC <> WETH", address(uniswapV2Pair_WBTC_WETH));
        console.log("reserve WBTC: %s", reserve_WBTC_Pool2);
        console.log("reserve WETH: %s", reserve_WETH_Pool2);

        // 2.1 liquidate the target user
        
        uint debtToCover = amount1;
        //console.log("debtToCover WETH: %s", amount1);
        //console.log("debtToCover WBTC: %s", amount1);
        //USDT.approve() อนุญาติให้ lendingPool ที่ address นี้สามารถใช้จ่าย USDT แทนเราได้เป็นจำนวนเท่ากับ debtToCover
        USDT.approve(address(lendingPool), debtToCover);

        //เรียก liquitaionCall() ผ่าน lendingPool, contract ของ leandingPool เป็นของ Aave (มี address เก็บไว้อยู่)
        //lendingPool.liquidationCall(collateralAsset, debtAsset, user, debtToCover = จำนวนหนี้ที่ต้องการจ่าย, receiveAToken = false หมายความว่าต้องการรับเป็น collateral ไม่เอา Aave token);
        lendingPool.liquidationCall(address(WBTC), address(USDT), liquidationTarget, debtToCover, false);

        //หลังจากทำ liauidationCall -> account ของ address(this) ได้รับ WBTC ตามราคาที่ลดลงมาเนื่องจาก liquidation space
        uint collateral_WBTC = WBTC.balanceOf(address(this));
        console.log("collateral_WBTC %s", collateral_WBTC);
        console.log("WBTC.balanceOf(address(this)) %s", WBTC.balanceOf(address(this)));


        // 2.2 swap WBTC for other things or repay directly
        //เอา WBTC ที่ได้มาบางส่วนมาแลก ETH เพื่อให้เพียงพอต่อการนำไปใช้หนี้ flash loan (การกู้) ในตอนแรก
        //transfer collateral_WBTC ทั้งหมดที่ได้จากการทำ liquidation ไปที่ pool ของ uniswapV2Pair_WBTC_WETH
        //WBTC.transfer(address(uniswapV2Pair_WBTC_WETH), collateral_WBTC);
        //getAmountOut() หลังจาก tranfer WBTC เข้าไปใน pool แลัวจะได้ WETH ออกมาเท่าไร
        //uint amountOut_WETH = getAmountOut(collateral_WBTC, reserve_WBTC_Pool2, reserve_WETH_Pool2);



        //data.lenght = 0 -> ทำ regular swap(ต้องใส่ assetหนึ่ง(WBTC) เข้าไปก่อน(transfer ด้านบน)เพื่อดึง อีกasset(WETH) ออกมา): ดึง ETH ออกมาจำนวนเท่ากับ amountOut_WETH ไปให้ address(this)
        //uniswapV2Pair_WBTC_WETH.swap(0, amountOut_WETH, address(this), "");


        
        // 2.3 repay
        //getAmountIn() = จำนวน ETH จริงๆที่ต้องใช้คืนจากการที่ไปกู้ USDT ในตอนแรก

        //uint repay_WETH = getAmountIn(debtToCover, reserve_WETH_Pool1, reserve_USDT_Pool1);

        uint repay_WBTC = getAmountIn(debtToCover, reserve_WBTC_Pool1, reserve_USDT_Pool1);//change Pool1 from WETH/USDT to WBTC/USDT*********************************************************


        //console.log("repay_WETH: %s", repay_WETH);
        console.log("repay_WBTC: %s", repay_WBTC);//change Pool1 from WETH/USDT to WBTC/USDT*********************************************************

        //transfer repay_WETH ไปยัง uniswapV2Pair_WETH_USDT เพื่อใช้หนี้ swap ที่เรา flash loan มาในตอนแรก uniswapV2Pair_WETH_USDT.swap(0, debt_USDT, address(this), "$");
        //WETH.transfer(address(uniswapV2Pair_WETH_USDT), repay_WETH);
        WBTC.transfer(address(uniswapV2Pair_WBTC_USDT), repay_WBTC);//change Pool1 from WETH/USDT to WBTC/USDT*********************************************************


        //2.4 convert WBTC remaining to WETH for calculate profit
        uint balance_WBTC_remaining = WBTC.balanceOf(address(this));
        WBTC.transfer(address(uniswapV2Pair_WBTC_WETH), balance_WBTC_remaining);
        uint amountOut_WETH = getAmountOut(balance_WBTC_remaining, reserve_WBTC_Pool2, reserve_WETH_Pool2); //ETH ที่เป็นกำไร 
        uniswapV2Pair_WBTC_WETH.swap(0, amountOut_WETH, address(this), "");

        // END TODO
    }
}
