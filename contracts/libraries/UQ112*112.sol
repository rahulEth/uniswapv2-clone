pragma solidity =0.5.16;

// a library for handling binary fixed point numbers (https://en.wikipedia.org/wiki/Q_(number_format))

// range: [0, 2**112 - 1]
// resolution: 1 / 2**112
/** 
 * this library use to hanlde fixed point numbers 112.112 but fixed-point numbers
 * 
*/

/**\
 * these functions ensure that arthmatic operations maintain the precision and avoid the overflow issues
 * which is essential for current functionality of defi protocols
   */
library UQ112x112 {

    // this is fixed point scaling factor 2^112 , it is used to convert uint112 integer into UQ112*112 fixed-point format

    uint224 constant Q112 = 2**112;

    // encode a uint112 as a UQ112x112 fixed-point number
    function encode(uint112 y) internal pure returns (uint224 z) {
        //uint224 z: The encoded UQ112x112 fixed-point number.
        z = uint224(y) * Q112; // never overflows  
    }

    // Divides a UQ112x112 fixed-point number by a uint112 number, returning a UQ112x112 fixed-point number.
    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}