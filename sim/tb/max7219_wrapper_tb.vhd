----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
--! max7219_wrapper_tb.vhd
--! 
--! 
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils_pkg.all;
use std.env.finish;

entity max7219_wrapper_tb is
end entity;

architecture behavioural of max7219_wrapper_tb is

    -- Constants


    -- Clock and reset

    constant clk_period_ns_c : time := 100 ns; -- 10 MHz
    signal clk_s    : std_ulogic := '0';
    signal rst_s    : std_ulogic := '0';

    -- dut signals
    signal macro_cmd_i   : std_logic_vector(log2_ceil(3) - 1 downto 0);
    signal data_all_i    : std_logic_vector(8*8 - 1 downto 0);
    signal addr_i        : std_logic_vector(log2_ceil(16) - 1 downto 0);
    signal data_i        : std_logic_vector(8 - 1 downto 0);
    signal start_i       : std_logic;
    signal done_o        : std_logic;
    signal max7219_clk_o : std_logic;
    signal max7219_din_o : std_logic;
    signal max7219_csn_o : std_logic;

begin

    --------------------------------------------------------------
    -- Clock and reset
    --------------------------------------------------------------

    clk_s <= not clk_s after clk_period_ns_c/2;
    rst_s <= '0', '1' after 10*clk_period_ns_c, '0' after 20*clk_period_ns_c;

    --------------------------------------------------------------
    -- Main process
    --------------------------------------------------------------

    -- process
    -- begin
    --     wait for 30 us;
    --     finish;                       
    -- end process;

    --------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------

    max7219_wrapper_inst : entity work.max7219_wrapper
        generic map (
            num_segments_g      => 8,
            word_width_g        => 8,
            num_addresses_g     => 16,
            num_macro_cmds_g    => 3,
            segment_id_offset_g => 1
        )
        port map (
            clk_i         => clk_s,
            rst_i         => rst_s,
            macro_cmd_i   => macro_cmd_i,
            data_all_i    => data_all_i,
            addr_i        => addr_i,
            data_i        => data_i,
            start_i       => start_i,
            done_o        => done_o,
            max7219_clk_o => max7219_clk_o,
            max7219_din_o => max7219_din_o,
            max7219_csn_o => max7219_csn_o
        );

    --------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------

    macro_cmd_i <= "00", "10" after 10 us, "01" after 15 us;
    data_all_i <= (others => '1');
    addr_i <= (others => '1');
    data_i <= (others => '1');
    start_i <= '1', '0' after 20 us;

end architecture;
