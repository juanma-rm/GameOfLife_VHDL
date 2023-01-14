----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
--! game_of_life_top.vhd
--! 
--! @todo description
--! 
--! 
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils_pkg.all;

entity game_of_life_top is
    port (
        clk_i         : in  std_logic;
        rst_i         : in  std_logic;
        max7219_clk_o : out std_logic;
        max7219_din_o : out std_logic;
        max7219_csn_o : out std_logic := '1';

        -- temp
        macro_cmd_o   : out std_logic_vector(2 - 1 downto 0);
        start_o       : out std_logic;
        done_rose_o   : out std_logic
    );
end entity;

architecture behavioural of game_of_life_top is

    -- max7219 @todo remove hardcoded
    signal macro_cmd_i   : std_logic_vector(log2_ceil(3) - 1 downto 0);
    signal data_all_i    : std_logic_vector(8*8 - 1 downto 0);
    signal addr_i        : std_logic_vector(log2_ceil(16) - 1 downto 0);
    signal data_i        : std_logic_vector(8 - 1 downto 0);
    signal start_i       : std_logic;
    signal done_o        : std_logic;

    -- max7219 test
    signal done_last_s   : std_logic;
    signal done_rose_s   : std_logic;
    signal count_s       : integer := 0;

begin


    -- max7219 test

    -- Register done_o signal
    process (clk_i) 
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then done_last_s <= '0';
            else                done_last_s <= done_o;
            end if;
        end if;
    end process;

    -- done_rose_s goes high if done rose during last cycle
    done_rose_s <= '1' when (done_last_s = '0' and done_o = '1') else '0';

    -- TEMP DEBUG
    start_o <= start_i;
    macro_cmd_o <= macro_cmd_i;
    
    -- Count up when done_rose_s; count determines next macro command to send
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then          count_s <= 0;
            elsif done_rose_s = '1' then count_s <= count_s + 1;
            end if;
        end if;
    end process;

    -- Control start_i and macro_cmd_i according to current count
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if    count_s = 1 then start_i <= '1'; macro_cmd_i <= "00"; -- initialization
            elsif count_s = 2 then start_i <= '1'; macro_cmd_i <= "01"; -- write_all (diagonal line of leds on)
            elsif count_s = 3 then start_i <= '1'; macro_cmd_i <= "10"; -- third row all 1s
            else                   start_i <= '0'; macro_cmd_i <= "10";
            end if;
        end if;
    end process;

    data_all_i <= "1100000011000000001000000001000000001000000001000000001100000011";
    addr_i     <= "0001";
    data_i     <= "01010111";

    -- max7219
    max7219_wrapper_inst : entity work.max7219_wrapper
        generic map (
            num_segments_g      => 8,
            word_width_g        => 8,
            num_addresses_g     => 16,
            num_macro_cmds_g    => 3,
            segment_id_offset_g => 1
        )
        port map (
            clk_i            => clk_i,
            rst_i            => rst_i,
            macro_cmd_i      => macro_cmd_i,
            data_all_i       => data_all_i,
            addr_i           => addr_i,
            data_i           => data_i,
            start_i          => start_i,
            macro_cmd_done_o => done_o,
            max7219_clk_o    => max7219_clk_o,
            max7219_din_o    => max7219_din_o,
            max7219_csn_o    => max7219_csn_o
        );
    

end architecture;
