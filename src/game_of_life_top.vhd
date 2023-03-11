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
        next_iter_i   : in std_logic
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

    -- cells test
    signal done_last_s   : std_logic;
    signal done_rose_s   : std_logic;
    signal count_s       : integer := 0;
    signal next_gen_done_s : std_logic;

begin

    -- cells test

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
            else                   start_i <= '1'; macro_cmd_i <= "01"; -- write_all
            end if;
        end if;
    end process;


    cells_isnt : entity work.cells
        port map (
            clk_i         => clk_i,
            rst_i         => rst_i,
            next_iter_i   => next_iter_i,
            done_o        => next_gen_done_s,
            cells_arr_o   => data_all_i
        );

    -- max7219
    max7219_wrapper_inst : entity work.max7219_wrapper
        port map (
            clk_i            => clk_i,
            rst_i            => rst_i,
            macro_cmd_i      => macro_cmd_i,
            data_all_i       => data_all_i,
            addr_i           => (others => '0'),
            data_i           => (others => '0'),
            start_i          => next_gen_done_s,
            macro_cmd_done_o => done_o,
            max7219_clk_o    => max7219_clk_o,
            max7219_din_o    => max7219_din_o,
            max7219_csn_o    => max7219_csn_o
        );
    

end architecture;
