----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
--! max7219_wrapper.vhd
--! 
--! Wrapper to ease the use of max7219 device
--! Macro commands:
--!     - 1) Initialize device by sending init_cmd_list_s
--!     - 2) Write NxN data (to all LEDs), taking data from data_all_i input (firstly registered)
--!     - 3) Write 8b data to specified address (firstly registered)
--! Note: each macro command or user command may consist of several commands to be sent to the device
--! 
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

-- package max7219_pkg is
    
-- end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.utils_pkg.all;

entity max7219_wrapper is
    generic (
        num_segments_g      : positive := 8;
        word_width_g        : positive := 8;
        num_addresses_g     : positive := 16;
        num_macro_cmds_g    : positive := 3;
        segment_id_offset_g : positive := 1

    );
    port (
        clk_i         : in  std_logic;
        rst_i         : in  std_logic;
        macro_cmd_i   : in  std_logic_vector(log2_ceil(num_macro_cmds_g) - 1 downto 0);
        data_all_i    : in  std_logic_vector(num_segments_g*word_width_g - 1 downto 0);
        addr_i        : in  std_logic_vector(log2_ceil(num_addresses_g) - 1 downto 0);
        data_i        : in  std_logic_vector(word_width_g - 1 downto 0);
        start_i       : in  std_logic;
        done_o        : out std_logic;
        max7219_clk_o : out std_logic;
        max7219_din_o : out std_logic;
        max7219_csn_o : out std_logic
    );
end entity;

architecture behavioural of max7219_wrapper is

    type max7219_macro_cmd_t is (init, write_all, write_addr);
    type state_t is (st_init, st_data_reg, st_wait_for_ready, st_send_next_cmd);

    signal state_s         : state_t;
    signal done_s          : std_logic;
    signal cmd_list_done_s : std_logic;

    -- Init commands
    signal cmd_index_s      : integer := 0;
    type command_t is record
        addr    : std_logic_vector(7 downto 0); -- @todo fix hardcoded 7
        data    : std_logic_vector(word_width_g - 1 downto 0);
    end record;
    constant num_init_cmds_c : positive := 5;
    type init_cmd_list_t is array (0 to num_init_cmds_c-1) of command_t;
    signal init_cmd_list_s : init_cmd_list_t := (
        00 => (addr => x"09", data => x"00"),
        01 => (addr => x"0A", data => x"03"),
        02 => (addr => x"0B", data => x"07"),
        03 => (addr => x"0C", data => x"01"),
        04 => (addr => x"0F", data => x"00")
    );

    -- Write all
    type array_data_t is array (0 to num_segments_g - 1) of std_logic_vector(word_width_g - 1 to 0);

    -- Current command list
    constant max_cmds_c : positive := max(num_segments_g, num_init_cmds_c);
    type curr_cmd_list_t is array (0 to max_cmds_c - 1) of command_t;
    signal curr_cmd_list_s : curr_cmd_list_t;

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
                    when st_send_next_cmd  => if (cmd_list_done_s = '1') then state_s <= st_init; end if;
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
            case state_s is
                when st_init =>
                    for cmd_index in 0 to max_cmds_c - 1 loop
                        curr_cmd_list_s(cmd_index) <= (others => '0');
                    end loop;
                when st_data_reg =>
                    if macro_cmd_id_v = init then
                        curr_cmd_list_s(0).addr(log2_ceil(num_addresses_g) - 1 downto 0) <= addr_i;
                        curr_cmd_list_s(0).data <= data_i;
                    elsif macro_cmd_id_v = init then
                        for cmd_index in 0 to num_init_cmds_c - 1 loop
                            curr_cmd_list_s(cmd_index) <= init_cmd_list_s(cmd_index);
                        end loop;
                    elsif macro_cmd_id_v = write_all then
                        for cmd_index in 0 to num_segments_g - 1 loop
                            curr_cmd_list_s(cmd_index).addr <= cmd_index + segment_id_offset_g;
                            curr_cmd_list_s(cmd_index).data <= data_all_i(cmd_index*word_width_g + word_width_g - 1 downto cmd_index*word_width_g);
                        end loop;
                    end if;
            end case;
        end if;
    end process;

    -- @todo cmd_list_done_s to be handled
    -- @todo addr_s and data_s to be handled
    -- @todo start_s to be handled

    max7219_driver_inst : entity work.max7219_driver
    generic map (
        num_segments_g  => num_segments_g,
        word_width_g    => word_width_g,
        num_addresses_g => num_addresses_g
    )
    port map (
        clk_i         => clk_i,
        rst_i         => rst_i,
        addr_i        => addr_s,
        data_i        => data_s,
        start_i       => start_s,
        done_o        => done_s,
        max7219_clk_o => max7219_clk_o,
        max7219_din_o => max7219_din_o,
        max7219_csn_o => max7219_csn_o,
        addr_o        => open,
        data_o        => open,
        state_slv_o   => open
    );

    -- Outputs
    done_o <= done_s;

end architecture;
