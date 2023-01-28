----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
--! max7219_driver.vhd
--! 
--! Driver to control a max7219 device, consisting of 8 digits, 7+1 segments wide each
--! The internal memory consists of 16 addresses, 8-bit wide each
--! Each command sent to de device must follow the following (binary) format:
--!     0000 XXXX YYYYYYYY, being right-most bit the most significative
--!     XXXX: register address
--!     YYYYYYYY: data to be written on addressed register
--! 
--! Register map:
--!     Purpose         | Address (hex)
--!     --------        | -------------
--!     No-Op           |    0xX0
--!     Digit0          |    0xX1
--!     ...             |    ...
--!     Digit7          |    0xX8
--!     Decode Mode     |    0xX9
--!     Intensity       |    0xXA
--!     Scan Limit      |    0xXB
--!     Shutdown        |    0xXC
--!     Display Test    |    0xXF

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Internal package
----------------------------------------------------------------------------------

-- use work.utils_pkg.all;

-- package max7219_pkg is
--     constant command_width_c : positive := 16; -- (msb) 4-bit dummy, 4-bit address, 8-bit data (lsb)
--     constant num_addresses_c : positive := 16;
--     constant addr_width_c    : positive := log2_ceil(num_addresses_c);
--     constant word_width_c    : positive := 8;
-- end package;

----------------------------------------------------------------------------------
-- Libraries
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils_pkg.all;
-- use work.max7219_pkg.all;

----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity max7219_driver is
    port (
        clk_i         : in  std_logic;
        rst_i         : in  std_logic;
        addr_i        : in  std_logic_vector(4 - 1 downto 0);
        data_i        : in  std_logic_vector(8 - 1 downto 0);
        start_i       : in  std_logic;
        done_o        : out std_logic;
        max7219_clk_o : out std_logic;
        max7219_din_o : out std_logic;
        max7219_csn_o : out std_logic := '1'
    );
end entity;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture behavioural of max7219_driver is

    constant command_width_c : positive := 16; -- (msb) 4-bit dummy, 4-bit address, 8-bit data (lsb)
    constant num_addresses_c : positive := 16;
    constant addr_width_c    : positive := log2_ceil(num_addresses_c);
    constant word_width_c    : positive := 8;


    type state_t is (st_init, st_enable_csn, st_send_data);
    signal state_s : state_t;

    signal command_s        : std_logic_vector(command_width_c - 1 downto 0);
    signal max7219_addr_s   : std_logic_vector(addr_width_c - 1 downto 0);
    signal max7219_data_s   : std_logic_vector(word_width_c - 1 downto 0);

    signal bit_sent_index_s : integer range 0 to command_width_c - 1;
    signal command_done_s   : boolean := true;

begin
    
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
                bit_sent_index_s <= command_width_c - 1;
            elsif (state_s = st_send_data and bit_sent_index_s > 0) then
                bit_sent_index_s <= bit_sent_index_s - 1;
            elsif (state_s = st_send_data) then
                bit_sent_index_s <= 0;
            end if;
        end if;
    end process;
    command_done_s <= true when bit_sent_index_s = 0 else false;

    command_s(word_width_c - 1                downto                           0) <= data_i;          -- data
    command_s(word_width_c + addr_width_c - 1 downto                word_width_c) <= addr_i;          -- address
    command_s(command_width_c - 1             downto word_width_c + addr_width_c) <= (others => '0'); -- dummy    

    -- Outputs
    max7219_din_o  <= command_s(bit_sent_index_s);
    max7219_csn_o <= '1' when state_s = st_init else '0';
    max7219_clk_o <= clk_i;
    done_o <= '1' when state_s = st_init else '0';

end architecture;
