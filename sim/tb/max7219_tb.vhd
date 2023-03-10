----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- max7219_tb.vhd
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Import of libraries and packages
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity max7219_tb is
end;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture bench of max7219_tb is

    -- Constants


    -- Clock and reset

    constant clk_period_ns_c : time := 100 ns; -- 10 MHz
    signal clk_s    : std_ulogic := '0';
    signal rst_s    : std_ulogic := '0';

    -- dut signals

begin

    --------------------------------------------------------------
    -- Clock and reset
    --------------------------------------------------------------

    clk_s    <= not clk_s after clk_period_ns_c/2;
    rst_s <= '0', '1' after 10*clk_period_ns_c, '0' after 20*clk_period_ns_c;

    --------------------------------------------------------------
    -- Main process
    --------------------------------------------------------------

    process
    begin
        wait for 30 us;
        finish;                       
    end process;

    --------------------------------------------------------------
    -- DUT and other instances
    --------------------------------------------------------------

    max7219_inst : entity work.max7219
        port map (
            clk_i           => clk_s,
            rst_i           => rst_s,
            max7219_clk_o   => open,
            max7219_din_o   => open,
            max7219_csn_o   => open
        );

    --------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------



    --------------------------------------------------------------
    -- Check
    --------------------------------------------------------------


end;
