----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
--! max7219_driver.vhd
--! 
--! Driver to control a set of num_segments_g LED segments, each word_width_g wide
--! The internal memory consists of num_addresses_g addresses, each word_width_g wide
--! 
--! 
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

-- package max7219_pkg is
    
-- end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
-- use work.max7219_pkg.all;
use work.utils_pkg.all;

entity max7219_driver is
    generic (
        num_segments_g  : positive := 8;
        word_width_g    : positive := 8;
        num_addresses_g : positive := 16 -- @todo check < 2^8
    );
    port (
        clk_i         : in  std_logic;
        rst_i         : in  std_logic;
        addr_i        : in  std_logic_vector(log2_ceil(num_addresses_g) - 1 downto 0);
        data_i        : in  std_logic_vector(word_width_g - 1 downto 0);
        start_i       : in  std_logic;
        done_o        : out std_logic;
        max7219_clk_o : out std_logic;
        max7219_din_o : out std_logic;
        max7219_csn_o : out std_logic := '1';

        -- TEMP
        addr_o           : out std_logic_vector(7 downto 0);
        data_o           : out std_logic_vector(7 downto 0);
        state_slv_o      : out std_logic_vector(1 downto 0)
    );
end entity;

architecture behavioural of max7219_driver is

    type state_t is (st_init, st_enable_csn, st_send_data);
    signal state_s : state_t;

    signal max7219_addr_s   : std_logic_vector(7 downto 0);
    signal max7219_data_s   : std_logic_vector(7 downto 0);

    signal bit_sent_index_s : integer range 0 to 15;
    signal command_done_s   : boolean := true;

begin

    -- TEMP
    process (state_s)
    begin
        if state_s = st_init then
            state_slv_o <= "00";
        elsif (state_s = st_enable_csn) then
            state_slv_o <= "01";
        elsif (state_s = st_send_data) then
            state_slv_o <= "10";
        end if;
    end process;
    
    -- FSM
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state_s <= st_init;
            else
                case state_s is
                    when st_init       => if (start_i = '1') then state_s <= st_enable_csn; end if;
                    when st_enable_csn => state_s <= st_send_data;
                    when st_send_data  => if (command_done_s) then state_s <= st_init; end if;
                    when others        => state_s <= st_init;
                end case;
            end if;
        end if;
    end process;

    -- bit_sent_index_s (count from 15 to 0: 8 msb for addr, 8 lsb for data)
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if state_s = st_init then
                bit_sent_index_s <= 15;
            elsif (state_s = st_send_data and bit_sent_index_s > 0) then
                bit_sent_index_s <= bit_sent_index_s - 1;
            elsif (state_s = st_send_data) then
                bit_sent_index_s <= 0;
            end if;
        end if;
    end process;
    command_done_s <= true when bit_sent_index_s = 0 else false;

    -- Outputs
    max7219_addr_s(7 downto 4) <= (others => '0');
    max7219_addr_s(3 downto 0) <= addr_i;
    max7219_data_s <= data_i;
    max7219_din_o  <= max7219_addr_s(bit_sent_index_s - 8) when bit_sent_index_s > 7
                    else max7219_data_s(bit_sent_index_s);
    max7219_csn_o <= '1' when state_s = st_init else '0';
    max7219_clk_o <= clk_i;
    done_o <= '1' when state_s = st_init else '0';

end architecture;
