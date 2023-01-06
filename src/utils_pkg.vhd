library ieee;
use ieee.std_logic_1164.all;
use ieee.math_real.all;

package utils_pkg is

    pure function log2_ceil( i : positive ) return natural; 
    
end package;

package body utils_pkg is

    pure function log2_ceil( i : positive ) return natural is
        variable ret_val : integer;
	begin
        ret_val := integer(ceil(ieee.math_real.log2(real(i))));
		return ret_val;
	end function;

end utils_pkg;