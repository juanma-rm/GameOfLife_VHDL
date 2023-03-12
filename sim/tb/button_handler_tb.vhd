----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- button_handler_tb.vhd
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

entity button_handler_tb is
end;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture bench of button_handler_tb is

    -- Constants


    -- Clock and reset

    constant clk_period_ns_c : time := 1000 ns; -- 1 MHz
    signal clk_s    : std_ulogic := '0';
    signal rst_s    : std_ulogic := '0';

    -- dut signals
    signal buttons_s    : std_logic_vector(5-1 downto 0);
    signal event_read_s : std_logic_vector(5-1 downto 0);

begin

    --------------------------------------------------------------
    -- Clock and reset
    --------------------------------------------------------------

    clk_s    <= not clk_s after clk_period_ns_c/2;
    rst_s <= '0', '1' after 10*clk_period_ns_c, '0' after 20*clk_period_ns_c;

    --------------------------------------------------------------
    -- Main process
    --------------------------------------------------------------

    -- process
    -- begin
        -- wait for 30 us;
    --     finish;                       
    -- end process;

    --------------------------------------------------------------
    -- DUT and other instances
    --------------------------------------------------------------

    button_handler_inst : entity work.button_handler
        port map (
            clk_i           => clk_s,
            rst_i           => rst_s,
            buttons_raw_i   => buttons_s,
            buttons_evnts_o => open,
            event_read_i    => event_read_s
        );

    --------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------

    process
    begin
        
        buttons_s <= (others => '0');
        event_read_s <= (others => '0');
        wait for 100 us;
        
        -- Simulate metastability (though not affecting simulation)
        buttons_s(0) <= '1'; wait for 5730 ns;   buttons_s(0) <= '0'; wait for 3050 ns; buttons_s(0) <= '1'; wait for 908 ns; buttons_s(0) <= '0'; wait for 2020 ns;
        
        -- Simulate no event (< 50 ms)
        buttons_s(0) <= '1'; wait for 40 ms;  buttons_s(0) <= '0'; wait for 20 ms;
        -- Read no event
        event_read_s(0) <= '1'; wait for 1 us; event_read_s(0) <= '0'; wait for 20 ms;

        -- Simulate no event (>= 50 ms)
        buttons_s(0) <= '1'; wait for 70 ms;  buttons_s(0) <= '0'; wait for 20 ms;
        -- Read no event
        event_read_s(0) <= '1'; wait for 1 us; event_read_s(0) <= '0'; wait for 20 ms;

        -- Simulate long event
        buttons_s(0) <= '1'; wait for 2100 ms;  buttons_s(0) <= '0'; wait for 20 ms;
        -- Read long event
        event_read_s(0) <= '1'; wait for 1 us; event_read_s(0) <= '0'; wait for 20 ms;
        
        -- Simulate short event
        buttons_s(0) <= '1'; wait for 70 ms;  buttons_s(0) <= '0'; wait for 200 ms;
        -- Simulate none event without reading the previous one
        buttons_s(0) <= '1'; wait for 30 ms;  buttons_s(0) <= '0'; wait for 20 ms;
        -- Read none event
        event_read_s(0) <= '1'; wait for 1 us; event_read_s(0) <= '0'; wait for 20 ms;        

        finish;                       
    end process;

    --------------------------------------------------------------
    -- Check
    --------------------------------------------------------------


end;
