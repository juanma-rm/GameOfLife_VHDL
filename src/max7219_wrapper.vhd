----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
--! max7219_wrapper.vhd
--! 
--! Wrapper to ease the use of max7219 device
--! Macro commands available:
--!     - 1) Initialize device by sending init_cmd_list_s
--!     - 2) Write NxN data (to all LEDs), taking data from data_all_i input
--!     - 3) Write 8b data to specified address
--! Note: each macro command or user command may consist of several commands to be sent to the device
--! Note2: data_all_i and 8b data are both firstly registered so that user does not need to keep the value during operation
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

----------------------------------------------------------------------------------
-- Internal package
----------------------------------------------------------------------------------

use work.utils_pkg.all;

package max7219_wrapper_pkg is
    constant command_width_c     : positive := 16; -- (msb) 4-bit dummy, 4-bit address, 8-bit data (lsb)
    constant num_addresses_c     : positive := 16;
    constant addr_width_c        : positive := log2_ceil(num_addresses_c);
    constant num_segments_c      : positive := 8;
    constant word_width_c        : positive := 8;
    constant num_macro_cmds_c    : positive := 3;
    constant segment_id_offset_c : natural  := 1;
end package;

----------------------------------------------------------------------------------
-- Libraries
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils_pkg.all;
use work.max7219_wrapper_pkg.all;

----------------------------------------------------------------------------------
-- Entity
----------------------------------------------------------------------------------

entity max7219_wrapper is
    port (
        clk_i            : in  std_logic;
        rst_i            : in  std_logic;
        macro_cmd_i      : in  std_logic_vector(log2_ceil(num_macro_cmds_c) - 1 downto 0);
        data_all_i       : in  std_logic_vector(num_segments_c*word_width_c - 1 downto 0);
        addr_i           : in  std_logic_vector(addr_width_c - 1 downto 0);
        data_i           : in  std_logic_vector(word_width_c - 1 downto 0);
        start_i          : in  std_logic;
        macro_cmd_done_o : out std_logic;
        max7219_clk_o    : out std_logic;
        max7219_din_o    : out std_logic;
        max7219_csn_o    : out std_logic
    );
end entity;

----------------------------------------------------------------------------------
-- Architecture
----------------------------------------------------------------------------------

architecture behavioural of max7219_wrapper is

    -- Control / FSM

    type max7219_macro_cmd_t is (init, write_all, write_addr);
    type state_t is (st_init, st_data_reg, st_wait_for_ready, st_send_next_cmd);

    signal state_s      : state_t;
    signal start_s      : std_logic;
    signal done_s       : std_logic;
    signal addr_s       : std_logic_vector(addr_width_c - 1 downto 0);
    signal data_s       : std_logic_vector(word_width_c - 1 downto 0);

    signal cmd_index_s      : integer := 0;
    type command_t is record
        dummy   : std_logic_vector(command_width_c - (addr_width_c + word_width_c) - 1 downto 0); -- fill unused in command_width_c 
        addr    : std_logic_vector(addr_width_c - 1 downto 0);
        data    : std_logic_vector(word_width_c - 1 downto 0);
    end record;

    -- Init commands
    constant num_init_cmds_c : positive := 5;
    type init_cmd_list_t is array (0 to num_init_cmds_c-1) of command_t;
    signal init_cmd_list_s : init_cmd_list_t := (
        00 => (dummy => x"0", addr => x"9", data => x"00"),
        01 => (dummy => x"0", addr => x"A", data => x"03"),
        02 => (dummy => x"0", addr => x"B", data => x"07"),
        03 => (dummy => x"0", addr => x"C", data => x"01"),
        04 => (dummy => x"0", addr => x"F", data => x"00")
    );

    -- Current command list
    constant max_cmds_c : positive := max(num_segments_c, num_init_cmds_c);
    type curr_cmd_list_t is array (0 to max_cmds_c - 1) of command_t;
    signal curr_cmd_list_s : curr_cmd_list_t;
    signal curr_cmd_list_len_s   : natural; -- Count the total number of commands to be sent from current command list
    signal curr_cmd_list_index_s : natural; -- Count how many commands have been sent from current command list
    signal cmd_list_last_s : std_logic;

begin

    -- FSM
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state_s <= st_init;
            else
                case state_s is
                    when st_init           => if (start_i = '1') then state_s <= st_data_reg; end if;
                    when st_data_reg       => state_s <= st_wait_for_ready;
                    when st_wait_for_ready => if (done_s = '1') then state_s <= st_send_next_cmd; end if;
                    when st_send_next_cmd  =>
                        if (done_s = '1') then
                            if (cmd_list_last_s = '1') then state_s <= st_init;
                            else                            state_s <= st_wait_for_ready;
                            end if;
                        end if;
                    when others            => state_s <= st_init;
                end case;
            end if;
        end if;
    end process;

    -- curr_cmd_list_s stores all commands to be sent to device right after

    process (clk_i)
        variable macro_cmd_id_v : max7219_macro_cmd_t;
    begin

        macro_cmd_id_v := max7219_macro_cmd_t'val(to_integer(unsigned(macro_cmd_i)));

        if rising_edge(clk_i) then

            -- dummy always set to 0
            for cmd_index in 0 to num_init_cmds_c - 1 loop
                curr_cmd_list_s(cmd_index).dummy <= (others => '0');
            end loop;

            case state_s is

                when st_init => -- @todo: is this initialization necessary? To remove?
                    for cmd_index in 0 to max_cmds_c - 1 loop
                        curr_cmd_list_s(cmd_index).addr <= (others => '0');
                        curr_cmd_list_s(cmd_index).data <= (others => '0');
                    end loop;
                    curr_cmd_list_len_s <= 0;

                when st_data_reg =>
                    if macro_cmd_id_v = write_addr then
                        curr_cmd_list_s(0).addr <= addr_i;
                        curr_cmd_list_s(0).data <= data_i;
                        curr_cmd_list_len_s <= 1;
                    elsif macro_cmd_id_v = init then
                        for cmd_index in 0 to num_init_cmds_c - 1 loop
                            curr_cmd_list_s(cmd_index) <= init_cmd_list_s(cmd_index);
                        end loop;
                        curr_cmd_list_len_s <= num_init_cmds_c;
                    elsif macro_cmd_id_v = write_all then
                        for cmd_index in 0 to num_segments_c - 1 loop
                            curr_cmd_list_s(cmd_index).addr <= std_logic_vector(to_unsigned(cmd_index + segment_id_offset_c, addr_width_c));
                            curr_cmd_list_s(cmd_index).data <= data_all_i(cmd_index*word_width_c + word_width_c - 1 downto cmd_index*word_width_c);
                        end loop;
                        curr_cmd_list_len_s <= num_segments_c;
                    end if;

                when others =>

            end case;
        end if;
    end process;

    -- curr_cmd_list_index_s as iterator for list of commands
    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if (state_s = st_init) then 
                curr_cmd_list_index_s <= 0;
            elsif (state_s = st_send_next_cmd and done_s = '1' and curr_cmd_list_index_s < curr_cmd_list_len_s - 1) then
                curr_cmd_list_index_s <= curr_cmd_list_index_s + 1;
            end if;
        end if;
    end process;
    cmd_list_last_s <= '1' when curr_cmd_list_index_s = curr_cmd_list_len_s - 1 else '0';

    start_s <= '1' when state_s = st_wait_for_ready else '0';
    macro_cmd_done_o <= '1' when state_s = st_init else '0';

    -- addr_s and data_s taken from command list
    addr_s <= curr_cmd_list_s(curr_cmd_list_index_s).addr;
    data_s <= curr_cmd_list_s(curr_cmd_list_index_s).data;  

    -- driver instance
    max7219_driver_inst : entity work.max7219_driver
    port map (
        clk_i         => clk_i,
        rst_i         => rst_i,
        addr_i        => addr_s,
        data_i        => data_s,
        start_i       => start_s,
        done_o        => done_s,
        max7219_clk_o => max7219_clk_o,
        max7219_din_o => max7219_din_o,
        max7219_csn_o => max7219_csn_o
    );

end architecture;
