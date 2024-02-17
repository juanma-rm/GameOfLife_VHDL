----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- game_of_life_top_tb.vhd
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Import of libraries and packages
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.finish;

use work.utils_pkg.all;

----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity game_of_life_top_tb is
end;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture bench of game_of_life_top_tb is

    -- Constants


    -- Clock and reset

    constant clk_period_ns_c : time := 1000 ns; -- 1 MHz
    signal clk_s    : std_ulogic := '0';
    signal rst_s    : std_ulogic := '0';

    -- dut signals

    signal cells_arr_s  : std_logic_vector(8*8-1 downto 0);
    signal done_s       : std_logic;
    signal next_iter_s  : std_logic;
    signal buttons_s    : std_logic_vector(5-1 downto 0);
    signal event_read_s : std_logic_vector(5-1 downto 0);


begin

    --------------------------------------------------------------
    -- Clock and reset
    --------------------------------------------------------------

    clk_s <= not clk_s after clk_period_ns_c/2;
    rst_s <= '0', '1' after 10*clk_period_ns_c, '0' after 20*clk_period_ns_c;

    --------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------

    game_of_life_top_inst : entity work.game_of_life_top
        port map (
            clk_i         => clk_s,
            rst_i         => rst_s,
            max7219_clk_o => open,
            max7219_din_o => open,
            max7219_csn_o => open,
            buttons_i     => buttons_s
        );  
  
    --------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------

    process
    begin
        
        buttons_s <= (others => '0');
        event_read_s <= (others => '1');
        wait for 100 us;
        
        -- Short center (> 50 ms)
        buttons_s(0) <= '1'; wait for 60 ms;   buttons_s(0) <= '0'; wait for 20 us; 
        -- Short down (> 50 ms)
        buttons_s(2) <= '1'; wait for 60 ms;   buttons_s(2) <= '0'; wait for 20 us; 
        -- Short center (> 50 ms)
        buttons_s(0) <= '1'; wait for 60 ms;   buttons_s(0) <= '0'; wait for 20 us; 
        -- Long center (> 50 ms)
        buttons_s(0) <= '1'; wait for 2050 ms;   buttons_s(0) <= '0'; wait for 20 us;     
        
        -- Pass several generations
        -- Short center (< 50 ms)
        buttons_s(0) <= '1'; wait for 60 ms;   buttons_s(0) <= '0'; wait for 20 us; 
        -- Short center (< 50 ms)
        buttons_s(0) <= '1'; wait for 60 ms;   buttons_s(0) <= '0'; wait for 20 us; 
        -- Short center (< 50 ms)
        buttons_s(0) <= '1'; wait for 60 ms;   buttons_s(0) <= '0'; wait for 20 us; 
        -- Short center (< 50 ms)
        buttons_s(0) <= '1'; wait for 60 ms;   buttons_s(0) <= '0'; wait for 20 us;                                    

        wait;
        -- finish;                       
    end process;

    --------------------------------------------------------------
    -- Check
    --------------------------------------------------------------


end;
