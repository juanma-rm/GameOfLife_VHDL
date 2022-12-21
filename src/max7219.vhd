library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity max7219 is
    port (
        clk_i           : in std_logic;
        rst_i           : in std_logic;
        max7219_clk_o   : out std_logic;
        max7219_din_o   : out std_logic;
        max7219_csn_o   : out std_logic := '1';

        -- TEMP
        addr_o          : out std_logic_vector(7 downto 0);
        data_o          : out std_logic_vector(7 downto 0);
        state_slv_o     : out std_logic_vector(1 downto 0)
    );
end entity;

architecture behavioural of max7219 is

    -- Clocks and resets
    signal max7219_clk_s    : std_logic; -- Clock from PS, 100 MHz? 5 MHz?
    signal max7219_addr_s   : std_logic_vector(7 downto 0);
    signal max7219_data_s   : std_logic_vector(7 downto 0);

    -- signal send_din_s       : boolean := true;
    signal new_command_s    : boolean := true;
    signal bit_sent_index_s : integer range 0 to 15;
    signal command_done_s   : boolean := true;
    
    type state_t is (st_init, st_enable_csn, st_send_data);
    signal state_s : state_t;

    signal cmd_index_s      : integer := 0;
    type command_t is record
        addr    : std_logic_vector(7 downto 0);
        data    : std_logic_vector(7 downto 0);
    end record;
    constant num_commands_c : positive := 13;
    type command_list_t is array (0 to num_commands_c-1) of command_t;
    signal command_list_s : command_list_t := (
        00 => (addr => x"09", data => x"00"),
        01 => (addr => x"0A", data => x"03"),
        02 => (addr => x"0B", data => x"07"),
        03 => (addr => x"0C", data => x"01"),
        04 => (addr => x"0F", data => x"00"),
        05 => (addr => x"01", data => x"01"),
        06 => (addr => x"02", data => x"02"),
        07 => (addr => x"03", data => x"04"),
        08 => (addr => x"04", data => x"08"),
        09 => (addr => x"05", data => x"00"),
        10 => (addr => x"06", data => x"00"),
        11 => (addr => x"07", data => x"00"),
        12 => (addr => x"08", data => x"00")
    );

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

    max7219_clk_o <= clk_i;
    
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
    max7219_din_o  <= max7219_addr_s(bit_sent_index_s - 8) when bit_sent_index_s > 7
                 else max7219_data_s(bit_sent_index_s);

    max7219_csn_o <= '1' when state_s = st_init else '0';
    max7219_addr_s <= command_list_s(cmd_index_s).addr when cmd_index_s < num_commands_c else (others => '0');
    max7219_data_s <= command_list_s(cmd_index_s).data when cmd_index_s < num_commands_c else (others => '0');
    new_command_s <= true when cmd_index_s < num_commands_c else false;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                cmd_index_s <= 0;
            elsif (command_done_s and state_s = st_send_data) then
                cmd_index_s <= cmd_index_s + 1;
            end if;
        end if;
    end process;

    process (clk_i)
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                state_s <= st_init;
            else
                case state_s is
                    when st_init       => if (new_command_s) then state_s <= st_enable_csn; end if;
                    when st_enable_csn => state_s <= st_send_data;
                    when st_send_data  => if (command_done_s) then state_s <= st_init; end if;
                    when others        => state_s <= st_init;
                end case;
            end if;
        end if;
    end process;

end architecture;