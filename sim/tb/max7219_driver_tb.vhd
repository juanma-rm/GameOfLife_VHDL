----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
-- max7219_driver_tb.vhd
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

entity max7219_driver_tb is
end;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture bench of max7219_driver_tb is

    -- Constants


    -- Clock and reset

    constant clk_period_ns_c : time := 100 ns; -- 10 MHz
    signal clk_s    : std_ulogic := '0';
    signal rst_s    : std_ulogic := '0';

    -- dut signals

    constant num_segments_c  : positive := 8;
    constant word_width_c    : positive := 8;
    constant num_addresses_c : positive := 16;
    
    signal addr_s     : std_logic_vector(7 downto 0);
    signal data_s     : std_logic_vector(7 downto 0);
    signal start_s    : std_logic; 
    signal done_s     : std_logic;
    signal done_reg_s : std_logic;

    -- Commands
    signal cmd_index_s      : integer := 0;
    type command_t is record
        addr    : std_logic_vector(7 downto 0);
        data    : std_logic_vector(7 downto 0);
    end record;
    constant num_commands_c : positive := 6;
    type command_list_t is array (0 to num_commands_c-1) of command_t;
    signal command_list_s : command_list_t := (
        00 => (addr => x"09", data => x"00"),
        01 => (addr => x"0A", data => x"03"),
        02 => (addr => x"0B", data => x"07"),
        03 => (addr => x"0C", data => x"01"),
        04 => (addr => x"0F", data => x"00"),
        05 => (addr => x"01", data => x"AA")
    );

begin

    --------------------------------------------------------------
    -- Clock and reset
    --------------------------------------------------------------

    clk_s <= not clk_s after clk_period_ns_c/2;
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
    -- DUT
    --------------------------------------------------------------

    max7219_driver_inst : entity work.max7219_driver
        generic map (
            num_segments_g  => num_segments_c,
            word_width_g    => word_width_c,
            num_addresses_g => num_addresses_c
        )
        port map (
            clk_i         => clk_s,
            rst_i         => rst_s,
            addr_i        => addr_s(3 downto 0),
            data_i        => data_s,
            start_i       => start_s,
            done_o        => done_s,
            max7219_clk_o => open,
            max7219_din_o => open,
            max7219_csn_o => open,
            addr_o        => open,
            data_o        => open,
            state_slv_o   => open
        );
  

    --------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------

    addr_s  <= command_list_s(cmd_index_s).addr;
    data_s  <= command_list_s(cmd_index_s).data;

    process (clk_s)
    begin
        if rising_edge(clk_s) then
            if rst_s = '1' then
                cmd_index_s <= 0;
            elsif start_s = '1' and done_s = '1' and done_reg_s = '0' and cmd_index_s < num_commands_c - 1 then
                cmd_index_s <= cmd_index_s + 1;
            end if;
        end if;
    end process;
    
    process (clk_s)
    begin
        if rising_edge(clk_s) then
            if rst_s = '1' or cmd_index_s = num_commands_c - 1 then
                start_s <= '0';
            elsif done_s = '1' then
                start_s <= '1';
            end if;
        end if;
    end process;

    process (clk_s)
    begin
        if rising_edge(clk_s) then
            if rst_s = '1'then
                done_reg_s <= '0';
            else
                done_reg_s <= done_s;
            end if;
        end if;
    end process;

    --------------------------------------------------------------
    -- Check
    --------------------------------------------------------------


end;
